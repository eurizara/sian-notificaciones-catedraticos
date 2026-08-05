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
