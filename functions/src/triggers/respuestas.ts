/**
 * SIAN — Responder a un aviso (DT-27, mejora M-5).
 *
 * Las reglas del negocio viven en `domain/respuesta.ts`; aquí están los
 * efectos: leer el aviso, escribir el turno, llevar los contadores y avisar al
 * otro lado.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Por el servidor, como todo lo que escribe en Firestore.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Las reglas niegan cualquier escritura del cliente sobre `hilos`. Si el
 * navegador pudiera escribir, bastaría con la consola para responder en nombre
 * de otro, o en el hilo de otro.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Los contadores van en el hilo, NO en el aviso.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Lo cómodo era poner «3 respuestas» en el documento del aviso. Pero ese
 * documento lo leen **todos** sus destinatarios, y cualquiera habría podido
 * saber cuántos compañeros contestaron. El hilo solo lo leen sus dos partes, y
 * el emisor reúne los suyos con una consulta sobre `hilos` filtrada por él.
 */

import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import { getMessaging, type TokenMessage } from 'firebase-admin/messaging';

import { crearAsiento } from '../domain/bitacora';
import { esTokenMuerto } from '../domain/dispositivo';
import { ErrorAutorizacion, ErrorDominio } from '../domain/errores';
import {
  avisoAlCatedratico,
  avisoAlEmisor,
  debeAvisarAlEmisor,
  decidirLado,
  type LadoHilo,
  normalizarRespuesta,
  vistaPrevia,
} from '../domain/respuesta';
import type { Rol } from '../domain/tipos';
import { FieldValue, OPCIONES_FUNCION, RUTAS, Timestamp, db } from '../infrastructure/firebase';
import { escribirAsiento, nombreDe } from '../infrastructure/repositorios';
import { retirarTokensMuertos, tokensDe } from './envio';

/**
 * Identificador del turno que propone el cliente.
 *
 * Es lo que hace inofensivo el doble toque (DT-24): el mismo turno llega dos
 * veces con el mismo identificador, y el segundo encuentra el documento ya
 * creado. Se valida la forma porque es un identificador de documento que
 * viene de fuera.
 */
const FORMA_TURNO = /^[A-Za-z0-9]{12,40}$/;

function traducir(e: unknown, contexto: Record<string, unknown>, mensaje: string): HttpsError {
  if (e instanceof HttpsError) {
    return e;
  }
  if (e instanceof ErrorAutorizacion) {
    return new HttpsError('permission-denied', e.message, { codigo: e.codigo });
  }
  if (e instanceof ErrorDominio) {
    return new HttpsError('invalid-argument', e.message, { codigo: e.codigo });
  }
  logger.error(mensaje, { ...contexto, error: String(e) });
  return new HttpsError('internal', mensaje);
}

/**
 * Escribe un turno en el hilo que corresponde.
 *
 * Un destinatario escribe en su propio hilo —y lo crea si es la primera vez—;
 * quien emitió el aviso contesta en el hilo de un destinatario que ya
 * escribió. `decidirLado` es quien dice cuál de los dos casos es, o ninguno.
 */
export const responderAviso = onCall(OPCIONES_FUNCION, async (peticion) => {
  if (!peticion.auth) {
    throw new HttpsError('unauthenticated', 'Hay que iniciar sesión.');
  }
  if (peticion.auth.token.activo !== true) {
    throw new HttpsError('permission-denied', 'Tu cuenta no está activa.');
  }

  const uid = peticion.auth.uid;
  const correo = (peticion.auth.token.email as string | undefined) ?? '';
  const rol = (peticion.auth.token.rol as Rol | undefined) ?? 'CATEDRATICO';
  const datos = peticion.data as {
    mensajeId?: string;
    texto?: string;
    hiloUid?: string;
    turnoId?: string;
  };

  if (!datos.mensajeId) {
    throw new HttpsError('invalid-argument', 'Falta el aviso.');
  }
  if (datos.turnoId !== undefined && !FORMA_TURNO.test(datos.turnoId)) {
    throw new HttpsError('invalid-argument', 'Identificador de respuesta no válido.');
  }
  const mensajeId = datos.mensajeId;

  try {
    const texto = normalizarRespuesta(datos.texto);
    const miNombre = (await nombreDe(uid)) || correo;
    const refMensaje = db.collection(RUTAS.mensajes).doc(mensajeId);

    const hecho = await db.runTransaction(async (tx) => {
      // Todas las lecturas antes que cualquier escritura: una transacción de
      // Firestore no admite leer después de haber escrito.
      const mensaje = await tx.get(refMensaje);
      if (!mensaje.exists) {
        // Sin detalle: decir «ese aviso no es para ti» ya revela que existe.
        throw new HttpsError('not-found', 'No se encontró el aviso.');
      }

      const creadoPor = (mensaje.get('creadoPor') as string | undefined) ?? '';
      const destinatarios = (mensaje.get('destinatariosUids') as string[] | undefined) ?? [];
      const hiloPedido = datos.hiloUid && datos.hiloUid.length > 0 ? datos.hiloUid : uid;

      const refHilo = refMensaje.collection('hilos').doc(hiloPedido);
      const refPrivado = refMensaje.collection('privado').doc('respuestas');
      const refTurno = refHilo
        .collection('turnos')
        .doc(datos.turnoId ?? refHilo.collection('turnos').doc().id);

      const [hilo, privado, turnoPrevio] = await Promise.all([
        tx.get(refHilo),
        tx.get(refPrivado),
        tx.get(refTurno),
      ]);

      const { lado, hiloUid } = decidirLado({
        uid,
        creadoPor,
        esDestinatario: destinatarios.includes(uid),
        hiloPedido,
        hiloExiste: hilo.exists,
      });

      // El mismo turno por segunda vez: doble toque, o un reintento de la red.
      // Ya está guardado; no se escribe ni se notifica otra vez.
      if (turnoPrevio.exists) {
        return { repetido: true as const };
      }

      const ahora = new Date();
      const tituloAviso = (mensaje.get('titulo') as string | undefined) ?? '';
      const nombreEmisor = (mensaje.get('creadoPorNombre') as string | undefined) ?? '';

      tx.create(refTurno, {
        lado,
        autorUid: uid,
        autorNombre: miNombre,
        texto,
        creadoEn: FieldValue.serverTimestamp(),
      });

      const cambios = {
        turnos: FieldValue.increment(1),
        actualizadoEn: FieldValue.serverTimestamp(),
        ultimo: { lado, vista: vistaPrevia(texto) },
        // Quien escribe ya está leyendo su hilo: lo suyo queda al día, y lo
        // del otro lado sube.
        ...(lado === 'CATEDRATICO'
          ? { sinLeerEmisor: FieldValue.increment(1), sinLeerCatedratico: 0 }
          : { sinLeerCatedratico: FieldValue.increment(1), sinLeerEmisor: 0 }),
      };

      if (hilo.exists) {
        tx.update(refHilo, cambios);
      } else {
        // Solo llega aquí un destinatario: `decidirLado` no deja al emisor
        // escribir en un hilo que no existe.
        tx.create(refHilo, {
          mensajeId,
          uid: hiloUid,
          nombre: miNombre,
          emisorUid: creadoPor,
          emisorNombre: nombreEmisor,
          // Copiado para que el emisor sepa de qué le hablan sin abrir el
          // aviso, igual que el nombre del emisor viaja con el mensaje.
          tituloAviso,
          creadoEn: FieldValue.serverTimestamp(),
          ...cambios,
        });
      }

      let avisarAlEmisor = false;
      if (lado === 'CATEDRATICO') {
        const ultimo = (privado.get('avisadoEn') as Timestamp | undefined)?.toDate() ?? null;
        avisarAlEmisor = debeAvisarAlEmisor(ultimo, ahora);
        if (avisarAlEmisor) {
          tx.set(refPrivado, { avisadoEn: Timestamp.fromDate(ahora) }, { merge: true });
        }
      }

      return {
        repetido: false as const,
        lado,
        hiloUid,
        creadoPor,
        tituloAviso,
        nombreEmisor,
        avisarAlEmisor,
      };
    });

    if (hecho.repetido) {
      return { guardada: true, repetida: true };
    }

    await escribirAsiento(
      crearAsiento({
        tipo: 'RESPUESTA_ENVIADA',
        actor: { uid, correo, rol },
        entidad: 'MENSAJE',
        entidadId: `${mensajeId}/${hecho.hiloUid}`,
        resumen:
          hecho.lado === 'CATEDRATICO'
            ? `Respondió al aviso ${mensajeId}`
            : `Contestó en el hilo de ${hecho.hiloUid} del aviso ${mensajeId}`,
        datos: { mensajeId, hiloUid: hecho.hiloUid, lado: hecho.lado },
        origen: hecho.lado === 'CATEDRATICO' ? 'APP_DOCENTE' : 'PANEL_WEB',
      }),
    );

    // Avisar es un extra: la respuesta ya está guardada y se ve en la
    // aplicación. Un fallo de push no puede convertirse en «no se envió».
    try {
      if (hecho.lado === 'CATEDRATICO' && hecho.avisarAlEmisor) {
        const sinLeer = await sinLeerDelEmisor(mensajeId);
        await notificar(hecho.creadoPor, {
          ...avisoAlEmisor({ nombre: miNombre, tituloAviso: hecho.tituloAviso, texto, sinLeer }),
          etiqueta: `respuestas-${mensajeId}`,
        });
      } else if (hecho.lado === 'EMISOR') {
        await notificar(hecho.hiloUid, {
          ...avisoAlCatedratico({
            nombreEmisor: hecho.nombreEmisor || miNombre,
            tituloAviso: hecho.tituloAviso,
            texto,
          }),
          etiqueta: `respuesta-${mensajeId}`,
        });
      }
    } catch (e) {
      logger.warn('La respuesta se guardó pero no se pudo notificar', {
        mensajeId,
        error: String(e),
      });
    }

    return { guardada: true, repetida: false };
  } catch (e) {
    throw traducir(e, { uid, mensajeId }, 'No se pudo enviar la respuesta.');
  }
});

/**
 * Marca como leído lo que el otro lado escribió en un hilo.
 *
 * Cada lado pone a cero SU contador, nunca el del otro: que el emisor abra la
 * conversación no puede hacer creer al catedrático que ya leyó la respuesta.
 */
export const marcarHiloLeido = onCall(OPCIONES_FUNCION, async (peticion) => {
  if (!peticion.auth) {
    throw new HttpsError('unauthenticated', 'Hay que iniciar sesión.');
  }
  if (peticion.auth.token.activo !== true) {
    throw new HttpsError('permission-denied', 'Tu cuenta no está activa.');
  }
  const uid = peticion.auth.uid;
  const { mensajeId, hiloUid } = peticion.data as { mensajeId?: string; hiloUid?: string };
  if (!mensajeId) {
    throw new HttpsError('invalid-argument', 'Falta el aviso.');
  }

  try {
    const refMensaje = db.collection(RUTAS.mensajes).doc(mensajeId);
    const refHilo = refMensaje.collection('hilos').doc(hiloUid || uid);

    return await db.runTransaction(async (tx) => {
      const [mensaje, hilo] = await Promise.all([tx.get(refMensaje), tx.get(refHilo)]);
      if (!mensaje.exists || !hilo.exists) {
        return { leido: false };
      }

      let lado: LadoHilo;
      if (uid === (mensaje.get('creadoPor') as string | undefined)) {
        lado = 'EMISOR';
      } else if (uid === hilo.id) {
        lado = 'CATEDRATICO';
      } else {
        throw new HttpsError('permission-denied', 'Esta conversación no es tuya.');
      }

      const campo = lado === 'EMISOR' ? 'sinLeerEmisor' : 'sinLeerCatedratico';
      if (((hilo.get(campo) as number | undefined) ?? 0) > 0) {
        tx.update(refHilo, { [campo]: 0 });
      }
      return { leido: true };
    });
  } catch (e) {
    throw traducir(e, { uid, mensajeId }, 'No se pudo marcar como leída.');
  }
});

/** Cuántos turnos le quedan por leer al emisor en este aviso, sumando hilos. */
async function sinLeerDelEmisor(mensajeId: string): Promise<number> {
  const hilos = await db.collection(RUTAS.mensajes).doc(mensajeId).collection('hilos').get();
  return hilos.docs.reduce(
    (total, h) => total + ((h.get('sinLeerEmisor') as number | undefined) ?? 0),
    0,
  );
}

/**
 * Notifica a todos los dispositivos de una persona.
 *
 * **Sin `mensajeId`**, a propósito. El service worker cuenta para la insignia y
 * cierra al leer las notificaciones que lo llevan; una respuesta no es un
 * aviso sin leer de la bandeja, y contarla desajustaría el número del icono,
 * que ya costó dos correcciones. La `etiqueta` agrupa las de un mismo aviso.
 *
 * Quien no tiene dispositivo no recibe nada, y no pasa nada: la respuesta está
 * guardada y la ve al abrir la aplicación.
 */
async function notificar(
  uid: string,
  aviso: { titulo: string; cuerpo: string; etiqueta: string },
): Promise<void> {
  const tokens = await tokensDe(uid);
  if (tokens.length === 0) {
    return;
  }

  const mensajes: TokenMessage[] = tokens.map((token) => ({
    token,
    data: { tipo: 'RESPUESTA', titulo: aviso.titulo, cuerpo: aviso.cuerpo, etiqueta: aviso.etiqueta },
    webpush: { headers: { Urgency: 'normal' }, fcmOptions: { link: '/' } },
  }));

  const respuesta = await getMessaging().sendEach(mensajes);
  const muertos: { uid: string; token: string }[] = [];
  respuesta.responses.forEach((r, i) => {
    const token = tokens[i];
    if (!r.success && token !== undefined && esTokenMuerto(r.error?.code)) {
      muertos.push({ uid, token });
    }
  });
  await retirarTokensMuertos(muertos);
}
