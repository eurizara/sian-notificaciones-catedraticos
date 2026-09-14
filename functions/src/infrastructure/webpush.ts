/**
 * SIAN — Envío por Web Push directo (DT-23).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * La misma notificación, por el camino que el aparato sí puede reparar solo.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * El servicio de push del navegador —el de Google, el de Apple, el de Mozilla—
 * acepta el mensaje firmado con nuestra llave privada y lo entrega al service
 * worker. Ahí llega **con la misma forma** que un mensaje de FCM: un objeto con
 * `data`, que es lo que el worker ya sabe leer. Por eso este cambio no toca la
 * notificación ni la insignia ni el acuse.
 *
 * La llave privada se lee de Secret Manager en la primera llamada y se guarda en
 * memoria mientras viva la instancia. Si no está —un ambiente donde todavía no
 * se configuró—, esta vía queda apagada y todo sigue yendo por FCM.
 */

import { logger } from 'firebase-functions/v2';
import webpush from 'web-push';

import { CONTACTO_VAPID, clavePublicaDe } from './vapid';

export interface SuscripcionWeb {
  readonly endpoint: string;
  readonly p256dh: string;
  readonly auth: string;
}

export interface ResultadoWebPush {
  readonly ok: boolean;
  /** El servicio de push dice que esa suscripción ya no existe. */
  readonly muerta: boolean;
  readonly codigo?: string;
}

let privadaEnMemoria: string | null | undefined;

/** El proyecto en el que corre esta función. */
function proyecto(): string {
  return process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT ?? '';
}

/**
 * Lee la llave privada de Secret Manager, una vez por instancia.
 *
 * Se hace por API y no con un secreto enlazado a la función a propósito: así,
 * un ambiente donde el secreto todavía no existe **despliega igual** y
 * simplemente no usa esta vía. Enlazarlo haría fallar el despliegue entero.
 */
async function clavePrivada(): Promise<string | null> {
  if (privadaEnMemoria !== undefined) {
    return privadaEnMemoria;
  }
  try {
    const meta = await fetch(
      'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token',
      { headers: { 'Metadata-Flavor': 'Google' } },
    );
    const { access_token: token } = (await meta.json()) as { access_token: string };

    const url =
      `https://secretmanager.googleapis.com/v1/projects/${proyecto()}` +
      '/secrets/VAPID_PRIVADA/versions/latest:access';
    const r = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
    if (!r.ok) {
      logger.info('Sin llave VAPID propia en este proyecto: se envía solo por FCM');
      privadaEnMemoria = null;
      return null;
    }
    const cuerpo = (await r.json()) as { payload?: { data?: string } };
    const dato = cuerpo.payload?.data;
    privadaEnMemoria = dato ? Buffer.from(dato, 'base64').toString('utf8').trim() : null;
    return privadaEnMemoria;
  } catch (e) {
    logger.warn('No se pudo leer la llave VAPID', { error: String(e) });
    privadaEnMemoria = null;
    return null;
  }
}

/** ¿Se puede enviar por esta vía en este proyecto? */
export async function hayWebPushPropio(): Promise<boolean> {
  return clavePublicaDe(proyecto()).length > 0 && (await clavePrivada()) !== null;
}

/**
 * Manda una notificación a una suscripción.
 *
 * `404` y `410` son la forma en que el servicio de push dice «esta suscripción
 * ya no existe»: es el equivalente del token muerto de FCM, y se trata igual.
 */
export async function enviarPorWebPush(
  suscripcion: SuscripcionWeb,
  carga: Record<string, string>,
): Promise<ResultadoWebPush> {
  const privada = await clavePrivada();
  const publica = clavePublicaDe(proyecto());
  if (!privada || !publica) {
    return { ok: false, muerta: false, codigo: 'SIN_LLAVES' };
  }

  try {
    await webpush.sendNotification(
      {
        endpoint: suscripcion.endpoint,
        keys: { p256dh: suscripcion.p256dh, auth: suscripcion.auth },
      },
      // Misma forma que entrega FCM: el worker no distingue de dónde vino.
      JSON.stringify({ data: carga }),
      {
        vapidDetails: { subject: CONTACTO_VAPID, publicKey: publica, privateKey: privada },
        TTL: Number(carga.ttl ?? 0) || 86400,
        urgency: 'high',
      },
    );
    return { ok: true, muerta: false };
  } catch (e) {
    const estado = (e as { statusCode?: number }).statusCode;
    return {
      ok: false,
      muerta: estado === 404 || estado === 410,
      codigo: estado ? `webpush/${estado}` : 'webpush/desconocido',
    };
  }
}
