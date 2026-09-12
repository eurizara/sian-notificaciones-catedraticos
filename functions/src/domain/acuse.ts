/**
 * SIAN — El acuse de que el aparato MOSTRÓ la notificación (DT-31, C-5).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * «Entregado» solo significa que FCM aceptó el mensaje.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Entre eso y que el teléfono enseñe la notificación hay un tramo entero que el
 * servidor no ve:
 *
 *     servidor → FCM → servicio de push (Apple/Google) → aparato
 *              ↑                                          ↑
 *        lo único que                            lo que la persona
 *        medíamos hasta hoy                      de verdad experimenta
 *
 * El 11 de septiembre de 2026 un aviso salió a 23 personas: cinco fallaron y
 * varias de las dieciocho «entregadas» nunca vieron la notificación —se
 * enteraron por WhatsApp—. Con lo que había, esa frase no se podía ni confirmar
 * ni desmentir.
 *
 * Desde aquí, **el service worker avisa cuando ha mostrado la notificación**, y
 * eso se anota en la entrega. Lo que antes era una suposición pasa a ser un
 * dato, y con él se puede insistir y se puede decir a quién hay que llamar.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * La seña: quién puede decir «ya la mostré»
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * El service worker no tiene sesión: no puede firmar la llamada como el resto
 * de la aplicación. Así que cada entrega lleva un identificador aleatorio que
 * **viaja dentro del propio push** y vuelve con el acuse. Quien no recibió ese
 * push no lo conoce, y sin él el acuse se rechaza.
 *
 * No es una credencial ni protege nada valioso: lo peor que puede hacer quien
 * lo tenga es afirmar que vio un aviso que sí se le mandó a él.
 */

import { ErrorValidacion } from './errores';

/**
 * Desde qué versión de la aplicación un aparato sabe acusar.
 *
 * ───────────────────────────────────────────────────────────────────────────
 * Sin esto, el panel acusa a quien no tenía forma de contestar.
 * ───────────────────────────────────────────────────────────────────────────
 *
 * El acuse lo manda el service worker, que viaja con la aplicación. Un teléfono
 * que todavía no ha recargado corre la versión anterior y **no puede** acusar
 * aunque muestre la notificación perfectamente. Se vio el 11 de septiembre de
 * 2026, media hora después de estrenar el acuse: el reporte dijo «se mostró en
 * 0 de 5» cuando lo único cierto era que ninguno de los cinco sabía todavía
 * cómo decirlo.
 *
 * Así que de un aparato por debajo de esta versión **no se afirma nada**, igual
 * que no se afirma nada de los avisos anteriores a C-5.
 */
export const VERSION_QUE_SABE_ACUSAR = '1.5.0';

/**
 * ¿Este aparato sabía acusar cuando se le mandó el aviso?
 *
 * Compara por tramos numéricos, no como texto: «1.10.0» es posterior a «1.9.0»
 * y comparado como cadena saldría al revés.
 */
export function sabeAcusar(version: string | undefined | null): boolean {
  const tramos = (version ?? '').trim().split('.').map((t) => Number.parseInt(t, 10));
  if (tramos.length !== 3 || tramos.some((t) => !Number.isFinite(t))) {
    return false;
  }
  const minimo = VERSION_QUE_SABE_ACUSAR.split('.').map((t) => Number.parseInt(t, 10));
  for (let i = 0; i < 3; i += 1) {
    if (tramos[i]! !== minimo[i]!) {
      return tramos[i]! > minimo[i]!;
    }
  }
  return true;
}

/**
 * ¿Se puede afirmar que a esta persona su aparato no le mostró el aviso?
 *
 * Dos caminos, y basta uno:
 *
 *   · La **versión** que corría su aparato sabía acusar.
 *   · O ya **consta que acusó** algo antes de este envío, aunque su versión no
 *     lo diga: el service worker se renueva en cada arranque mientras la
 *     aplicación espera a que alguien recargue, así que hay aparatos que acusan
 *     con la versión sin reportar. Se vio el 12 de septiembre de 2026.
 *
 * Sin ninguno de los dos, el silencio no significa nada y no se acusa a nadie.
 */
export function podiaAcusar(entrada: {
  versionAparato?: string | null;
  enviadoAFcmEn: Date | null;
  acusaDesde: Date | null;
}): boolean {
  if (sabeAcusar(entrada.versionAparato)) {
    return true;
  }
  if (entrada.acusaDesde === null) {
    return false;
  }
  return entrada.enviadoAFcmEn === null || entrada.acusaDesde <= entrada.enviadoAFcmEn;
}

/** Cuánto se espera un acuse antes de volver a intentar el aviso. */
export const MINUTOS_SIN_ACUSE_PARA_REINTENTAR = 10;

/**
 * Cuánto se reintenta, como máximo. Una vez.
 *
 * Insistir más no ayuda: si dos empujones seguidos no aparecieron, lo que falla
 * no es la entrega sino los ajustes del aparato, y eso se resuelve con una
 * persona, no con un tercer intento.
 */
export const REINTENTOS_POR_FALTA_DE_ACUSE = 1;

/**
 * Vida útil del push, en segundos.
 *
 * Sin esto, FCM guarda el mensaje hasta cuatro semanas: un aviso de «mañana hay
 * actividades» podía aparecer el jueves siguiente, cuando ya no significa nada.
 * Un urgente vale menos todavía si llega tarde.
 */
export const SEGUNDOS_DE_VIDA_URGENTE = 4 * 60 * 60;
export const SEGUNDOS_DE_VIDA_INFORMATIVO = 24 * 60 * 60;

/**
 * Las cabeceras del push.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * `Urgency: high` en TODOS los avisos, no solo en los urgentes.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Con urgencia normal, el servicio de push está autorizado a retener el mensaje
 * hasta que el aparato salga del modo de reposo. Eso es exactamente lo que
 * describieron varias personas el 11 de septiembre: la notificación no sonó, y
 * el aviso apareció al abrir la aplicación.
 *
 * Un aviso institucional no es una novedad de una tienda: si no se puede
 * mostrar ahora, ya no sirve. La distinción entre urgente e informativo se
 * mantiene donde sí corresponde —el prefijo, la vibración, la insistencia— y en
 * cuánto tiempo se guarda.
 */
export function cabecerasDeEnvio(esUrgente: boolean): Record<string, string> {
  return {
    Urgency: 'high',
    TTL: String(esUrgente ? SEGUNDOS_DE_VIDA_URGENTE : SEGUNDOS_DE_VIDA_INFORMATIVO),
  };
}

/** Longitud del identificador aleatorio que viaja en el push. */
export const LARGO_DE_ACUSE = 16;

const FORMA_SEÑA = /^([A-Za-z0-9_-]{1,64})\|([A-Za-z0-9_-]{1,64})\|([A-Za-z0-9]{8,64})$/;

/** Lo que viaja en el push para poder identificar la entrega al volver. */
export function armarSeña(ocurrenciaId: string, uid: string, acuseId: string): string {
  return `${ocurrenciaId}|${uid}|${acuseId}`;
}

/**
 * Deshace la seña, o rechaza lo que no tiene su forma.
 *
 * Se valida la forma porque estos tres valores se convierten en una ruta de
 * Firestore, y llegan de fuera.
 */
export function leerSeña(texto: unknown): {
  ocurrenciaId: string;
  uid: string;
  acuseId: string;
} {
  const encaja = typeof texto === 'string' ? FORMA_SEÑA.exec(texto) : null;
  if (encaja === null) {
    throw new ErrorValidacion('SEÑA_INVALIDA', 'El acuse no trae una seña válida.');
  }
  return { ocurrenciaId: encaja[1]!, uid: encaja[2]!, acuseId: encaja[3]! };
}

/**
 * ¿Hay que volver a empujar este aviso?
 *
 * Solo si consta entregado —FCM lo aceptó—, nadie ha dicho que se mostrara,
 * han pasado los minutos de gracia y no se ha reintentado ya. Un aviso que la
 * persona abrió no se reintenta aunque falte el acuse: ya lo vio, que es lo
 * único que se perseguía.
 */
export function necesitaReintento(
  entrega: {
    estado: string;
    mostradaEn: Date | null;
    enviadoAFcmEn: Date | null;
    reintentosPorAcuse?: number;
  },
  ahora: Date,
): boolean {
  if (entrega.estado !== 'ENTREGADO') {
    return false;
  }
  if (entrega.mostradaEn !== null || entrega.enviadoAFcmEn === null) {
    return false;
  }
  if ((entrega.reintentosPorAcuse ?? 0) >= REINTENTOS_POR_FALTA_DE_ACUSE) {
    return false;
  }
  const minutos = (ahora.getTime() - entrega.enviadoAFcmEn.getTime()) / 60000;
  return minutos >= MINUTOS_SIN_ACUSE_PARA_REINTENTAR;
}
