/**
 * SIAN — Las cuatro estrategias concretas de recurrencia
 * (documento 02, sección 3 · RF-PRG-05..08).
 */

import type { DateTime } from 'luxon';

import { EstrategiaBase } from './estrategiaRecurrencia';

/**
 * «Cada N minutos», dentro de los días y la franja permitidos.
 *
 * Es el patrón del simulacro: cada 2 minutos durante 10 minutos.
 */
export class PorMinutos extends EstrategiaBase {
  readonly nombre = 'POR_MINUTOS';

  protected primerCandidato(): DateTime {
    return this.ctx.inicio;
  }

  protected siguienteCandidato(anterior: DateTime): DateTime {
    return anterior.plus({ minutes: this.ctx.valorIntervalo });
  }

  protected reintentar(candidato: DateTime): DateTime {
    return this.proximaVentana(candidato);
  }
}

/** «Cada N horas», dentro de los días y la franja permitidos. */
export class PorHoras extends EstrategiaBase {
  readonly nombre = 'POR_HORAS';

  protected primerCandidato(): DateTime {
    return this.ctx.inicio;
  }

  protected siguienteCandidato(anterior: DateTime): DateTime {
    return anterior.plus({ hours: this.ctx.valorIntervalo });
  }

  protected reintentar(candidato: DateTime): DateTime {
    return this.proximaVentana(candidato);
  }
}

/**
 * «Cada N días», opcionalmente a una hora fija del día.
 *
 * Si además se restringen días de la semana, un disparo que caiga en un día no
 * permitido no se adelanta ni se atrasa: se salta, y se prueba el siguiente
 * múltiplo de N días. La rejilla manda sobre la restricción.
 */
export class PorDias extends EstrategiaBase {
  readonly nombre = 'POR_DIAS';

  protected primerCandidato(): DateTime {
    const anclado = this.anclarHoraDelDia(this.ctx.inicio);
    // Si anclar la hora dejó el disparo antes del inicio, es que hoy ya pasó.
    return anclado >= this.ctx.inicio ? anclado : this.anclarHoraDelDia(anclado.plus({ days: 1 }));
  }

  protected siguienteCandidato(anterior: DateTime): DateTime {
    return this.anclarHoraDelDia(anterior.plus({ days: this.ctx.valorIntervalo }));
  }

  protected reintentar(candidato: DateTime): DateTime {
    return this.anclarHoraDelDia(candidato.plus({ days: this.ctx.valorIntervalo }));
  }
}

/**
 * «Los días L/M/X/J/V/S/D indicados, a una hora fija» (RF-PRG-07).
 *
 * Se distingue de {@link PorDias} en que aquí la rejilla es el calendario
 * semanal, no un múltiplo de días: «lunes, miércoles y viernes a las 07:30»
 * no es «cada 2 días».
 */
export class PorDiasDeSemana extends EstrategiaBase {
  readonly nombre = 'POR_DIAS_DE_SEMANA';

  protected primerCandidato(): DateTime {
    const anclado = this.anclarHoraDelDia(this.ctx.inicio);
    return anclado >= this.ctx.inicio ? anclado : this.anclarHoraDelDia(anclado.plus({ days: 1 }));
  }

  protected siguienteCandidato(anterior: DateTime): DateTime {
    return this.anclarHoraDelDia(anterior.plus({ days: 1 }));
  }

  protected reintentar(candidato: DateTime): DateTime {
    return this.anclarHoraDelDia(candidato.plus({ days: 1 }));
  }
}
