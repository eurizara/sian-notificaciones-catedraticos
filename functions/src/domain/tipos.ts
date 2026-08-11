/**
 * SIAN — Vocabulario del dominio.
 *
 * Este archivo es la traducción literal a tipos del documento 01 (secciones 9
 * y 10) y del documento 05 (sección 2). Ninguna cadena de estado ni de rol se
 * escribe suelta en el resto del código: si un valor no está aquí, no existe.
 *
 * No importa nada de Firebase, por diseño (RNF-19).
 */

// ---------------------------------------------------------------------------
// Roles y autorización (documento 01, sección 2)
// ---------------------------------------------------------------------------

export const ROLES = ['COORDINADOR', 'ADMINISTRADORA', 'CATEDRATICO', 'AUDITOR'] as const;
export type Rol = (typeof ROLES)[number];

// ---------------------------------------------------------------------------
// Mensajes (documento 01, sección 3.3 · documento 05, sección 2.4)
// ---------------------------------------------------------------------------

export const TIPOS_MENSAJE = ['INFORMATIVO', 'URGENTE'] as const;
export type TipoMensaje = (typeof TIPOS_MENSAJE)[number];

export const FORMATOS_MENSAJE = ['TEXTO', 'VOZ', 'IMAGEN'] as const;
export type FormatoMensaje = (typeof FORMATOS_MENSAJE)[number];

/** Máquina de estados del mensaje — documento 01, sección 9. */
export const ESTADOS_MENSAJE = [
  'BORRADOR',
  'PROGRAMADO',
  'SUSPENDIDO',
  'EN_COLA',
  'EN_ENVIO',
  'ENVIADO',
  'ENVIADO_CON_FALLOS',
  'FALLIDO',
  'CANCELADO',
  'RECURRENTE_PENDIENTE',
  'AGOTADO',
] as const;
export type EstadoMensaje = (typeof ESTADOS_MENSAJE)[number];

/** Máquina de estados de la entrega individual — documento 01, sección 10. */
export const ESTADOS_ENTREGA = [
  'PENDIENTE',
  'ENVIADO_A_FCM',
  'ENTREGADO',
  'FALLIDO',
  'DESCARTADO',
  'ABIERTO',
  'CONFIRMADO',
] as const;
export type EstadoEntrega = (typeof ESTADOS_ENTREGA)[number];

/** Estados de la ocurrencia — documento 05, sección 2.6. */
export const ESTADOS_OCURRENCIA = [
  'PENDIENTE',
  'EN_ENVIO',
  'COMPLETADA',
  'COMPLETADA_CON_FALLOS',
  'OMITIDA',
  'CANCELADA',
] as const;
export type EstadoOcurrencia = (typeof ESTADOS_OCURRENCIA)[number];

/** Estados del ítem en la cola de despacho — documento 05, sección 2.8. */
export const ESTADOS_ITEM_COLA = ['PENDIENTE', 'TOMADO', 'COMPLETADO', 'FALLIDO'] as const;
export type EstadoItemCola = (typeof ESTADOS_ITEM_COLA)[number];

// ---------------------------------------------------------------------------
// Programación y recurrencia (documento 05, sección 2.5)
// ---------------------------------------------------------------------------

export const MODOS_PROGRAMACION = ['INMEDIATO', 'UNICO', 'RECURRENTE'] as const;
export type ModoProgramacion = (typeof MODOS_PROGRAMACION)[number];

export const UNIDADES_INTERVALO = ['MINUTOS', 'HORAS', 'DIAS'] as const;
export type UnidadIntervalo = (typeof UNIDADES_INTERVALO)[number];

/** Franja horaria diaria, en hora local institucional (RF-PRG-08). */
export interface FranjaHoraria {
  readonly desde: string; // 'HH:mm'
  readonly hasta: string; // 'HH:mm'
}

/**
 * Patrón de repetición (RF-PRG-05..08).
 *
 * `fechaInicio` y `fechaFin` son instantes absolutos en UTC (RN-05).
 * `horaDelDia` y `franjaHoraria` son hora local de la zona institucional: esa
 * asimetría es deliberada y es la fuente de la mayoría de los errores de
 * calendario, por eso queda dicha aquí.
 */
export interface Recurrencia {
  readonly fechaInicio: string; // ISO 8601 en UTC
  readonly fechaFin: string; // ISO 8601 en UTC — obligatoria (RF-PRG-14)
  readonly unidadIntervalo: UnidadIntervalo;
  readonly valorIntervalo: number;
  /** 1 = lunes … 7 = domingo. Vacío significa «todos los días». */
  readonly diasSemana?: readonly number[];
  /** 'HH:mm' en hora local institucional. Solo aplica a intervalos en días. */
  readonly horaDelDia?: string;
  readonly franjaHoraria?: FranjaHoraria;
  readonly maxOcurrencias: number;
  readonly ocurrenciasGeneradas?: number;
  readonly suspendida?: boolean;
}

export interface Programacion {
  readonly modo: ModoProgramacion;
  readonly zonaHoraria: string;
  /** Solo cuando modo = UNICO. ISO 8601 en UTC. */
  readonly ejecutarEn?: string;
  /** Solo cuando modo = RECURRENTE. */
  readonly recurrencia?: Recurrencia;
}

// ---------------------------------------------------------------------------
// Adjuntos (documento 05, sección 2.4)
// ---------------------------------------------------------------------------

export const TIPOS_ADJUNTO = ['AUDIO', 'IMAGEN'] as const;
export type TipoAdjunto = (typeof TIPOS_ADJUNTO)[number];

export interface Adjunto {
  readonly tipo: TipoAdjunto;
  readonly ruta: string;
  readonly bytes: number;
  readonly tipoMime: string;
  /** Solo audio. */
  readonly duracionSeg?: number;
}

export interface AdjuntoAudio {
  readonly ruta: string;
  readonly bytes: number;
  readonly tipoMime?: string;
  readonly duracionSeg: number;
}

export interface AdjuntoImagen {
  readonly ruta: string;
  readonly bytes: number;
  readonly tipoMime: string;
  readonly ancho?: number;
  readonly alto?: number;
}

/**
 * Lo que un mensaje lleva adjunto.
 *
 * ---------------------------------------------------------------------------
 * UNA LISTA ORDENADA, NO UNA LISTA POR TIPO.
 * ---------------------------------------------------------------------------
 *
 * El orden es del emisor y tiene sentido: un plano, después la nota de voz que
 * lo explica, después la foto del punto de reunión. Guardarlo como
 * `{audios: [], imagenes: []}` obligaría a reconstruir ese orden al mostrarlo,
 * y no hay forma de reconstruir lo que no se guardó.
 *
 * `audio` e `imagen` son la forma ANTIGUA, de cuando solo cabía uno de cada.
 * Se siguen leyendo porque los mensajes ya enviados no se reescriben (RN-03):
 * dejar de entenderlos borraría los adjuntos de todo lo entregado hasta hoy.
 * Nada nuevo se escribe así — `normalizarAdjuntos` traduce y el resto del
 * sistema solo conoce `lista`.
 */
export interface Adjuntos {
  readonly lista?: readonly Adjunto[];
  readonly audio?: AdjuntoAudio;
  readonly imagen?: AdjuntoImagen;
}

/** Los adjuntos en orden, vengan en la forma nueva o en la antigua. */
export function normalizarAdjuntos(adjuntos?: Adjuntos): readonly Adjunto[] {
  if (!adjuntos) {
    return [];
  }
  if (adjuntos.lista && adjuntos.lista.length > 0) {
    return adjuntos.lista;
  }

  // Forma antigua. La voz iba primero al mostrarse, así que se conserva ese
  // orden: es el único que esos mensajes llegaron a tener.
  const traducidos: Adjunto[] = [];
  if (adjuntos.audio) {
    traducidos.push({
      tipo: 'AUDIO',
      ruta: adjuntos.audio.ruta,
      bytes: adjuntos.audio.bytes,
      tipoMime: adjuntos.audio.tipoMime ?? 'audio/webm',
      duracionSeg: adjuntos.audio.duracionSeg,
    });
  }
  if (adjuntos.imagen) {
    traducidos.push({
      tipo: 'IMAGEN',
      ruta: adjuntos.imagen.ruta,
      bytes: adjuntos.imagen.bytes,
      tipoMime: adjuntos.imagen.tipoMime,
    });
  }
  return traducidos;
}

// ---------------------------------------------------------------------------
// Destinatarios (RF-USR-06)
// ---------------------------------------------------------------------------

export const MODOS_DESTINATARIO = ['TODOS', 'GRUPOS', 'INDIVIDUAL'] as const;
export type ModoDestinatario = (typeof MODOS_DESTINATARIO)[number];

export interface Destinatarios {
  readonly modo: ModoDestinatario;
  readonly gruposIds?: readonly string[];
  readonly usuariosIds?: readonly string[];
}

// ---------------------------------------------------------------------------
// Límites del dominio — documento 01, sección 3 · documento 05, sección 2.11
// ---------------------------------------------------------------------------

export const LIMITES = {
  /** RF-MSG-06 */
  TITULO_MAX: 80,
  /** RF-MSG-06 */
  CUERPO_MAX: 500,
  /** RF-MSG-07 */
  AUDIO_MAX_SEGUNDOS: 60,
  /** RF-MSG-07 */
  AUDIO_MAX_BYTES: 2 * 1024 * 1024,
  /** RF-MSG-08 */
  IMAGEN_MAX_BYTES: 5 * 1024 * 1024,
  /** RF-MSG-08 */
  IMAGEN_MIMES: ['image/jpeg', 'image/png', 'image/webp'] as readonly string[],
  /** RF-MSG-05 — cuántos adjuntos caben en un mensaje. */
  MAX_IMAGENES: 3,
  MAX_AUDIOS: 2,
  /**
   * Peso total de los adjuntos de un mensaje.
   *
   * Los máximos por pieza sumarían 19 MB, y un aviso de 19 MB en una conexión
   * mala no es un aviso: es contenido que no llega. El tope existe para que el
   * emisor se entere ANTES de enviar, cuando todavía puede quitar algo.
   */
  ADJUNTOS_MAX_BYTES_TOTAL: 10 * 1024 * 1024,
  /** RF-PRG-14 · documento 05, sección 2.11 */
  MAX_OCURRENCIAS_POR_MENSAJE: 500,
  /** RF-PRG-09 */
  VISTA_PREVIA_OCURRENCIAS: 10,
  /** DT-08 */
  MAX_MIEMBROS_POR_GRUPO: 200,
  /** RNF-22 · documento 05, sección 2.11 */
  TAMANO_LOTE_FCM: 500,
  /** RF-ENT-10 */
  MAX_REINTENTOS_ENTREGA: 3,
  /** RF-ADM-02 · tolerancia por omisión, en minutos */
  TOLERANCIA_RETRASO_MIN: 30,
} as const;
