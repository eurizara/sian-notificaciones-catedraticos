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

export interface AdjuntoAudio {
  readonly ruta: string;
  readonly bytes: number;
  readonly duracionSeg: number;
}

export interface AdjuntoImagen {
  readonly ruta: string;
  readonly bytes: number;
  readonly tipoMime: string;
  readonly ancho?: number;
  readonly alto?: number;
}

export interface Adjuntos {
  readonly audio?: AdjuntoAudio;
  readonly imagen?: AdjuntoImagen;
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
