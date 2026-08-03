/**
 * SIAN — Entidad Mensaje y su fábrica (patrón Factory Method,
 * documento 02, sección 3).
 *
 * `MensajeFactory.crear` construye la entidad con sus invariantes ya validadas.
 * No existe forma de obtener un Mensaje a medio validar: o sale entero o lanza.
 * Por eso ninguna capa posterior vuelve a comprobar longitudes ni tamaños.
 */

import { ErrorValidacion } from './errores';
import { Cuerpo, Titulo } from './objetosDeValor';
import {
  LIMITES,
  type Adjuntos,
  type Destinatarios,
  type EstadoMensaje,
  type FormatoMensaje,
  type Programacion,
  type TipoMensaje,
} from './tipos';

export interface Mensaje {
  readonly titulo: string;
  readonly cuerpo: string;
  readonly tipo: TipoMensaje;
  readonly formato: readonly FormatoMensaje[];
  readonly adjuntos: Adjuntos;
  readonly requiereConfirmacion: boolean;
  readonly estado: EstadoMensaje;
  readonly destinatarios: Destinatarios;
  readonly programacion: Programacion;
  readonly creadoPor: string;
  readonly creadoEn: Date;
  readonly referenciaCorreccion?: string;
}

export interface EntradaMensaje {
  readonly titulo: string;
  readonly cuerpo: string;
  readonly tipo: TipoMensaje;
  readonly adjuntos?: Adjuntos;
  readonly requiereConfirmacion?: boolean;
  readonly destinatarios: Destinatarios;
  readonly programacion: Programacion;
  readonly creadoPor: string;
  readonly creadoEn?: Date;
  readonly referenciaCorreccion?: string;
}

function exigir(condicion: boolean, codigo: string, mensaje: string, detalle?: Record<string, unknown>): asserts condicion {
  if (!condicion) {
    throw new ErrorValidacion(codigo, mensaje, detalle);
  }
}

/**
 * RN-06 — Una alerta urgente exige doble confirmación del emisor antes de
 * salir. El dominio declara la regla; la interfaz la materializa en un diálogo
 * (RF-MSG-13) y la Function la vuelve a exigir antes de encolar.
 */
export function exigeDobleConfirmacion(tipo: TipoMensaje): boolean {
  return tipo === 'URGENTE';
}

/** Prioridad del ítem en la cola: las urgentes salen primero del mismo lote. */
export function prioridadDeDespacho(tipo: TipoMensaje): number {
  return tipo === 'URGENTE' ? 100 : 0;
}

function validarAdjuntos(adjuntos: Adjuntos): FormatoMensaje[] {
  const formato: FormatoMensaje[] = ['TEXTO'];

  if (adjuntos.audio) {
    const { bytes, duracionSeg, ruta } = adjuntos.audio;
    exigir(typeof ruta === 'string' && ruta.length > 0, 'AUDIO_SIN_RUTA', 'La nota de voz no tiene ruta de almacenamiento.');
    // RF-MSG-07
    exigir(bytes > 0, 'AUDIO_VACIO', 'La nota de voz está vacía.');
    exigir(
      bytes <= LIMITES.AUDIO_MAX_BYTES,
      'AUDIO_MUY_PESADO',
      `La nota de voz no puede exceder ${LIMITES.AUDIO_MAX_BYTES / (1024 * 1024)} MB.`,
      { bytes, maximo: LIMITES.AUDIO_MAX_BYTES },
    );
    exigir(
      duracionSeg > 0 && duracionSeg <= LIMITES.AUDIO_MAX_SEGUNDOS,
      'AUDIO_MUY_LARGO',
      `La nota de voz no puede exceder ${LIMITES.AUDIO_MAX_SEGUNDOS} segundos.`,
      { duracionSeg, maximo: LIMITES.AUDIO_MAX_SEGUNDOS },
    );
    formato.push('VOZ');
  }

  if (adjuntos.imagen) {
    const { bytes, tipoMime, ruta } = adjuntos.imagen;
    exigir(typeof ruta === 'string' && ruta.length > 0, 'IMAGEN_SIN_RUTA', 'La imagen no tiene ruta de almacenamiento.');
    // RF-MSG-08
    exigir(bytes > 0, 'IMAGEN_VACIA', 'La imagen está vacía.');
    exigir(
      bytes <= LIMITES.IMAGEN_MAX_BYTES,
      'IMAGEN_MUY_PESADA',
      `La imagen no puede exceder ${LIMITES.IMAGEN_MAX_BYTES / (1024 * 1024)} MB.`,
      { bytes, maximo: LIMITES.IMAGEN_MAX_BYTES },
    );
    exigir(
      LIMITES.IMAGEN_MIMES.includes(tipoMime),
      'IMAGEN_FORMATO_NO_ADMITIDO',
      `Formato de imagen no admitido: «${tipoMime}». Se admiten JPEG, PNG y WebP.`,
      { tipoMime },
    );
    formato.push('IMAGEN');
  }

  return formato;
}

function validarDestinatarios(d: Destinatarios): void {
  const grupos = d.gruposIds ?? [];
  const usuarios = d.usuariosIds ?? [];

  switch (d.modo) {
    case 'TODOS':
      exigir(
        grupos.length === 0 && usuarios.length === 0,
        'DESTINATARIOS_INCOHERENTES',
        'El modo TODOS no admite listas de grupos ni de usuarios.',
      );
      return;

    case 'GRUPOS':
      exigir(
        grupos.length > 0,
        'DESTINATARIOS_SIN_GRUPOS',
        'El modo GRUPOS exige al menos un grupo destinatario.',
      );
      return;

    case 'INDIVIDUAL':
      exigir(
        usuarios.length > 0,
        'DESTINATARIOS_SIN_USUARIOS',
        'El modo INDIVIDUAL exige al menos un destinatario.',
      );
      return;

    default: {
      const jamas: never = d.modo;
      throw new ErrorValidacion(
        'MODO_DESTINATARIO_INVALIDO',
        `Modo de destinatarios desconocido: «${String(jamas)}».`,
      );
    }
  }
}

function validarProgramacion(p: Programacion): void {
  exigir(
    typeof p.zonaHoraria === 'string' && p.zonaHoraria.length > 0,
    'ZONA_HORARIA_OBLIGATORIA',
    'Toda programación debe declarar la zona horaria institucional (RN-05).',
  );

  if (p.modo === 'UNICO') {
    exigir(
      typeof p.ejecutarEn === 'string' && p.ejecutarEn.length > 0,
      'EJECUTAR_EN_OBLIGATORIO',
      'Una programación de modo UNICO debe declarar `ejecutarEn`.',
    );
  }

  if (p.modo === 'RECURRENTE') {
    exigir(
      p.recurrencia !== undefined,
      'RECURRENCIA_OBLIGATORIA',
      'Una programación de modo RECURRENTE debe declarar el patrón `recurrencia`.',
    );
  }

  if (p.modo === 'INMEDIATO') {
    exigir(
      p.ejecutarEn === undefined && p.recurrencia === undefined,
      'PROGRAMACION_INCOHERENTE',
      'Un envío INMEDIATO no lleva fecha de ejecución ni patrón de recurrencia.',
    );
  }
}

export const MensajeFactory = {
  /**
   * Crea un mensaje en estado BORRADOR con todas sus invariantes verificadas.
   *
   * El formato no se recibe: se deduce de los adjuntos presentes. Así es
   * imposible declarar «lleva voz» y no adjuntarla, que es la incoherencia que
   * más caro sale en el momento del envío.
   */
  crear(entrada: EntradaMensaje): Mensaje {
    const titulo = Titulo.crear(entrada.titulo);
    const cuerpo = Cuerpo.crear(entrada.cuerpo);

    exigir(
      entrada.tipo === 'INFORMATIVO' || entrada.tipo === 'URGENTE',
      'TIPO_MENSAJE_INVALIDO',
      `Tipo de mensaje desconocido: «${String(entrada.tipo)}». Debe ser INFORMATIVO o URGENTE (RF-MSG-02).`,
    );
    exigir(
      typeof entrada.creadoPor === 'string' && entrada.creadoPor.length > 0,
      'EMISOR_OBLIGATORIO',
      'Todo mensaje debe registrar quién lo creó (RF-BIT-02).',
    );

    const adjuntos = entrada.adjuntos ?? {};
    const formato = validarAdjuntos(adjuntos);
    validarDestinatarios(entrada.destinatarios);
    validarProgramacion(entrada.programacion);

    return Object.freeze({
      titulo: titulo.valor,
      cuerpo: cuerpo.valor,
      tipo: entrada.tipo,
      formato: Object.freeze(formato),
      adjuntos,
      requiereConfirmacion: entrada.requiereConfirmacion ?? false,
      estado: 'BORRADOR' as const,
      destinatarios: entrada.destinatarios,
      programacion: entrada.programacion,
      creadoPor: entrada.creadoPor,
      creadoEn: entrada.creadoEn ?? new Date(),
      ...(entrada.referenciaCorreccion ? { referenciaCorreccion: entrada.referenciaCorreccion } : {}),
    });
  },
};
