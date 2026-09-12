/**
 * SIAN — «Mi suscripción cambió» (DT-23, segunda mitad).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * El canal se perdía de madrugada y solo se sabía al fallar un aviso.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * El 12 de septiembre de 2026 se midieron dos casos en desarrollo: un Android
 * que dejó de recibir entre las 22:50 y las 08:19 —con el teléfono en reposo y
 * sin que nadie lo tocara— y una computadora cuyo registro murió a los cuarenta
 * minutos de crearse. En los dos, el navegador rotó la suscripción y el SDK
 * acuñó una nueva **dentro del aparato**, sin decírselo a nadie.
 *
 * Ahora el service worker se vuelve a suscribir él solo y reporta aquí lo que
 * tiene. Con eso:
 *
 *   · El registro queda marcado como **pendiente de renovar**, así que el
 *     panel lo puede enseñar en el momento en vez de esperar a perder un aviso.
 *   · Queda guardada la suscripción en crudo —`endpoint` y llaves—, que es lo
 *     que hará falta el día que se envíe por Web Push directo sin pasar por el
 *     token de FCM.
 *
 * Como el acuse, es una petición sin sesión: el worker no tiene ninguna. Lo que
 * lo identifica es la identidad que la aplicación le dejó guardada al
 * registrarse, y **solo puede tocar un registro que ya existe**: no crea nada,
 * no borra nada y no toca ningún dato con valor probatorio.
 */

import { onRequest } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';

import { FieldValue, OPCIONES_FUNCION, RUTAS, db } from '../infrastructure/firebase';

const FORMA_ID = /^[A-Za-z0-9_.:-]{1,200}$/;

/**
 * Servicios de push conocidos.
 *
 * El `endpoint` llega de fuera y se guarda para enviarle notificaciones algún
 * día: aceptar cualquier dirección sería guardar un destino arbitrario en la
 * ficha de una persona.
 */
const SERVICIOS = [
  'https://fcm.googleapis.com/',
  'https://updates.push.services.mozilla.com/',
  'https://web.push.apple.com/',
  'https://wns2-',
  'https://sin.push.',
];

function esEndpointConocido(endpoint: string): boolean {
  return SERVICIOS.some((s) => endpoint.startsWith(s)) || endpoint.includes('.notify.windows.com/');
}

export const reportarSuscripcion = onRequest(
  { ...OPCIONES_FUNCION, cors: true },
  async (peticion, respuesta) => {
    if (peticion.method === 'OPTIONS') {
      respuesta.status(204).send('');
      return;
    }
    if (peticion.method !== 'POST') {
      respuesta.status(405).send('');
      return;
    }

    const cuerpo = (peticion.body ?? {}) as {
      uid?: string;
      instalacionId?: string;
      endpoint?: string;
      p256dh?: string;
      auth?: string;
      motivo?: string;
    };

    const uid = String(cuerpo.uid ?? '');
    const instalacionId = String(cuerpo.instalacionId ?? '');
    const endpoint = String(cuerpo.endpoint ?? '');

    if (!FORMA_ID.test(uid) || !FORMA_ID.test(instalacionId) || !esEndpointConocido(endpoint)) {
      respuesta.status(400).send('');
      return;
    }

    try {
      const ref = db
        .collection(RUTAS.usuarios)
        .doc(uid)
        .collection('dispositivos')
        .doc(instalacionId);

      // `update` y no `set`: si ese registro no existe, no hay nada que
      // reportar y no se crea un dispositivo desde una petición sin sesión.
      await ref.update({
        webPush: {
          endpoint,
          p256dh: String(cuerpo.p256dh ?? '').slice(0, 200),
          auth: String(cuerpo.auth ?? '').slice(0, 100),
          actualizadaEn: FieldValue.serverTimestamp(),
        },
        // El token de FCM que tenemos ya no vale: solo la página puede acuñar
        // uno nuevo, y lo hará en la próxima apertura.
        ...(cuerpo.motivo === 'rotada'
          ? {
              suscripcionRotadaEn: FieldValue.serverTimestamp(),
              tokenPendienteDeRenovar: true,
            }
          : { canalRevisadoEn: FieldValue.serverTimestamp() }),
      });

      logger.info('Suscripción reportada por el worker', {
        uid,
        instalacionId,
        motivo: cuerpo.motivo,
      });
      respuesta.status(204).send('');
    } catch (e) {
      // Un registro que ya no existe —lo retiró la limpieza— no es un error
      // del que haya que informar a nadie.
      logger.warn('No se pudo anotar la suscripción reportada', {
        uid,
        instalacionId,
        error: String(e),
      });
      respuesta.status(204).send('');
    }
  },
);
