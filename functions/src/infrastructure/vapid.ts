/**
 * SIAN — Las llaves VAPID propias, para enviar Web Push sin pasar por FCM.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Por qué hacen falta unas llaves nuestras
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Con FCM, el aparato se suscribe con la llave pública de Firebase y nos
 * devuelve un **token**, que es lo único a lo que podemos enviar. Ese token solo
 * se puede acuñar desde la página: cuando el navegador rota la suscripción de
 * madrugada, el service worker puede volver a suscribirse pero **no** puede
 * darnos un token nuevo. Hasta que la persona abre la aplicación, no hay a dónde
 * enviarle. Es lo que se midió el 12 de septiembre de 2026 (DT-23).
 *
 * Con llaves propias, el aparato se suscribe con **nuestra** llave pública y lo
 * que guardamos es la suscripción en crudo —dirección y llaves de cifrado—. Eso
 * el worker sí lo puede renovar y reportar él solo, sin que nadie abra nada.
 *
 * La pública va aquí porque **es pública por diseño**: viaja a cada navegador en
 * cada suscripción. La privada vive en Secret Manager de cada proyecto, y se lee
 * en tiempo de ejecución.
 *
 * Si falta la privada, esta vía no envía. Eso es inofensivo solo mientras la
 * aplicación de ese ambiente se compile SIN la pública: un aparato suscrito con
 * ella no tiene token de FCM al que caer. Primero el secreto, después la
 * pública — ver el documento 11 y `test/unidad/vapid.test.ts`.
 */

/** Llave pública por proyecto. Vacío = ese ambiente aún no tiene par propio. */
const PUBLICAS: Record<string, string> = {
  'sian-umg-bdm-dev':
    'BKXdY3qydUGq6byS_W9cUwy3ysqlpThNqh-HhxtkrUgXeuWfK2dk0WhGwT8fxrHbW-OJVFaJjp3AfUYVIS2czNU',
  'sian-umg-bdm-qa':
    'BJdWvY3LzFBl35JW1fVXtJDFfLO5C_VuEM8kTWciWoXkvXXSIst65N2rrZ9MLb_BAxO-m8oTBf4aOjg6A4-lcKE',
  // 'sian-umg-bdm': pendiente de generar
};

/** Quién firma las peticiones de push, según pide el estándar. */
export const CONTACTO_VAPID = 'mailto:coordinacion@miumg.edu.gt';

export function clavePublicaDe(proyecto: string | undefined): string {
  return PUBLICAS[proyecto ?? ''] ?? '';
}
