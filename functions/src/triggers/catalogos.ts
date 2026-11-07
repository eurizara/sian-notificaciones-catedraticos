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

import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import type { QuerySnapshot } from 'firebase-admin/firestore';

import { sedeDeLaPeticion } from '../application/sedeDeLaPeticion';
import { exigirPermiso } from '../domain/autorizacion';
import { crearAsiento } from '../domain/bitacora';
import { decidirGuardado, type ElementoCatalogo } from '../domain/catalogo';
import { ErrorAutorizacion, ErrorDominio } from '../domain/errores';
import { esIdDeSede, sedesDelToken } from '../domain/sede';
import { ROLES, type Rol } from '../domain/tipos';
import { FieldValue, OPCIONES_LLAMABLE, RUTAS, db } from '../infrastructure/firebase';
import { escribirAsiento } from '../infrastructure/repositorios';

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
export const guardarSede = onCall(OPCIONES_LLAMABLE, async (peticion) => {
  if (!peticion.auth) {
    throw new HttpsError('unauthenticated', 'Hay que iniciar sesión.');
  }
  const token = peticion.auth.token;
  const correo = (token.email as string | undefined) ?? '';
  const rol: Rol = (ROLES as readonly string[]).includes(token.rol as string) ? (token.rol as Rol) : 'CATEDRATICO';
  // La bandera se le da a quien coordina: un auditor o una administradora con
  // ella no mantienen sedes (RF-CAT-05).
  const coordinaEnAlguna = Object.values(sedesDelToken(token, rol)).includes('COORDINADOR');
  if (token.activo !== true || token.adminGeneral !== true || !coordinaEnAlguna) {
    throw new HttpsError('permission-denied', 'Solo la administración general mantiene las sedes.');
  }

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
        actor: { uid: peticion.auth.uid, correo, rol },
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
