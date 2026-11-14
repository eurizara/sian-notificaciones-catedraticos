/**
 * SIAN — Mantenimiento de sedes y facultades (2.0 · RF-SED-06, RF-CAT-01..05).
 *
 * Las sedes las mantiene la administración general (`adminGeneral` en el
 * token): son lo que reparte a la gente entre lugares, y nadie de una sede debe
 * poder crear otra. Desde la 2.0.6 las facultades son un catálogo único que
 * también mantiene el superadministrador; cada sede elige de él las que ofrece
 * (el superadministrador o su coordinación), ver `domain/facultades.ts`.
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
import { decidirOferta, exigirQueNingunaSedeLaOfrezca } from '../domain/facultades';
import { ErrorAutorizacion, ErrorDominio } from '../domain/errores';
import { claimsDe, type PerfilUsuario } from '../application/activarSesion';
import {
  conFacultadesEnSede,
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
import {
  actualizarPerfil,
  buscarPerfil,
  escribirAsiento,
  reemplazarMembresias,
} from '../infrastructure/repositorios';
import {
  contarGruposConFacultad,
  contarPersonasConFacultad,
  leerCatalogoDeFacultades,
  leerFacultades,
  propagarNombreDeFacultad,
  sedesQueOfrecen,
} from '../infrastructure/sedes';

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
 * Alta o edición de una facultad del catálogo único de la UMG (2.0.6). Solo el
 * superadministrador: así cada facultad existe una vez y es la misma en todas
 * las sedes. Cada sede elige después cuáles ofrece (`ofrecerFacultad`).
 *
 * Cambiar el nombre lo cambia en cada sede que la ofrece. Desactivarla solo se
 * puede si ninguna sede la ofrece.
 */
export const guardarFacultad = onCall(OPCIONES_LLAMABLE, async (peticion) => {
  const { uid: actorUid, correo, rol } = exigirAdminGeneral(peticion);

  try {
    const datos = (peticion.data ?? {}) as Record<string, unknown>;
    const existentes = await leerCatalogoDeFacultades();
    const decision = decidirGuardado(
      { id: datos.id, nombre: datos.nombre, activa: datos.activa },
      existentes,
    );
    const { elemento } = decision;
    if (decision.cambios.length === 0) {
      return { id: elemento.id, nuevo: false };
    }
    const previo = existentes.find((e) => e.id === elemento.id);
    if (previo?.activa === true && !elemento.activa) {
      exigirQueNingunaSedeLaOfrezca(elemento.nombre, await sedesQueOfrecen(elemento.id));
    }
    await db
      .collection(RUTAS.catalogoFacultades)
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
    if (previo !== undefined && previo.nombre !== elemento.nombre) {
      await propagarNombreDeFacultad(elemento.id, elemento.nombre);
    }
    await escribirAsiento(
      crearAsiento({
        tipo: 'CATALOGO_MODIFICADO',
        actor: { uid: actorUid, correo, rol },
        entidad: 'CATALOGO',
        entidadId: `facultades/${elemento.id}`,
        resumen: `Facultad «${elemento.nombre}» (catálogo): ${decision.cambios.join(', ')}`,
        datos: { catalogo: 'facultades', id: elemento.id, cambios: decision.cambios },
      }),
    );
    return { id: elemento.id, nuevo: decision.nuevo };
  } catch (e) {
    throw traducir(e);
  }
});

/**
 * Que una sede ofrezca, o deje de ofrecer, una facultad del catálogo (2.0.6).
 * El superadministrador, en cualquier sede; la coordinación, en la suya
 * (permiso `ADMINISTRAR_CATALOGOS` con su rol allí). No se retira una que
 * alguien de la sede tiene asignada.
 */
export const ofrecerFacultad = onCall(OPCIONES_LLAMABLE, async (peticion) => {
  if (!peticion.auth) {
    throw new HttpsError('unauthenticated', 'Hay que iniciar sesión.');
  }
  const token = peticion.auth.token;
  const correo = (token.email as string | undefined) ?? '';
  const datos = (peticion.data ?? {}) as { sedeId?: unknown; facultadId?: unknown; ofrecer?: unknown };

  try {
    let sedeId: string;
    let rol: Rol;
    if (token.activo === true && token.adminGeneral === true) {
      if (!esIdDeSede(datos.sedeId)) {
        throw new HttpsError('invalid-argument', 'La sede no es válida.');
      }
      sedeId = datos.sedeId;
      rol = (ROLES as readonly string[]).includes(token.rol as string) ? (token.rol as Rol) : 'CATEDRATICO';
    } else {
      ({ sedeId, rol } = sedeDeLaPeticion(token, datos.sedeId));
      exigirPermiso({ uid: peticion.auth.uid, rol, activo: token.activo === true }, 'ADMINISTRAR_CATALOGOS');
    }
    if (!esIdDeSede(datos.facultadId)) {
      throw new HttpsError('invalid-argument', 'La facultad no es válida.');
    }
    if (typeof datos.ofrecer !== 'boolean') {
      throw new HttpsError('invalid-argument', 'Falta decir si se ofrece o no.');
    }
    const facultadId = datos.facultadId;
    const sede = await db.collection(RUTAS.sedes).doc(sedeId).get();
    if (!sede.exists) {
      throw new HttpsError('failed-precondition', 'Esa sede todavía no está dada de alta.');
    }
    const enCatalogo = await db.collection(RUTAS.catalogoFacultades).doc(facultadId).get();
    const oferta = sede.ref.collection(RUTAS.facultades).doc(facultadId);
    const actual = await oferta.get();
    const catalogo = enCatalogo.exists
      ? {
          nombre: (enCatalogo.get('nombre') as string | undefined) ?? facultadId,
          activa: enCatalogo.get('activa') !== false,
        }
      : undefined;
    const cambio = decidirOferta({
      ofrecer: datos.ofrecer,
      catalogo,
      actual: actual.exists ? { activa: actual.get('activa') !== false } : undefined,
      personas: datos.ofrecer ? 0 : await contarPersonasConFacultad(sedeId, facultadId),
      grupos: datos.ofrecer ? 0 : await contarGruposConFacultad(sedeId, facultadId),
    });
    if (cambio === null) {
      return { sedeId, facultadId, ofrecida: datos.ofrecer };
    }
    const nombre = catalogo?.nombre ?? ((actual.get('nombre') as string | undefined) ?? facultadId);
    await oferta.set(
      {
        nombre,
        activa: datos.ofrecer,
        ...(cambio === 'alta' ? { creadaEn: FieldValue.serverTimestamp() } : {}),
        actualizadaEn: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    await escribirAsiento(
      crearAsiento({
        tipo: 'CATALOGO_MODIFICADO',
        actor: { uid: peticion.auth.uid, correo, rol },
        entidad: 'CATALOGO',
        entidadId: `sedes/${sedeId}/facultades/${facultadId}`,
        resumen: `Facultad «${nombre}» en la sede: ${cambio === 'retirada' ? 'ya no se ofrece' : 'se ofrece'}`,
        datos: { catalogo: 'oferta', id: facultadId, cambios: [cambio] },
        sedeId,
      }),
    );
    return { sedeId, facultadId, ofrecida: datos.ofrecer };
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
  await reemplazarMembresias(perfil.uid, membresias, rol);
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
  const datos = (peticion.data ?? {}) as { uid?: unknown; sedeId?: unknown; rol?: unknown; facultades?: unknown };
  try {
    const perfil = await perfilOError(datos.uid);
    // 2.0.5: el superadministrador sí cambia sus propias sedes, como sus
    // facultades. Lo que no puede es quedarse sin ninguna (`sinSede`) ni
    // quitarse el rol de superadministrador (eso lo hace otro).
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
    let membresias = conRolEnSede(perfil, datos.sedeId, rol);
    // 2.0.6: con `facultades`, también las suyas en esa sede, solo entre las
    // que la sede ofrece. Sin ellas (versiones anteriores), se conservan.
    if (datos.facultades !== undefined) {
      membresias = conFacultadesEnSede(
        { rol: perfil.rol, membresias },
        datos.sedeId,
        datos.facultades,
        await leerFacultades(datos.sedeId),
      );
    }
    const despues = await aplicarMembresias(perfil, membresias);
    await escribirAsiento(
      crearAsiento({
        tipo: 'USUARIO_SEDES_CAMBIADAS',
        actor,
        entidad: 'USUARIO',
        entidadId: perfil.uid,
        resumen: `Sedes de ${perfil.correo}: ${resumenSedes(antes)} → ${resumenSedes(despues.membresias ?? {})}`,
        datos: { sedeId: datos.sedeId, rol, facultades: membresias[datos.sedeId]?.facultades ?? [] },
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

