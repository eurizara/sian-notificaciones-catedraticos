/**
 * SIAN — Planificación: qué se dispara, cuándo, y qué hacer si llegó tarde.
 *
 * Estas funciones son puras. El despachador las usa, pero también las usa el
 * panel para enseñarle al emisor las próximas 10 ocurrencias antes de guardar
 * (RF-PRG-09). Que sean la misma implementación es justamente lo que evita que
 * la vista previa mienta.
 */

import { DateTime } from 'luxon';

import { ErrorRecurrencia } from '../errores';
import { LIMITES, type Programacion, type Recurrencia } from '../tipos';
import { crearEstrategia } from './fabricaRecurrencia';

/** Qué debe hacer el despachador con una ocurrencia vencida (RF-PRG-13). */
export type DecisionDespacho = 'ESPERAR' | 'DESPACHAR' | 'OMITIR';

export interface OcurrenciaCalculada {
  readonly numero: number;
  /** Instante absoluto del disparo. */
  readonly previstaPara: Date;
  /** El mismo instante en hora local institucional, para mostrarlo tal cual. */
  readonly previstaParaLocal: string;
}

/**
 * Calcula las próximas ocurrencias de un patrón recurrente (RF-PRG-09).
 *
 * Respeta a la vez las tres condiciones de parada del documento 01: la fecha de
 * fin, el máximo de ocurrencias del patrón y el tope duro de 500 por mensaje
 * (RF-PRG-14).
 *
 * @param cantidad  Cuántas se quieren, como mucho.
 * @param desde     Punto a partir del cual seguir. `null` calcula desde el
 *                  principio del patrón.
 */
export function calcularProximasOcurrencias(
  rec: Recurrencia,
  zona: string,
  cantidad: number = LIMITES.VISTA_PREVIA_OCURRENCIAS,
  desde: Date | null = null,
): OcurrenciaCalculada[] {
  if (!Number.isInteger(cantidad) || cantidad < 1) {
    throw new ErrorRecurrencia(
      'CANTIDAD_INVALIDA',
      'La cantidad de ocurrencias a calcular debe ser un entero mayor o igual a 1.',
    );
  }

  const estrategia = crearEstrategia(rec, zona);
  const yaGeneradas = rec.ocurrenciasGeneradas ?? 0;
  const restantesDelPatron = Math.max(0, rec.maxOcurrencias - yaGeneradas);
  const aCalcular = Math.min(cantidad, restantesDelPatron);

  const resultado: OcurrenciaCalculada[] = [];
  let anterior: DateTime | null = desde === null ? null : DateTime.fromJSDate(desde, { zone: zona });

  for (let i = 0; i < aCalcular; i += 1) {
    const siguiente: DateTime | null = estrategia.siguiente(anterior);
    if (siguiente === null) {
      break;
    }
    resultado.push({
      numero: yaGeneradas + i + 1,
      previstaPara: siguiente.toJSDate(),
      previstaParaLocal: siguiente.toFormat("yyyy-LL-dd HH:mm ('UTC'ZZ)"),
    });
    anterior = siguiente;
  }

  return resultado;
}

/**
 * Primera ocurrencia de una programación cualquiera.
 *
 * Es lo que la Function `programarMensaje` inserta en `cola_despacho`
 * (documento 02, sección 5.2). Devuelve `null` si el patrón ya nace agotado.
 */
export function calcularPrimeraOcurrencia(prog: Programacion, ahora: Date = new Date()): Date | null {
  switch (prog.modo) {
    case 'INMEDIATO':
      return ahora;

    case 'UNICO': {
      if (!prog.ejecutarEn) {
        throw new ErrorRecurrencia(
          'EJECUTAR_EN_OBLIGATORIO',
          'Una programación de modo UNICO debe declarar `ejecutarEn`.',
        );
      }
      const dt = DateTime.fromISO(prog.ejecutarEn, { zone: prog.zonaHoraria });
      if (!dt.isValid) {
        throw new ErrorRecurrencia(
          'FECHA_INVALIDA',
          `«${prog.ejecutarEn}» no es una fecha ISO 8601 válida.`,
        );
      }
      // RF-PRG-04: el sistema rechaza una programación cuya hora ya pasó.
      if (dt.toMillis() <= ahora.getTime()) {
        throw new ErrorRecurrencia(
          'PROGRAMACION_EN_PASADO',
          'No se puede programar un mensaje para una fecha y hora que ya pasaron.',
        );
      }
      return dt.toJSDate();
    }

    case 'RECURRENTE': {
      if (!prog.recurrencia) {
        throw new ErrorRecurrencia(
          'RECURRENCIA_OBLIGATORIA',
          'Una programación de modo RECURRENTE debe declarar el patrón `recurrencia`.',
        );
      }
      const [primera] = calcularProximasOcurrencias(prog.recurrencia, prog.zonaHoraria, 1);
      return primera ? primera.previstaPara : null;
    }

    default: {
      const jamas: never = prog.modo;
      throw new ErrorRecurrencia(
        'MODO_PROGRAMACION_INVALIDO',
        `Modo de programación desconocido: «${String(jamas)}».`,
      );
    }
  }
}

/**
 * Decide qué hacer con una ocurrencia que el despachador acaba de tomar
 * (RF-PRG-13).
 *
 * · Todavía no toca             → ESPERAR
 * · Venció dentro de tolerancia → DESPACHAR
 * · Venció hace demasiado       → OMITIR, y queda asiento en bitácora
 *
 * El caso que importa es el tercero: si el sistema estuvo caído dos días, nadie
 * quiere que al volver salga de golpe el aviso de un simulacro de anteayer.
 */
export function decidirDespacho(
  previstaPara: Date,
  ahora: Date = new Date(),
  toleranciaMinutos: number = LIMITES.TOLERANCIA_RETRASO_MIN,
): DecisionDespacho {
  if (toleranciaMinutos < 0) {
    throw new ErrorRecurrencia(
      'TOLERANCIA_INVALIDA',
      'La tolerancia de retraso no puede ser negativa.',
    );
  }

  const retrasoMin = (ahora.getTime() - previstaPara.getTime()) / 60000;
  if (retrasoMin < 0) {
    return 'ESPERAR';
  }
  return retrasoMin <= toleranciaMinutos ? 'DESPACHAR' : 'OMITIR';
}

/** Desviación en segundos entre la hora prevista y la real. Evidencia de RNF-04. */
export function desviacionSegundos(previstaPara: Date, ejecutadaEn: Date): number {
  return Math.round((ejecutadaEn.getTime() - previstaPara.getTime()) / 1000);
}

/**
 * ¿El patrón llegó a su tope de ocurrencias? (RF-PRG-14)
 *
 * Al agotarse, la recurrencia se detiene, se marca como AGOTADO y se notifica
 * a su creador.
 */
export function recurrenciaAgotada(rec: Recurrencia): boolean {
  const generadas = rec.ocurrenciasGeneradas ?? 0;
  return generadas >= Math.min(rec.maxOcurrencias, LIMITES.MAX_OCURRENCIAS_POR_MENSAJE);
}

/** ¿Está suspendida temporalmente? (RF-PRG-10) */
export function recurrenciaSuspendida(rec: Recurrencia): boolean {
  return rec.suspendida === true;
}
