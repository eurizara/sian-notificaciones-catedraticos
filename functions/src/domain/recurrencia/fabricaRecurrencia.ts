/**
 * SIAN — Fábrica de estrategias de recurrencia (patrón Factory Method).
 *
 * Aquí se valida el patrón completo antes de construir nada. Una recurrencia
 * incoherente se rechaza al crearse, no al dispararse a las tres de la mañana.
 */

import { DateTime } from 'luxon';

import { ErrorRecurrencia } from '../errores';
import { HoraLocal } from '../objetosDeValor';
import { LIMITES, type Recurrencia } from '../tipos';
import type { ContextoRecurrencia, EstrategiaRecurrencia, FranjaResuelta } from './estrategiaRecurrencia';
import { PorDias, PorDiasDeSemana, PorHoras, PorMinutos } from './estrategias';

/** Topes de cordura por unidad. Evitan patrones que nadie quiso escribir. */
const MAXIMO_POR_UNIDAD: Readonly<Record<Recurrencia['unidadIntervalo'], number>> = {
  MINUTOS: 1440, // un día
  HORAS: 168, // una semana
  DIAS: 365, // un año
};

function exigir(condicion: boolean, codigo: string, mensaje: string): asserts condicion {
  if (!condicion) {
    throw new ErrorRecurrencia(codigo, mensaje);
  }
}

function aDateTime(iso: string, zona: string, campo: string): DateTime {
  const dt = DateTime.fromISO(iso, { zone: zona });
  exigir(dt.isValid, 'FECHA_INVALIDA', `El campo ${campo} no es una fecha ISO 8601 válida: «${iso}».`);
  return dt;
}

/**
 * Valida el patrón y lo traduce a un contexto expresado en la zona
 * institucional, listo para que las estrategias operen sobre él.
 */
export function resolverContexto(rec: Recurrencia, zona: string): ContextoRecurrencia {
  exigir(
    DateTime.local().setZone(zona).isValid,
    'ZONA_HORARIA_INVALIDA',
    `«${zona}» no es una zona horaria IANA reconocida.`,
  );

  const inicio = aDateTime(rec.fechaInicio, zona, 'fechaInicio');
  // RF-PRG-14: la fecha de fin es obligatoria. Sin ella no hay recurrencia,
  // hay un bucle.
  exigir(
    typeof rec.fechaFin === 'string' && rec.fechaFin.length > 0,
    'FECHA_FIN_OBLIGATORIA',
    'Toda recurrencia debe declarar fecha de fin.',
  );
  const fin = aDateTime(rec.fechaFin, zona, 'fechaFin');

  exigir(fin > inicio, 'RANGO_INVALIDO', 'La fecha de fin debe ser posterior a la de inicio.');

  exigir(
    Number.isInteger(rec.valorIntervalo) && rec.valorIntervalo >= 1,
    'INTERVALO_INVALIDO',
    'El intervalo de repetición debe ser un entero mayor o igual a 1.',
  );
  const tope = MAXIMO_POR_UNIDAD[rec.unidadIntervalo];
  exigir(
    tope !== undefined,
    'UNIDAD_INTERVALO_INVALIDA',
    `Unidad de intervalo desconocida: «${rec.unidadIntervalo}».`,
  );
  exigir(
    rec.valorIntervalo <= tope,
    'INTERVALO_FUERA_DE_RANGO',
    `Un intervalo en ${rec.unidadIntervalo} no puede exceder ${tope}.`,
  );

  const diasSemana = [...new Set(rec.diasSemana ?? [])].sort((a, b) => a - b);
  for (const d of diasSemana) {
    exigir(
      Number.isInteger(d) && d >= 1 && d <= 7,
      'DIA_SEMANA_INVALIDO',
      `Día de la semana fuera de rango: ${d}. Se espera 1 (lunes) a 7 (domingo).`,
    );
  }

  const horaDelDia = rec.horaDelDia ? HoraLocal.crear(rec.horaDelDia) : null;

  let franja: FranjaResuelta | null = null;
  if (rec.franjaHoraria) {
    const desde = HoraLocal.crear(rec.franjaHoraria.desde);
    const hasta = HoraLocal.crear(rec.franjaHoraria.hasta);
    exigir(
      desde.minutosDesdeMedianoche < hasta.minutosDesdeMedianoche,
      'FRANJA_INVALIDA',
      'La franja horaria debe empezar antes de terminar. No se admiten franjas que crucen la medianoche.',
    );
    franja = { desde, hasta };
  }

  if (horaDelDia && franja) {
    exigir(
      horaDelDia.minutosDesdeMedianoche >= franja.desde.minutosDesdeMedianoche &&
        horaDelDia.minutosDesdeMedianoche <= franja.hasta.minutosDesdeMedianoche,
      'HORA_FUERA_DE_FRANJA',
      `La hora del día (${horaDelDia.valor}) queda fuera de la franja ` +
        `${franja.desde.valor}–${franja.hasta.valor}: el patrón no dispararía nunca.`,
    );
  }

  exigir(
    Number.isInteger(rec.maxOcurrencias) &&
      rec.maxOcurrencias >= 1 &&
      rec.maxOcurrencias <= LIMITES.MAX_OCURRENCIAS_POR_MENSAJE,
    'MAX_OCURRENCIAS_INVALIDO',
    `El máximo de ocurrencias debe estar entre 1 y ${LIMITES.MAX_OCURRENCIAS_POR_MENSAJE} (RF-PRG-14).`,
  );

  return {
    inicio,
    fin,
    valorIntervalo: rec.valorIntervalo,
    diasSemana,
    horaDelDia,
    franja,
    zona,
  };
}

/**
 * Elige e instancia la estrategia que corresponde al patrón.
 *
 * La única elección con matiz es la de días: «cada 1 día, solo lunes y
 * miércoles» es un patrón semanal (PorDiasDeSemana), mientras que «cada 3 días,
 * solo lunes y miércoles» sí es una rejilla de 3 días a la que además se le
 * aplica un filtro (PorDias). Así ningún dato que escribió el emisor se ignora
 * en silencio.
 */
export function crearEstrategia(rec: Recurrencia, zona: string): EstrategiaRecurrencia {
  const ctx = resolverContexto(rec, zona);

  switch (rec.unidadIntervalo) {
    case 'MINUTOS':
      return new PorMinutos(ctx);
    case 'HORAS':
      return new PorHoras(ctx);
    case 'DIAS':
      return ctx.diasSemana.length > 0 && ctx.valorIntervalo === 1
        ? new PorDiasDeSemana(ctx)
        : new PorDias(ctx);
    default: {
      const jamas: never = rec.unidadIntervalo;
      throw new ErrorRecurrencia(
        'UNIDAD_INTERVALO_INVALIDA',
        `Unidad de intervalo desconocida: «${String(jamas)}».`,
      );
    }
  }
}
