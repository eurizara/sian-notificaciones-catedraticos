/**
 * SIAN — Confirmación de lectura (RF-CNF-01..07).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Esto es la evidencia. Cuando alguien pregunte «¿quién sabía del simulacro?»,
 * la respuesta sale de aquí.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Por eso lo escribe solo el servidor y nunca el cliente: una confirmación que
 * pudiera fabricarse desde la consola del navegador no probaría nada. Las
 * reglas de Firestore niegan toda escritura sobre `entregas` (documento 05,
 * sección 5), y este es el único camino.
 *
 * Y por eso **abrir no es confirmar** (RF-CNF-02): abrir dice que la
 * aplicación mostró el mensaje; confirmar dice que una persona declaró haberlo
 * leído. Mezclarlos convertiría una evidencia en una suposición.
 */

import { HttpsError, onCall } from 'firebase-functions/v2/https';
import type { DocumentReference } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';

import { estadoTrasAbrir, exigirConfirmable } from '../application/confirmacion';
import { exigirPermiso } from '../domain/autorizacion';
import { crearAsiento } from '../domain/bitacora';
import { ErrorDominio } from '../domain/errores';
import type { EstadoEntrega, Rol } from '../domain/tipos';
import { FieldValue, OPCIONES_FUNCION, RUTAS, db } from '../infrastructure/firebase';
import { escribirAsiento } from '../infrastructure/repositorios';

interface Ubicacion {
  mensajeId: string;
  ocurrenciaId: string;
}

/** Encuentra la entrega de este usuario para este mensaje. */
async function localizarEntrega(
  mensajeId: string,
  uid: string,
): Promise<{ ubicacion: Ubicacion; estado: EstadoEntrega } | null> {
  const ocurrencias = await db
    .collection(RUTAS.mensajes)
    .doc(mensajeId)
    .collection('ocurrencias')
    .get();

  for (const oc of ocurrencias.docs) {
    const entrega = await oc.ref.collection('entregas').doc(uid).get();
    if (entrega.exists) {
      return {
        ubicacion: { mensajeId, ocurrenciaId: oc.id },
        estado: entrega.get('estado') as EstadoEntrega,
      };
    }
  }
  return null;
}

function refEntrega(u: Ubicacion, uid: string): DocumentReference {
  return db
    .collection(RUTAS.mensajes)
    .doc(u.mensajeId)
    .collection('ocurrencias')
    .doc(u.ocurrenciaId)
    .collection('entregas')
    .doc(uid);
}

/**
 * Marca un mensaje como abierto (RF-CNF-02).
 *
 * Es automático: lo llama la aplicación al mostrar el mensaje. No sustituye a
 * la confirmación ni la insinúa — de hecho existe precisamente para poder
 * distinguir «lo vio pasar» de «dijo que lo leyó», que es la diferencia entre
 * un dato y una prueba.
 */
export const marcarAbierto = onCall(OPCIONES_FUNCION, async (peticion) => {
  if (!peticion.auth) {
    throw new HttpsError('unauthenticated', 'Hay que iniciar sesión.');
  }

  const uid = peticion.auth.uid;
  const { mensajeId } = peticion.data as { mensajeId?: string };

  if (!mensajeId) {
    throw new HttpsError('invalid-argument', 'Falta el mensaje.');
  }

  try {
    const hallazgo = await localizarEntrega(mensajeId, uid);
    if (hallazgo === null) {
      // No es destinatario. Se responde sin detalle: decir «ese mensaje no es
      // para ti» ya revela que existe.
      return { abierto: false };
    }

    const nuevo = estadoTrasAbrir(hallazgo.estado);
    if (nuevo === hallazgo.estado) {
      return { abierto: hallazgo.estado === 'ABIERTO' };
    }

    await refEntrega(hallazgo.ubicacion, uid).update({
      estado: nuevo,
      abiertoEn: FieldValue.serverTimestamp(),
    });

    await db
      .collection(RUTAS.mensajes)
      .doc(mensajeId)
      .update({ 'resumenEntrega.abiertos': FieldValue.increment(1) });

    return { abierto: true };
  } catch (e) {
    logger.error('Fallo marcando abierto', { uid, mensajeId, error: String(e) });
    // Que no se pueda marcar como abierto no puede impedir leer el mensaje.
    return { abierto: false };
  }
});

/**
 * Confirma la lectura (RF-CNF-01, 03, 04, 05).
 *
 * Registra quién, cuándo y desde qué dispositivo. Es irreversible y no se
 * puede repetir: la máquina de estados no tiene ninguna transición de salida
 * desde CONFIRMADO, y aquí se comprueba antes de escribir.
 */
export const confirmarLectura = onCall(OPCIONES_FUNCION, async (peticion) => {
  if (!peticion.auth) {
    throw new HttpsError('unauthenticated', 'Hay que iniciar sesión.');
  }

  const uid = peticion.auth.uid;
  const correo = (peticion.auth.token.email as string | undefined) ?? '';
  const rol = (peticion.auth.token.rol as Rol | undefined) ?? 'CATEDRATICO';
  const { mensajeId, dispositivo } = peticion.data as {
    mensajeId?: string;
    dispositivo?: string;
  };

  if (!mensajeId) {
    throw new HttpsError('invalid-argument', 'Falta el mensaje.');
  }

  try {
    const hallazgo = await localizarEntrega(mensajeId, uid);
    if (hallazgo === null) {
      throw new HttpsError(
        'not-found',
        'No consta que este mensaje se te haya entregado.',
      );
    }

    // Lanza con un motivo distinto según el caso: «ya estaba confirmado» no es
    // un fallo del sistema, y «nunca se entregó» sí es algo que revisar.
    exigirConfirmable(hallazgo.estado);

    const ref = refEntrega(hallazgo.ubicacion, uid);

    // La transacción cierra la ventana entre comprobar y escribir. Sin ella,
    // dos toques rápidos del mismo botón producirían dos confirmaciones
    // (RF-CNF-05).
    await db.runTransaction(async (tx) => {
      const doc = await tx.get(ref);
      const actual = doc.get('estado') as EstadoEntrega;
      exigirConfirmable(actual);

      tx.update(ref, {
        estado: 'CONFIRMADO',
        confirmadoEn: FieldValue.serverTimestamp(),
        // RF-CNF-03: desde qué dispositivo se confirmó.
        dispositivoConfirmacion: (dispositivo ?? '').slice(0, 120),
      });
    });

    await db
      .collection(RUTAS.mensajes)
      .doc(mensajeId)
      .update({ 'resumenEntrega.confirmados': FieldValue.increment(1) });

    await escribirAsiento(
      crearAsiento({
        tipo: 'LECTURA_CONFIRMADA',
        actor: { uid, correo, rol },
        entidad: 'ENTREGA',
        entidadId: `${mensajeId}/${uid}`,
        resumen: `Confirmó la lectura del mensaje ${mensajeId}`,
        datos: {
          mensajeId,
          dispositivo: (dispositivo ?? '').slice(0, 120),
          estadoAnterior: hallazgo.estado,
        },
        origen: 'APP_DOCENTE',
      }),
    );

    return { confirmado: true };
  } catch (e) {
    if (e instanceof HttpsError) {
      throw e;
    }
    if (e instanceof ErrorDominio) {
      throw new HttpsError('failed-precondition', e.message, { codigo: e.codigo });
    }
    logger.error('Fallo confirmando lectura', { uid, mensajeId, error: String(e) });
    throw new HttpsError('internal', 'No se pudo confirmar la lectura.');
  }
});

/**
 * Quién recibió y quién confirmó (RF-CNF-06).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Pasa por el servidor porque el emisor NO puede leer la lista de usuarios.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Las reglas solo dejan leer `usuarios` al coordinador, al auditor y al propio
 * interesado (documento 05, sección 5). Una administradora puede consultar el
 * reporte de sus envíos pero no el padrón entero, y eso está bien: no necesita
 * la lista de la institución para saber quién no ha confirmado su aviso.
 *
 * Aquí se unen las dos cosas con permiso de servidor y se devuelve solo lo del
 * mensaje pedido. La autorización se comprueba con el mismo permiso que rige
 * el reporte, `VER_REPORTE_ENTREGAS`, que para la administradora tiene alcance
 * PROPIO: sobre sus mensajes sí, sobre los ajenos no.
 */
export const detalleEntregas = onCall(OPCIONES_FUNCION, async (peticion) => {
  const sujeto = {
    uid: peticion.auth?.uid ?? '',
    rol: (peticion.auth?.token.rol as Rol | undefined) ?? 'CATEDRATICO',
    activo: peticion.auth?.token.activo === true,
  };

  if (!peticion.auth) {
    throw new HttpsError('unauthenticated', 'Hay que iniciar sesión.');
  }

  const { mensajeId } = peticion.data as { mensajeId?: string };
  if (!mensajeId) {
    throw new HttpsError('invalid-argument', 'Falta el mensaje.');
  }

  try {
    const refMensaje = db.collection(RUTAS.mensajes).doc(mensajeId);
    const mensaje = await refMensaje.get();

    if (!mensaje.exists) {
      throw new HttpsError('not-found', 'Ese mensaje no existe.');
    }

    exigirPermiso(sujeto, 'VER_REPORTE_ENTREGAS', {
      creadoPor: (mensaje.get('creadoPor') as string | undefined) ?? '',
    });

    const ocurrencias = await refMensaje.collection('ocurrencias').get();

    // Un destinatario aparece una sola vez aunque el mensaje sea recurrente:
    // lo que se pregunta es «¿esta persona lo confirmó?», no cuántas veces.
    const porUid = new Map<string, { estado: string; confirmadoEn: string | null }>();

    for (const oc of ocurrencias.docs) {
      const entregas = await oc.ref.collection('entregas').get();
      for (const e of entregas.docs) {
        const estado = e.get('estado') as string;
        const previo = porUid.get(e.id);
        // Se conserva el estado más avanzado: si confirmó en la primera
        // ocurrencia, confirmó.
        if (previo === undefined || previo.estado !== 'CONFIRMADO') {
          porUid.set(e.id, {
            estado,
            confirmadoEn:
              (e.get('confirmadoEn') as { toDate(): Date } | undefined)
                ?.toDate()
                .toISOString() ?? null,
          });
        }
      }
    }

    const uids = [...porUid.keys()];
    const perfiles = await Promise.all(
      uids.map((uid) => db.collection(RUTAS.usuarios).doc(uid).get()),
    );

    const nombres = new Map<string, { nombre: string; correo: string }>();
    for (const p of perfiles) {
      nombres.set(p.id, {
        nombre: (p.get('nombre') as string | undefined) ?? p.id,
        correo: (p.get('correo') as string | undefined) ?? '',
      });
    }

    const destinatarios = uids.map((uid) => ({
      uid,
      nombre: nombres.get(uid)?.nombre ?? uid,
      correo: nombres.get(uid)?.correo ?? '',
      estado: porUid.get(uid)!.estado,
      confirmadoEn: porUid.get(uid)!.confirmadoEn,
    }));

    // Los pendientes primero: es sobre quienes hay que actuar, y buscarlos
    // entre cuarenta confirmados sería el trabajo que esta pantalla evita.
    const orden: Record<string, number> = {
      FALLIDO: 0,
      DESCARTADO: 1,
      PENDIENTE: 2,
      ENVIADO_A_FCM: 3,
      ENTREGADO: 4,
      ABIERTO: 5,
      CONFIRMADO: 6,
    };
    destinatarios.sort((a, b) => {
      const d = (orden[a.estado] ?? 9) - (orden[b.estado] ?? 9);
      return d !== 0 ? d : a.nombre.localeCompare(b.nombre);
    });

    return {
      destinatarios,
      requiereConfirmacion: mensaje.get('requiereConfirmacion') === true,
    };
  } catch (e) {
    if (e instanceof HttpsError) {
      throw e;
    }
    if (e instanceof ErrorDominio) {
      throw new HttpsError('permission-denied', e.message, { codigo: e.codigo });
    }
    logger.error('Fallo leyendo el detalle de entregas', {
      mensajeId,
      error: String(e),
    });
    throw new HttpsError('internal', 'No se pudo cargar el detalle.');
  }
});
