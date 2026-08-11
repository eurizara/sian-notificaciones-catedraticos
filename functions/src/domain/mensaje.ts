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
  normalizarAdjuntos,
  type Adjunto,
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

/**
 * Valida los adjuntos y deduce el formato del mensaje.
 *
 * ---------------------------------------------------------------------------
 * Se valida la LISTA, en su orden, y las cuentas del conjunto.
 * ---------------------------------------------------------------------------
 *
 * Cada pieza tiene su límite (RF-MSG-07, RF-MSG-08), pero además hay límites
 * que solo existen mirando el conjunto: cuántas caben y cuánto pesan sumadas.
 * Un aviso de 19 MB en una conexión mala no es un aviso.
 */
function validarAdjuntos(lista: readonly Adjunto[]): FormatoMensaje[] {
  const formato: FormatoMensaje[] = ['TEXTO'];

  let audios = 0;
  let imagenes = 0;
  let total = 0;

  for (const [i, a] of lista.entries()) {
    // El índice viaja en el detalle: con cinco adjuntos, «la imagen está
    // vacía» no dice cuál, y el emisor tiene que adivinar cuál quitar.
    const donde = { posicion: i + 1 };

    exigir(
      typeof a.ruta === 'string' && a.ruta.length > 0,
      'ADJUNTO_SIN_RUTA',
      `El adjunto ${i + 1} no tiene ruta de almacenamiento.`,
      donde,
    );
    exigir(a.bytes > 0, 'ADJUNTO_VACIO', `El adjunto ${i + 1} está vacío.`, donde);

    total += a.bytes;

    if (a.tipo === 'AUDIO') {
      audios += 1;
      // RF-MSG-07
      exigir(
        a.bytes <= LIMITES.AUDIO_MAX_BYTES,
        'AUDIO_MUY_PESADO',
        `La nota de voz no puede exceder ${LIMITES.AUDIO_MAX_BYTES / (1024 * 1024)} MB.`,
        { ...donde, bytes: a.bytes, maximo: LIMITES.AUDIO_MAX_BYTES },
      );
      const duracionSeg = a.duracionSeg ?? 0;
      exigir(
        duracionSeg > 0 && duracionSeg <= LIMITES.AUDIO_MAX_SEGUNDOS,
        'AUDIO_MUY_LARGO',
        `La nota de voz no puede exceder ${LIMITES.AUDIO_MAX_SEGUNDOS} segundos.`,
        { ...donde, duracionSeg, maximo: LIMITES.AUDIO_MAX_SEGUNDOS },
      );
      continue;
    }

    imagenes += 1;
    // RF-MSG-08
    exigir(
      a.bytes <= LIMITES.IMAGEN_MAX_BYTES,
      'IMAGEN_MUY_PESADA',
      `La imagen no puede exceder ${LIMITES.IMAGEN_MAX_BYTES / (1024 * 1024)} MB.`,
      { ...donde, bytes: a.bytes, maximo: LIMITES.IMAGEN_MAX_BYTES },
    );
    exigir(
      LIMITES.IMAGEN_MIMES.includes(a.tipoMime),
      'IMAGEN_FORMATO_NO_ADMITIDO',
      `Formato de imagen no admitido: «${a.tipoMime}». Se admiten JPEG, PNG y WebP.`,
      { ...donde, tipoMime: a.tipoMime },
    );
  }

  exigir(
    audios <= LIMITES.MAX_AUDIOS,
    'DEMASIADAS_NOTAS_DE_VOZ',
    `Un mensaje admite hasta ${LIMITES.MAX_AUDIOS} notas de voz.`,
    { audios, maximo: LIMITES.MAX_AUDIOS },
  );
  exigir(
    imagenes <= LIMITES.MAX_IMAGENES,
    'DEMASIADAS_IMAGENES',
    `Un mensaje admite hasta ${LIMITES.MAX_IMAGENES} imágenes.`,
    { imagenes, maximo: LIMITES.MAX_IMAGENES },
  );
  exigir(
    total <= LIMITES.ADJUNTOS_MAX_BYTES_TOTAL,
    'ADJUNTOS_MUY_PESADOS',
    `Los adjuntos suman más de ${LIMITES.ADJUNTOS_MAX_BYTES_TOTAL / (1024 * 1024)} MB. ` +
      'Quita alguno: con una conexión mala, un mensaje así no llega.',
    { total, maximo: LIMITES.ADJUNTOS_MAX_BYTES_TOTAL },
  );

  if (audios > 0) {
    formato.push('VOZ');
  }
  if (imagenes > 0) {
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

    // Se guarda SIEMPRE en la forma nueva, venga como venga. Que convivan dos
    // maneras de escribir lo mismo garantiza que tarde o temprano una de las
    // dos deje de leerse en algún sitio.
    const lista = normalizarAdjuntos(entrada.adjuntos);
    const formato = validarAdjuntos(lista);
    validarDestinatarios(entrada.destinatarios);
    validarProgramacion(entrada.programacion);

    return Object.freeze({
      titulo: titulo.valor,
      cuerpo: cuerpo.valor,
      tipo: entrada.tipo,
      formato: Object.freeze(formato),
      adjuntos: Object.freeze({ lista: Object.freeze(lista) }),
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
