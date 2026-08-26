/**
 * SIAN — Repositorios sobre Firestore (patrón Repository, documento 02, §3).
 */

import type { PerfilUsuario } from '../application/activarSesion';
import type { AsientoBitacora } from '../domain/bitacora';
import { decidirCarga, type Invitacion } from '../domain/invitacion';
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

/** Qué pasó con cada correo de una carga. */
export interface ResultadoGuardado {
  /** No estaban en la lista. Son las altas de verdad. */
  readonly creadas: readonly string[];
  /** Estaban, sin haber entrado todavía. Se les actualizó rol y nombre. */
  readonly actualizadas: readonly string[];
  /** Estaban y ya entraron. **No se tocan**: ver la nota de abajo. */
  readonly yaEntraron: readonly string[];
}

/**
 * Escribe una carga de invitaciones sin pisar lo que ya pasó.
 *
 * ────────────────────────────────────────────────────────────────────────────
 * `merge: true` NO protege un campo que va en el objeto que se escribe.
 * ────────────────────────────────────────────────────────────────────────────
 *
 * La versión anterior escribía `consumida: i.consumida` con `merge: true` y un
 * comentario que decía «para no borrar `consumida`/`consumidaPor` si se vuelve
 * a cargar un correo que ya entró». El comentario describía la intención; el
 * código hacía lo contrario. `merge` respeta los campos **que no mandas**, y
 * `consumida` iba en el objeto, siempre en `false`, porque `crearInvitacion`
 * lo fija así para toda invitación nueva.
 *
 * El resultado, visto en la carga masiva del 25 de agosto de 2026: una persona
 * que ya había entrado quedó con `consumida: false` y, a la vez, con su
 * `consumidaPor` y su `consumidaEn` intactos. Un documento que se contradice a
 * sí mismo. Y con eso desarmado, el camino 5 de `decidirActivacion` —«sin
 * perfil, invitación ya consumida por OTRO uid → rechazo»— deja de proteger.
 *
 * Ahora se lee antes de escribir y cada caso se trata como lo que es:
 *
 *   · No existe        → se crea.
 *   · Existe sin usar  → se actualizan rol y nombre. Corregir una lista antes
 *                        de que la gente entre es legítimo y frecuente.
 *   · Existe y ya usó  → **no se toca nada**. Cambiarle el rol en la invitación
 *                        no le cambia el rol de verdad, que vive en su perfil y
 *                        en sus claims: solo dejaría a los dos diciendo cosas
 *                        distintas. El rol de alguien que ya entró se cambia
 *                        desde la pantalla de usuarios, que sí mueve las dos.
 *
 * Quien carga recibe los tres grupos por separado, en lugar de un número que
 * cuenta como «creadas» cosas que ya estaban.
 */
export async function guardarInvitaciones(
  invitaciones: readonly Invitacion[],
): Promise<ResultadoGuardado> {
  if (invitaciones.length === 0) {
    return { creadas: [], actualizadas: [], yaEntraron: [] };
  }

  const referencias = invitaciones.map((i) => db.collection(RUTAS.invitaciones).doc(i.correo));
  const existentes = await db.getAll(...referencias);

  const creadas: string[] = [];
  const actualizadas: string[] = [];
  const yaEntraron: string[] = [];
  const lote = db.batch();

  invitaciones.forEach((i, indice) => {
    const referencia = referencias[indice];
    const actual = existentes[indice];
    if (referencia === undefined || actual === undefined) {
      return;
    }

    // La regla vive en el dominio y está probada ahí; aquí solo se aplica.
    const destino = decidirCarga({
      existe: actual.exists,
      consumida: actual.get('consumida') === true,
    });

    if (destino === 'NO_TOCAR') {
      yaEntraron.push(i.correo);
      return;
    }

    if (destino === 'CREAR') {
      lote.set(referencia, {
        rolAsignado: i.rolAsignado,
        nombre: i.nombre,
        consumida: false,
        creadaPor: i.creadaPor,
        creadaEn: aTimestamp(i.creadaEn),
      });
      creadas.push(i.correo);
      return;
    }

    // `consumida` NO viaja aquí. Es justo el campo que no debe tocarse.
    lote.set(
      referencia,
      {
        rolAsignado: i.rolAsignado,
        nombre: i.nombre,
        creadaPor: i.creadaPor,
        creadaEn: aTimestamp(i.creadaEn),
      },
      { merge: true },
    );
    actualizadas.push(i.correo);
  });

  await lote.commit();
  return { creadas, actualizadas, yaEntraron };
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
    // `undefined` a propósito cuando el campo no existe: significa «lo que
    // diga el rol», y es lo que evita migrar los perfiles ya creados.
    recibeAvisos:
      typeof d.recibeAvisos === 'boolean' ? d.recibeAvisos : undefined,
    puedeCrearRecurrentes: d.puedeCrearRecurrentes === true,
    zonaHoraria: (d.zonaHoraria as string) ?? '',
  };
}

/**
 * Nombre de quien emite, para guardarlo JUNTO al mensaje.
 *
 * ---------------------------------------------------------------------------
 * El receptor no puede leer `usuarios`, así que el nombre viaja con el mensaje.
 * ---------------------------------------------------------------------------
 *
 * Las reglas solo dejan leer esa colección al coordinador, al auditor y al
 * propio interesado (documento 05, sección 5). Un catedrático que recibe un
 * aviso no puede resolver el `creadoPor` por su cuenta: vería un identificador
 * aleatorio donde debería decir quién le está avisando.
 *
 * Se desnormaliza a propósito, y se congela con el mensaje: si esa persona
 * cambia de nombre después, el aviso sigue diciendo quién lo firmó cuando lo
 * firmó, que es lo que una bitácora tiene que sostener (RF-BIT-02).
 *
 * Si no se encuentra el perfil se devuelve cadena vacía y no el uid: enseñar
 * un identificador es peor que no enseñar nada, porque parece un dato.
 */
export async function nombreDe(uid: string): Promise<string> {
  const doc = await db.collection(RUTAS.usuarios).doc(uid).get();
  return doc.exists ? ((doc.get('nombre') as string | undefined) ?? '') : '';
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
      ...(perfil.recibeAvisos === undefined
        ? {}
        : { recibeAvisos: perfil.recibeAvisos }),
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
