/**
 * SIAN — Mantenimiento de sedes y facultades (2.0 · RF-SED-06, RF-CAT-01..05).
 *
 * Las sedes las mantiene la administración general (`adminGeneral` en el
 * token): son lo que reparte a la gente entre lugares, y nadie de una sede debe
 * poder crear otra. Las facultades de una sede, su coordinación.
 *
 * Toda escritura pasa por aquí, nunca por el cliente: las reglas solo dejan
 * leer. Así la validación —nombre, repetidos, identificador que no cambia—
 * vive en un sitio (`domain/catalogo.ts`) y queda en la bitácora.
 */

import { HttpsError, onCall, type CallableRequest } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import type { QuerySnapshot } from 'firebase-admin/firestore';

import { sedeDeLaPeticion } from '../application/sedeDeLaPeticion';
import { exigirPermiso } from '../domain/autorizacion';
import { crearAsiento } from '../domain/bitacora';
import { decidirGuardado, type ElementoCatalogo } from '../domain/catalogo';
import { ErrorAutorizacion, ErrorDominio } from '../domain/errores';
import { claimsDe, type PerfilUsuario } from '../application/activarSesion';
import {
  conRolEnSede,
  esIdDeSede,
  membresiasDe,
  sedePrincipal,
  motivoParaNoCambiarSuperadministrador,
  sinSede,
  type Membresias,
} from '../domain/sede';
import { ROLES, type Rol } from '../domain/tipos';
import { FieldValue, OPCIONES_LLAMABLE, RUTAS, auth, db } from '../infrastructure/firebase';
import { actualizarPerfil, buscarPerfil, escribirAsiento } from '../infrastructure/repositorios';

function traducir(e: unknown): HttpsError {
  if (e instanceof HttpsError) {
    return e;
  }
  if (e instanceof ErrorAutorizacion) {
    return new HttpsError('permission-denied', e.message, { codigo: e.codigo });
  }
  if (e instanceof ErrorDominio) {
    return new HttpsError('invalid-argument', e.message, { codigo: e.codigo });
  }
  logger.error('Fallo en un catálogo', { error: String(e) });
  return new HttpsError('internal', 'No se pudo guardar el cambio.');
}

function leer(instantanea: QuerySnapshot): ElementoCatalogo[] {
  return instantanea.docs.map((d) => ({
    id: d.id,
    nombre: (d.get('nombre') as string | undefined) ?? d.id,
    activa: d.get('activa') !== false,
  }));
}

/**
 * Alta o edición de una sede (RF-SED-06). Solo la administración general.
 *
 * Desactivar una sede no saca a nadie de ella ni borra nada: deja de ofrecerse
 * para trabajar en ella. Reactivarla la devuelve tal como estaba.
 */
/**
 * Quien pide es superadministrador (RF-SED-06; campo técnico `adminGeneral`):
 * mantiene las sedes y pone a la gente en ellas. Solo otro superadministrador
 * lo designa (2.0.4).
 */
function exigirAdminGeneral(peticion: CallableRequest): { uid: string; correo: string; rol: Rol } {
  if (!peticion.auth) {
    throw new HttpsError('unauthenticated', 'Hay que iniciar sesión.');
  }
  const token = peticion.auth.token;
  const rol: Rol = (ROLES as readonly string[]).includes(token.rol as string) ? (token.rol as Rol) : 'CATEDRATICO';
  if (token.activo !== true || token.adminGeneral !== true) {
    throw new HttpsError('permission-denied', 'Solo un superadministrador puede hacer esto.');
  }
  return { uid: peticion.auth.uid, correo: (token.email as string | undefined) ?? '', rol };
}

export const guardarSede = onCall(OPCIONES_LLAMABLE, async (peticion) => {
  const { uid: actorUid, correo, rol } = exigirAdminGeneral(peticion);

  try {
    const decision = decidirGuardado(
      peticion.data as Record<string, unknown>,
      leer(await db.collection(RUTAS.sedes).get()),
    );
    const { elemento } = decision;
    if (decision.cambios.length === 0) {
      return { id: elemento.id, nuevo: false };
    }
    await db
      .collection(RUTAS.sedes)
      .doc(elemento.id)
      .set(
        {
          nombre: elemento.nombre,
          activa: elemento.activa,
          ...(decision.nuevo ? { creadaEn: FieldValue.serverTimestamp() } : {}),
          actualizadaEn: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    await escribirAsiento(
      crearAsiento({
        tipo: 'CATALOGO_MODIFICADO',
        actor: { uid: actorUid, correo, rol },
        entidad: 'CATALOGO',
        entidadId: `sedes/${elemento.id}`,
        resumen: `Sede «${elemento.nombre}»: ${decision.cambios.join(', ')}`,
        datos: { catalogo: 'sedes', id: elemento.id, cambios: decision.cambios },
        sedeId: elemento.id,
      }),
    );
    return { id: elemento.id, nuevo: decision.nuevo };
  } catch (e) {
    throw traducir(e);
  }
});

/**
 * Alta o edición de una facultad de la sede donde actúa quien la pide
 * (RF-FAC-01). Solo su coordinación (permiso `ADMINISTRAR_CATALOGOS`).
 */
export const guardarFacultad = onCall(OPCIONES_LLAMABLE, async (peticion) => {
  if (!peticion.auth) {
    throw new HttpsError('unauthenticated', 'Hay que iniciar sesión.');
  }
  const correo = (peticion.auth.token.email as string | undefined) ?? '';

  try {
    const datos = (peticion.data ?? {}) as Record<string, unknown>;
    const { sedeId, rol } = sedeDeLaPeticion(peticion.auth.token, datos.sedeId);
    exigirPermiso(
      { uid: peticion.auth.uid, rol, activo: peticion.auth.token.activo === true },
      'ADMINISTRAR_CATALOGOS',
    );
    if (!esIdDeSede(sedeId)) {
      throw new HttpsError('invalid-argument', 'La sede no es válida.');
    }
    const sede = await db.collection(RUTAS.sedes).doc(sedeId).get();
    if (!sede.exists) {
      // La migración (2.0-c) crea la sede inicial; sin ella no hay dónde
      // colgar una facultad, y crearla aquí a escondidas sería peor.
      throw new HttpsError('failed-precondition', 'Esa sede todavía no está dada de alta.');
    }

    const coleccion = db.collection(RUTAS.sedes).doc(sedeId).collection(RUTAS.facultades);
    const decision = decidirGuardado(
      { id: datos.id, nombre: datos.nombre, activa: datos.activa },
      leer(await coleccion.get()),
    );
    const { elemento } = decision;
    if (decision.cambios.length === 0) {
      return { id: elemento.id, nuevo: false };
    }
    await coleccion.doc(elemento.id).set(
      {
        nombre: elemento.nombre,
        activa: elemento.activa,
        ...(decision.nuevo ? { creadaEn: FieldValue.serverTimestamp() } : {}),
        actualizadaEn: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    await escribirAsiento(
      crearAsiento({
        tipo: 'CATALOGO_MODIFICADO',
        actor: { uid: peticion.auth.uid, correo, rol },
        entidad: 'CATALOGO',
        entidadId: `sedes/${sedeId}/facultades/${elemento.id}`,
        resumen: `Facultad «${elemento.nombre}»: ${decision.cambios.join(', ')}`,
        datos: { catalogo: 'facultades', id: elemento.id, cambios: decision.cambios },
        sedeId,
      }),
    );
    return { id: elemento.id, nuevo: decision.nuevo };
  } catch (e) {
    throw traducir(e);
  }
});

// ---------------------------------------------------------------------------
// Personas y sedes (2.0.1 · RF-SED-02, RF-SED-06) — administración general
// ---------------------------------------------------------------------------

/** Escribe las membresías, el rol de la sede principal y el token, de una vez. */
async function aplicarMembresias(perfil: PerfilUsuario, membresias: Membresias): Promise<PerfilUsuario> {
  // `rol` sigue diciendo el rol en la sede principal: las versiones anteriores
  // a la 2.0 solo leen ese campo.
  const rol = membresias[sedePrincipal(membresias)]?.rol ?? perfil.rol;
  const actualizado: PerfilUsuario = { ...perfil, rol, membresias };
  await actualizarPerfil(perfil.uid, { rol, membresias });
  await auth.setCustomUserClaims(perfil.uid, { ...claimsDe(actualizado) });
  return actualizado;
}

async function perfilOError(uid: unknown): Promise<PerfilUsuario> {
  if (typeof uid !== 'string' || uid === '') {
    throw new HttpsError('invalid-argument', 'Falta la persona.');
  }
  const perfil = await buscarPerfil(uid);
  if (!perfil) {
    throw new HttpsError('not-found', 'Esa persona no existe.');
  }
  return perfil;
}

function resumenSedes(m: Membresias): string {
  return Object.entries(m)
    .map(([s, v]) => `${s}:${v.rol}`)
    .join(', ');
}

/**
 * Pone a una persona en una sede con un rol, o le cambia el rol allí
 * (RF-SED-02, RF-SED-06). La sede tiene que existir y estar activa.
 */
export const asignarSede = onCall(OPCIONES_LLAMABLE, async (peticion) => {
  const actor = exigirAdminGeneral(peticion);
  const datos = (peticion.data ?? {}) as { uid?: unknown; sedeId?: unknown; rol?: unknown };
  try {
    const perfil = await perfilOError(datos.uid);
    if (perfil.uid === actor.uid) {
      // Quitarse a uno mismo el rol de coordinador podría dejar el sistema sin
      // nadie que lo administre: lo hace otra persona.
      throw new HttpsError('failed-precondition', 'No puede cambiar sus propias sedes.');
    }
    const rol = String(datos.rol ?? '').toUpperCase() as Rol;
    if (!(ROLES as readonly string[]).includes(rol)) {
      throw new HttpsError('invalid-argument', 'El rol no es válido.');
    }
    if (!esIdDeSede(datos.sedeId)) {
      throw new HttpsError('invalid-argument', 'La sede no es válida.');
    }
    const sede = await db.collection(RUTAS.sedes).doc(datos.sedeId).get();
    if (!sede.exists || sede.get('activa') === false) {
      throw new HttpsError('failed-precondition', 'Esa sede no existe o está inactiva.');
    }
    const antes = membresiasDe(perfil);
    const despues = await aplicarMembresias(perfil, conRolEnSede(perfil, datos.sedeId, rol));
    await escribirAsiento(
      crearAsiento({
        tipo: 'USUARIO_SEDES_CAMBIADAS',
        actor,
        entidad: 'USUARIO',
        entidadId: perfil.uid,
        resumen: `Sedes de ${perfil.correo}: ${resumenSedes(antes)} → ${resumenSedes(despues.membresias ?? {})}`,
        datos: { sedeId: datos.sedeId, rol },
        sedeId: datos.sedeId,
      }),
    );
    return { uid: perfil.uid, sedes: Object.keys(despues.membresias ?? {}) };
  } catch (e) {
    throw traducir(e);
  }
});

/** Saca a una persona de una sede (RF-SED-06). Nunca de la última. */
export const quitarSede = onCall(OPCIONES_LLAMABLE, async (peticion) => {
  const actor = exigirAdminGeneral(peticion);
  const datos = (peticion.data ?? {}) as { uid?: unknown; sedeId?: unknown };
  try {
    const perfil = await perfilOError(datos.uid);
    if (perfil.uid === actor.uid) {
      throw new HttpsError('failed-precondition', 'No puede cambiar sus propias sedes.');
    }
    if (!esIdDeSede(datos.sedeId)) {
      throw new HttpsError('invalid-argument', 'La sede no es válida.');
    }
    const antes = membresiasDe(perfil);
    const despues = await aplicarMembresias(perfil, sinSede(perfil, datos.sedeId));
    await escribirAsiento(
      crearAsiento({
        tipo: 'USUARIO_SEDES_CAMBIADAS',
        actor,
        entidad: 'USUARIO',
        entidadId: perfil.uid,
        resumen: `Sedes de ${perfil.correo}: ${resumenSedes(antes)} → ${resumenSedes(despues.membresias ?? {})}`,
        datos: { quitada: datos.sedeId },
        sedeId: datos.sedeId,
      }),
    );
    return { uid: perfil.uid, sedes: Object.keys(despues.membresias ?? {}) };
  } catch (e) {
    throw traducir(e);
  }
});

/**
 * Da o quita la administración general (RF-SED-06). Solo a quien coordina en
 * alguna sede, y nunca a uno mismo: así siempre queda alguien que la tenga.
 */
/**
 * Designa o retira a un superadministrador (2.0.4). Solo otro
 * superadministrador; nunca a sí mismo ni al último.
 */
export const cambiarAdminGeneral = onCall(OPCIONES_LLAMABLE, async (peticion) => {
  if (!peticion.auth) {
    throw new HttpsError('unauthenticated', 'Hay que iniciar sesión.');
  }
  const token = peticion.auth.token;
  const datos = (peticion.data ?? {}) as { uid?: unknown; valor?: unknown };
  try {
    if (token.activo !== true) {
      throw new HttpsError('permission-denied', 'Su cuenta no está activa.');
    }
    const rolGlobal: Rol = (ROLES as readonly string[]).includes(token.rol as string)
      ? (token.rol as Rol)
      : 'CATEDRATICO';
    const actor = { uid: peticion.auth.uid, correo: (token.email as string | undefined) ?? '', rol: rolGlobal };
    const perfil = await perfilOError(datos.uid);
    if (typeof datos.valor !== 'boolean') {
      throw new HttpsError('invalid-argument', 'Falta si se designa o se retira.');
    }
    const superadministradores = (
      await db.collection(RUTAS.usuarios).where('adminGeneral', '==', true).count().get()
    ).data().count;
    const motivo = motivoParaNoCambiarSuperadministrador({
      actorUid: actor.uid,
      actorEsSuperadministrador: token.adminGeneral === true,
      objetivo: perfil,
      valor: datos.valor,
      superadministradores,
    });
    if (motivo !== null) {
      throw new HttpsError('permission-denied', motivo);
    }
    const actualizado: PerfilUsuario = { ...perfil, adminGeneral: datos.valor };
    await actualizarPerfil(perfil.uid, { adminGeneral: datos.valor });
    await auth.setCustomUserClaims(perfil.uid, { ...claimsDe(actualizado) });
    await escribirAsiento(
      crearAsiento({
        tipo: 'USUARIO_ADMIN_GENERAL_CAMBIADO',
        actor,
        entidad: 'USUARIO',
        entidadId: perfil.uid,
        resumen: `${datos.valor ? 'Se designa' : 'Se retira'} como superadministrador a ${perfil.correo}`,
        datos: { valor: datos.valor },
      }),
    );
    return { uid: perfil.uid, adminGeneral: datos.valor };
  } catch (e) {
    throw traducir(e);
  }
});

