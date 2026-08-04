/**
 * SIAN — Repositorios sobre Firestore (patrón Repository, documento 02, §3).
 */

import type { PerfilUsuario } from '../application/activarSesion';
import type { AsientoBitacora } from '../domain/bitacora';
import type { Invitacion } from '../domain/invitacion';
import type { Rol } from '../domain/tipos';
import { DOC_CONFIGURACION, FieldValue, RUTAS, aTimestamp, db } from './firebase';

// ---------------------------------------------------------------------------
// Bitácora — RF-BIT-01, RF-BIT-02, RF-BIT-03
// ---------------------------------------------------------------------------

export async function escribirAsiento(asiento: AsientoBitacora): Promise<void> {
  await db.collection(RUTAS.bitacora).add({
    ...asiento,
    ocurridoEn: aTimestamp(asiento.ocurridoEn),
  });
}

/**
 * Escribe varios asientos en un solo lote.
 *
 * La bitácora nunca se actualiza ni se borra: solo crece (RF-BIT-03). Por eso
 * aquí solo hay `create`, y las reglas de seguridad niegan `update` y `delete`
 * a todo cliente.
 */
export async function escribirAsientos(asientos: readonly AsientoBitacora[]): Promise<void> {
  if (asientos.length === 0) {
    return;
  }
  const lote = db.batch();
  for (const asiento of asientos) {
    lote.create(db.collection(RUTAS.bitacora).doc(), {
      ...asiento,
      ocurridoEn: aTimestamp(asiento.ocurridoEn),
    });
  }
  await lote.commit();
}

// ---------------------------------------------------------------------------
// Invitaciones — RF-AUT-03, RF-USR-01
// ---------------------------------------------------------------------------

export async function buscarInvitacion(correo: string): Promise<Invitacion | null> {
  const doc = await db.collection(RUTAS.invitaciones).doc(correo).get();
  if (!doc.exists) {
    return null;
  }
  const d = doc.data() ?? {};
  return {
    correo: doc.id,
    rolAsignado: d.rolAsignado as Rol,
    nombre: (d.nombre as string) ?? '',
    consumida: d.consumida === true,
    consumidaPor: d.consumidaPor as string | undefined,
    creadaPor: (d.creadaPor as string) ?? '',
    creadaEn: (d.creadaEn?.toDate?.() as Date) ?? new Date(0),
  };
}

export async function guardarInvitaciones(invitaciones: readonly Invitacion[]): Promise<void> {
  const lote = db.batch();
  for (const i of invitaciones) {
    lote.set(
      db.collection(RUTAS.invitaciones).doc(i.correo),
      {
        rolAsignado: i.rolAsignado,
        nombre: i.nombre,
        consumida: i.consumida,
        creadaPor: i.creadaPor,
        creadaEn: aTimestamp(i.creadaEn),
      },
      // `merge` para no borrar `consumida`/`consumidaPor` si se vuelve a
      // cargar un correo que ya entró.
      { merge: true },
    );
  }
  await lote.commit();
}

export async function marcarInvitacionConsumida(correo: string, uid: string): Promise<void> {
  await db.collection(RUTAS.invitaciones).doc(correo).set(
    { consumida: true, consumidaPor: uid, consumidaEn: FieldValue.serverTimestamp() },
    { merge: true },
  );
}

export async function eliminarInvitacion(correo: string): Promise<void> {
  await db.collection(RUTAS.invitaciones).doc(correo).delete();
}

// ---------------------------------------------------------------------------
// Usuarios — documento 05, sección 2.1
// ---------------------------------------------------------------------------

export async function buscarPerfil(uid: string): Promise<PerfilUsuario | null> {
  const doc = await db.collection(RUTAS.usuarios).doc(uid).get();
  if (!doc.exists) {
    return null;
  }
  const d = doc.data() ?? {};
  return {
    uid: doc.id,
    correo: (d.correo as string) ?? '',
    nombre: (d.nombre as string) ?? '',
    rol: d.rol as Rol,
    activo: d.activo === true,
    proveedorAuth: (d.proveedorAuth as string) ?? '',
    puedeEmitirUrgentes: d.puedeEmitirUrgentes === true,
    puedeCrearRecurrentes: d.puedeCrearRecurrentes === true,
    zonaHoraria: (d.zonaHoraria as string) ?? '',
  };
}

export async function guardarPerfil(perfil: PerfilUsuario): Promise<void> {
  await db.collection(RUTAS.usuarios).doc(perfil.uid).set(
    {
      correo: perfil.correo,
      nombre: perfil.nombre,
      rol: perfil.rol,
      activo: perfil.activo,
      proveedorAuth: perfil.proveedorAuth,
      puedeEmitirUrgentes: perfil.puedeEmitirUrgentes,
      puedeCrearRecurrentes: perfil.puedeCrearRecurrentes,
      zonaHoraria: perfil.zonaHoraria,
      creadoEn: FieldValue.serverTimestamp(),
      actualizadoEn: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

export async function actualizarPerfil(
  uid: string,
  cambios: Readonly<Record<string, unknown>>,
): Promise<void> {
  await db
    .collection(RUTAS.usuarios)
    .doc(uid)
    .set({ ...cambios, actualizadoEn: FieldValue.serverTimestamp() }, { merge: true });
}

export async function registrarUltimoAcceso(uid: string): Promise<void> {
  await db
    .collection(RUTAS.usuarios)
    .doc(uid)
    .set({ ultimoAcceso: FieldValue.serverTimestamp() }, { merge: true });
}

// ---------------------------------------------------------------------------
// Configuración institucional — documento 05, sección 2.11
// ---------------------------------------------------------------------------

export async function zonaHorariaInstitucional(): Promise<string> {
  const doc = await db.doc(DOC_CONFIGURACION).get();
  return (doc.data()?.zonaHoraria as string) || 'America/Guatemala';
}
