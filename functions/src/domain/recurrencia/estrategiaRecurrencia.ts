/**
 * SIAN — Estrategias de recurrencia (patrón Strategy, documento 02, sección 4).
 *
 * Problema que resuelve: cada patrón de repetición calcula la siguiente
 * ocurrencia con su propio algoritmo. Sin Strategy esto sería un `if` anidado
 * de cinco niveles dentro del despachador, que es exactamente donde no se
 * quiere tener lógica delicada.
 *
 * Convenio de tiempo, y conviene leerlo dos veces:
 *   · `fechaInicio` y `fechaFin` son instantes absolutos (UTC, RN-05).
 *   · `horaDelDia` y `franjaHoraria` son hora de pared en la zona institucional.
 *   Todo el cálculo ocurre en la zona institucional y se devuelve en ella; la
 *   conversión a UTC se hace al persistir, no aquí.
 */

import type { DateTime } from 'luxon';

import { ErrorRecurrencia } from '../errores';
import type { HoraLocal } from '../objetosDeValor';

/** Salvaguarda contra un patrón que nunca converge. No debería alcanzarse. */
const MAX_VUELTAS = 5000;

export interface FranjaResuelta {
  readonly desde: HoraLocal;
  readonly hasta: HoraLocal;
}

/** Recurrencia ya validada y expresada en la zona institucional. */
export interface ContextoRecurrencia {
  readonly inicio: DateTime;
  readonly fin: DateTime;
  readonly valorIntervalo: number;
  /** 1 = lunes … 7 = domingo. Vacío significa «todos los días». */
  readonly diasSemana: readonly number[];
  readonly horaDelDia: HoraLocal | null;
  readonly franja: FranjaResuelta | null;
  readonly zona: string;
}

export interface EstrategiaRecurrencia {
  readonly nombre: string;
  /**
   * Devuelve el siguiente disparo válido, o `null` si el patrón se agotó.
   *
   * @param anterior `null` para pedir el primer disparo; en otro caso, el
   *                 disparo anterior ya emitido.
   */
  siguiente(anterior: DateTime | null): DateTime | null;
}

/**
 * Comportamiento común: el bucle de búsqueda y las restricciones.
 *
 * Cada subclase solo decide tres cosas — dónde empieza la rejilla, cómo se
 * avanza en ella, y qué hacer cuando un candidato no cumple las restricciones.
 */
export abstract class EstrategiaBase implements EstrategiaRecurrencia {
  abstract readonly nombre: string;

  constructor(protected readonly ctx: ContextoRecurrencia) {}

  siguiente(anterior: DateTime | null): DateTime | null {
    let candidato =
      anterior === null ? this.primerCandidato() : this.siguienteCandidato(anterior);

    for (let vuelta = 0; vuelta < MAX_VUELTAS; vuelta += 1) {
      if (candidato > this.ctx.fin) {
        return null;
      }
      if (this.cumpleRestricciones(candidato)) {
        return candidato;
      }
      const avanzado = this.reintentar(candidato);
      /* istanbul ignore next — invariante interna: reintentar siempre avanza */
      if (avanzado <= candidato) {
        throw new ErrorRecurrencia(
          'RECURRENCIA_SIN_AVANCE',
          `La estrategia ${this.nombre} no avanzó en el tiempo; sería un bucle infinito.`,
        );
      }
      candidato = avanzado;
    }

    throw new ErrorRecurrencia(
      'RECURRENCIA_SIN_SOLUCION',
      `La estrategia ${this.nombre} no encontró un disparo válido en ${MAX_VUELTAS} intentos. ` +
        'Revisa la combinación de intervalo, días de la semana y franja horaria.',
    );
  }

  // --- puntos de variación -------------------------------------------------

  /** Primer candidato de la rejilla, sin comprobar restricciones todavía. */
  protected abstract primerCandidato(): DateTime;

  /** Siguiente punto de la rejilla a partir de un disparo ya emitido. */
  protected abstract siguienteCandidato(anterior: DateTime): DateTime;

  /** Cómo avanzar cuando el candidato no cumple. Debe avanzar siempre. */
  protected abstract reintentar(candidato: DateTime): DateTime;

  // --- restricciones comunes ----------------------------------------------

  protected cumpleRestricciones(c: DateTime): boolean {
    return (
      c >= this.ctx.inicio &&
      c <= this.ctx.fin &&
      this.cumpleDiaDeSemana(c) &&
      this.cumpleFranja(c)
    );
  }

  /** RF-PRG-07. Luxon usa 1 = lunes … 7 = domingo, igual que el documento 05. */
  protected cumpleDiaDeSemana(c: DateTime): boolean {
    return this.ctx.diasSemana.length === 0 || this.ctx.diasSemana.includes(c.weekday);
  }

  /** RF-PRG-08. Los extremos de la franja se consideran incluidos. */
  protected cumpleFranja(c: DateTime): boolean {
    if (this.ctx.franja === null) {
      return true;
    }
    const minutos = c.hour * 60 + c.minute;
    return (
      minutos >= this.ctx.franja.desde.minutosDesdeMedianoche &&
      minutos <= this.ctx.franja.hasta.minutosDesdeMedianoche
    );
  }

  // --- utilidades ----------------------------------------------------------

  /**
   * Comienzo de la próxima ventana permitida, estrictamente posterior a `c`.
   *
   * Es la respuesta a «son las 19:30 de un viernes, la franja es 07:00–19:00 y
   * solo se envía lunes y miércoles»: el siguiente disparo no es 19:31, es el
   * lunes a las 07:00. Reanudar en el borde de la ventana, en lugar de seguir
   * sumando el intervalo en el vacío, es lo que espera quien programa el aviso.
   */
  protected proximaVentana(c: DateTime): DateTime {
    const hora = this.ctx.franja?.desde.hora ?? 0;
    const minuto = this.ctx.franja?.desde.minuto ?? 0;
    const aInicioDeVentana = (d: DateTime): DateTime =>
      d.set({ hour: hora, minute: minuto, second: 0, millisecond: 0 });

    let v = aInicioDeVentana(c);
    if (v <= c) {
      v = aInicioDeVentana(v.plus({ days: 1 }));
    }
    // Como máximo hay que recorrer una semana para dar con un día permitido.
    for (let i = 0; i < 7 && !this.cumpleDiaDeSemana(v); i += 1) {
      v = aInicioDeVentana(v.plus({ days: 1 }));
    }
    return v;
  }

  /** Fija la hora del día si el patrón la define; si no, deja el candidato tal cual. */
  protected anclarHoraDelDia(c: DateTime): DateTime {
    if (this.ctx.horaDelDia === null) {
      return c;
    }
    return c.set({
      hour: this.ctx.horaDelDia.hora,
      minute: this.ctx.horaDelDia.minuto,
      second: 0,
      millisecond: 0,
    });
  }
}
