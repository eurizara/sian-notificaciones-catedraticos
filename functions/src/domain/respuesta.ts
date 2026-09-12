/**
 * SIAN — Responder a un aviso (DT-27, mejora M-5).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Una respuesta es una conversación entre DOS personas, atada a UN aviso.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * El catedrático que recibió el aviso y quien lo emitió. Nadie más la lee —ni
 * los demás destinatarios, ni otros coordinadores—, y no existe conversación
 * que no cuelgue de un aviso: esto no es una mensajería general, y lo que aquí
 * se decide es justo lo que impide que llegue a serlo.
 *
 * Una respuesta **no edita el aviso** (RN-03). Es una entidad nueva, en su
 * propia subcolección, que el aviso no sabe que tiene.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Un hilo por pareja, identificado por el catedrático.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * `mensajes/{mensajeId}/hilos/{uidCatedratico}`. Identificarlo por el uid hace
 * imposible por construcción que existan dos hilos de la misma persona sobre
 * el mismo aviso: es el mismo recurso que ya se usa en `entregas`.
 */

import { ErrorAutorizacion, ErrorValidacion } from './errores';

/** Quién escribe en el hilo. */
export type LadoHilo = 'CATEDRATICO' | 'EMISOR';

/**
 * Largo máximo de una respuesta.
 *
 * Una respuesta a un aviso es «no puedo asistir» o «¿a qué hora?», no una
 * carta. El límite existe sobre todo para que un pegado accidental de un
 * documento entero no acabe en una notificación.
 */
export const LARGO_MAXIMO_RESPUESTA = 1000;

/** Lo que cabe del texto en una notificación o en la vista de la lista. */
export const LARGO_VISTA_PREVIA = 140;

/**
 * Tiempo mínimo entre dos notificaciones al emisor por el mismo aviso.
 *
 * ───────────────────────────────────────────────────────────────────────────
 * Veintidós respuestas no pueden ser veintidós notificaciones.
 * ───────────────────────────────────────────────────────────────────────────
 *
 * Un aviso a toda la sede puede volver con una respuesta de cada uno en pocos
 * minutos. En Android las notificaciones del mismo aviso se reemplazan, pero en
 * iOS se apilan aunque lleven la misma etiqueta —se comprobó con los avisos—,
 * así que el servidor tiene que plegarlas él: la primera respuesta avisa en el
 * acto, las que llegan en los minutos siguientes solo suben el contador, y la
 * próxima notificación dice cuántas hay.
 */
export const MINUTOS_ENTRE_AVISOS_AL_EMISOR = 10;

/**
 * Deja el texto listo para guardar, o dice por qué no se puede.
 *
 * Se recortan los espacios de los extremos pero no los de dentro: los saltos
 * de línea de quien escribe son parte de lo que escribió.
 */
export function normalizarRespuesta(texto: unknown): string {
  const limpio = typeof texto === 'string' ? texto.trim() : '';
  if (limpio.length === 0) {
    throw new ErrorValidacion('RESPUESTA_VACIA', 'La respuesta está vacía.');
  }
  if (limpio.length > LARGO_MAXIMO_RESPUESTA) {
    throw new ErrorValidacion(
      'RESPUESTA_DEMASIADO_LARGA',
      `La respuesta no puede pasar de ${LARGO_MAXIMO_RESPUESTA} caracteres.`,
      { largo: limpio.length },
    );
  }
  return limpio;
}

/**
 * ¿En qué hilo escribe esta persona, y como quién?
 *
 * Solo hay dos casos válidos:
 *
 *   · Un **destinatario** escribe en su propio hilo. No puede elegir otro: el
 *     hilo es él. Si pidiera escribir en el de otra persona, se rechaza.
 *   · **Quien emitió el aviso** escribe en el hilo de un destinatario, y solo en
 *     uno que ya exista: responde, no inicia. Abrir conversaciones con quien no
 *     escribió sería la mensajería general que esto no quiere ser.
 *
 * Y un caso raro que se cierra a propósito: quien emite un aviso a toda la
 * sede y además recibe avisos puede estar entre sus propios destinatarios.
 * Responderse a sí mismo no tiene sentido y dejaría un hilo con el mismo
 * autor en los dos lados.
 */
export function decidirLado(entrada: {
  uid: string;
  creadoPor: string;
  esDestinatario: boolean;
  hiloPedido?: string | null;
  hiloExiste: boolean;
}): { lado: LadoHilo; hiloUid: string } {
  const { uid, creadoPor, esDestinatario, hiloExiste } = entrada;
  const hiloUid = entrada.hiloPedido && entrada.hiloPedido.length > 0 ? entrada.hiloPedido : uid;

  if (uid === creadoPor) {
    if (hiloUid === uid) {
      throw new ErrorValidacion(
        'RESPUESTA_A_UNO_MISMO',
        'No se puede responder a un aviso propio.',
      );
    }
    if (!hiloExiste) {
      throw new ErrorValidacion(
        'HILO_INEXISTENTE',
        'Solo se puede responder a quien ya escribió sobre este aviso.',
      );
    }
    return { lado: 'EMISOR', hiloUid };
  }

  if (hiloUid !== uid) {
    // Un destinatario pidiendo escribir en el hilo de otro. No se explica más:
    // decir de quién es el hilo ya sería contar algo.
    throw new ErrorAutorizacion(
      'HILO_AJENO',
      'Solo puedes escribir en tu propia conversación.',
    );
  }

  if (!esDestinatario) {
    throw new ErrorAutorizacion(
      'NO_ES_DESTINATARIO',
      'Solo puede responder quien recibió el aviso.',
    );
  }

  return { lado: 'CATEDRATICO', hiloUid };
}

/**
 * ¿Toca notificar al emisor ahora, o plegar esta respuesta con la anterior?
 *
 * Sin notificación previa, siempre. Con una reciente, no: el contador ya
 * sube, y la próxima notificación dirá cuántas hay.
 */
export function debeAvisarAlEmisor(ultimoAviso: Date | null, ahora: Date): boolean {
  if (ultimoAviso === null) {
    return true;
  }
  const minutos = (ahora.getTime() - ultimoAviso.getTime()) / 60000;
  return minutos >= MINUTOS_ENTRE_AVISOS_AL_EMISOR;
}

/** Recorta para una vista previa, sin partir una palabra si se puede evitar. */
export function vistaPrevia(texto: string, largo = LARGO_VISTA_PREVIA): string {
  const plano = texto.replace(/\s+/g, ' ').trim();
  if (plano.length <= largo) {
    return plano;
  }
  const corte = plano.slice(0, largo);
  const espacio = corte.lastIndexOf(' ');
  return `${(espacio > largo * 0.6 ? corte.slice(0, espacio) : corte).trimEnd()}…`;
}

/**
 * Lo que dice la notificación al emisor.
 *
 * Con una sola respuesta pendiente, quién y qué: es lo que hace falta para
 * decidir si abrirla ya. Con varias, cuántas y sobre qué aviso — el texto de
 * la última engañaría, porque parecería que es la única.
 */
export function avisoAlEmisor(entrada: {
  nombre: string;
  tituloAviso: string;
  texto: string;
  sinLeer: number;
}): { titulo: string; cuerpo: string } {
  if (entrada.sinLeer <= 1) {
    return {
      titulo: `Respuesta de ${entrada.nombre}`,
      cuerpo: `A «${entrada.tituloAviso}»: ${vistaPrevia(entrada.texto)}`,
    };
  }
  return {
    titulo: `${entrada.sinLeer} respuestas sin leer`,
    cuerpo: `A «${entrada.tituloAviso}». La última, de ${entrada.nombre}.`,
  };
}

/** Lo que dice la notificación al catedrático cuando le contestan. */
export function avisoAlCatedratico(entrada: {
  nombreEmisor: string;
  tituloAviso: string;
  texto: string;
}): { titulo: string; cuerpo: string } {
  return {
    titulo: `${entrada.nombreEmisor} te respondió`,
    cuerpo: `Sobre «${entrada.tituloAviso}»: ${vistaPrevia(entrada.texto)}`,
  };
}
