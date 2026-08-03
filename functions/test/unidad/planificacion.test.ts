/**
 * Pruebas de planificación — RF-PRG-01, RF-PRG-04, RF-PRG-13, RF-PRG-14, RNF-04.
 */

import { DateTime } from 'luxon';

import { ErrorRecurrencia } from '../../src/domain/errores';
import {
  calcularPrimeraOcurrencia,
  decidirDespacho,
  desviacionSegundos,
  recurrenciaAgotada,
  recurrenciaSuspendida,
} from '../../src/domain/recurrencia/planificacion';
import type { Programacion, Recurrencia } from '../../src/domain/tipos';
import { esperarCodigo } from './ayudas';

const ZONA = 'America/Guatemala';
const AHORA = new Date('2026-08-03T13:00:00.000Z'); // 07:00 en Guatemala

function utc(fechaLocal: string): string {
  return DateTime.fromISO(fechaLocal, { zone: ZONA }).toUTC().toISO() as string;
}

describe('calcularPrimeraOcurrencia', () => {
  it('RF-PRG-01 · un envío inmediato se dispara ahora', () => {
    const prog: Programacion = { modo: 'INMEDIATO', zonaHoraria: ZONA };
    expect(calcularPrimeraOcurrencia(prog, AHORA)).toEqual(AHORA);
  });

  it('RF-PRG-02 · un envío único se dispara en la fecha indicada', () => {
    const prog: Programacion = {
      modo: 'UNICO',
      zonaHoraria: ZONA,
      ejecutarEn: utc('2026-08-15T14:00'),
    };
    expect(calcularPrimeraOcurrencia(prog, AHORA)?.toISOString()).toBe(
      new Date(utc('2026-08-15T14:00')).toISOString(),
    );
  });

  it('RF-PRG-04 · rechaza una programación cuya hora ya pasó', () => {
    const prog: Programacion = {
      modo: 'UNICO',
      zonaHoraria: ZONA,
      ejecutarEn: utc('2026-08-01T09:00'),
    };
    esperarCodigo(() => calcularPrimeraOcurrencia(prog, AHORA), 'PROGRAMACION_EN_PASADO');
  });

  it('rechaza el instante exacto de ahora: programar para «ya» es envío inmediato', () => {
    const prog: Programacion = {
      modo: 'UNICO',
      zonaHoraria: ZONA,
      ejecutarEn: AHORA.toISOString(),
    };
    expect(() => calcularPrimeraOcurrencia(prog, AHORA)).toThrow(ErrorRecurrencia);
  });

  it('devuelve la primera ocurrencia de un patrón recurrente', () => {
    const prog: Programacion = {
      modo: 'RECURRENTE',
      zonaHoraria: ZONA,
      recurrencia: {
        fechaInicio: utc('2026-08-05T07:30'),
        fechaFin: utc('2026-08-31T23:59'),
        unidadIntervalo: 'DIAS',
        valorIntervalo: 1,
        horaDelDia: '07:30',
        maxOcurrencias: 500,
      },
    };
    expect(calcularPrimeraOcurrencia(prog, AHORA)?.toISOString()).toBe(
      new Date(utc('2026-08-05T07:30')).toISOString(),
    );
  });

  it('devuelve null cuando el patrón recurrente ya nace agotado', () => {
    const prog: Programacion = {
      modo: 'RECURRENTE',
      zonaHoraria: ZONA,
      recurrencia: {
        fechaInicio: utc('2026-08-05T07:30'),
        fechaFin: utc('2026-08-31T23:59'),
        unidadIntervalo: 'DIAS',
        valorIntervalo: 1,
        maxOcurrencias: 5,
        ocurrenciasGeneradas: 5,
      },
    };
    expect(calcularPrimeraOcurrencia(prog, AHORA)).toBeNull();
  });

  it('exige los campos coherentes con el modo declarado', () => {
    esperarCodigo(
      () => calcularPrimeraOcurrencia({ modo: 'UNICO', zonaHoraria: ZONA }, AHORA),
      'EJECUTAR_EN_OBLIGATORIO',
    );
    esperarCodigo(
      () => calcularPrimeraOcurrencia({ modo: 'RECURRENTE', zonaHoraria: ZONA }, AHORA),
      'RECURRENCIA_OBLIGATORIA',
    );
  });
});

describe('RF-PRG-13 · decisión del despachador ante una ocurrencia vencida', () => {
  const prevista = new Date('2026-08-03T13:00:00.000Z');

  it('espera si todavía no toca', () => {
    const antes = new Date(prevista.getTime() - 60_000);
    expect(decidirDespacho(prevista, antes, 30)).toBe('ESPERAR');
  });

  it('despacha si venció dentro de la tolerancia', () => {
    expect(decidirDespacho(prevista, prevista, 30)).toBe('DESPACHAR');
    expect(decidirDespacho(prevista, new Date(prevista.getTime() + 29 * 60_000), 30)).toBe(
      'DESPACHAR',
    );
    // El borde exacto de la tolerancia todavía se despacha.
    expect(decidirDespacho(prevista, new Date(prevista.getTime() + 30 * 60_000), 30)).toBe(
      'DESPACHAR',
    );
  });

  it('omite si el retraso excede la tolerancia', () => {
    // El caso que importa: el sistema estuvo caído dos días y nadie quiere que
    // al volver salga de golpe el aviso de un simulacro de anteayer.
    const dosDiasTarde = new Date(prevista.getTime() + 48 * 60 * 60_000);
    expect(decidirDespacho(prevista, dosDiasTarde, 30)).toBe('OMITIR');
  });

  it('usa 30 minutos como tolerancia por omisión (documento 05, sección 2.11)', () => {
    expect(decidirDespacho(prevista, new Date(prevista.getTime() + 31 * 60_000))).toBe('OMITIR');
    expect(decidirDespacho(prevista, new Date(prevista.getTime() + 29 * 60_000))).toBe('DESPACHAR');
  });

  it('rechaza una tolerancia negativa', () => {
    expect(() => decidirDespacho(prevista, prevista, -1)).toThrow(ErrorRecurrencia);
  });
});

describe('RNF-04 · evidencia de precisión temporal', () => {
  it('mide la desviación en segundos entre lo previsto y lo ejecutado', () => {
    const prevista = new Date('2026-08-03T13:00:00.000Z');
    expect(desviacionSegundos(prevista, new Date('2026-08-03T13:00:45.000Z'))).toBe(45);
    expect(desviacionSegundos(prevista, prevista)).toBe(0);
    // Una ejecución adelantada da desviación negativa, no un valor absoluto:
    // interesa saber en qué dirección se desvió.
    expect(desviacionSegundos(prevista, new Date('2026-08-03T12:59:50.000Z'))).toBe(-10);
  });
});

describe('RF-PRG-14 · agotamiento y suspensión', () => {
  const base: Recurrencia = {
    fechaInicio: utc('2026-08-03T07:00'),
    fechaFin: utc('2026-08-31T23:59'),
    unidadIntervalo: 'DIAS',
    valorIntervalo: 1,
    maxOcurrencias: 10,
  };

  it('detecta el agotamiento al alcanzar el máximo declarado', () => {
    expect(recurrenciaAgotada({ ...base, ocurrenciasGeneradas: 9 })).toBe(false);
    expect(recurrenciaAgotada({ ...base, ocurrenciasGeneradas: 10 })).toBe(true);
    expect(recurrenciaAgotada({ ...base, ocurrenciasGeneradas: 11 })).toBe(true);
  });

  it('trata la ausencia de contador como cero ocurrencias generadas', () => {
    expect(recurrenciaAgotada(base)).toBe(false);
  });

  it('aplica el tope duro de 500 aunque el patrón declare más', () => {
    expect(
      recurrenciaAgotada({ ...base, maxOcurrencias: 100_000, ocurrenciasGeneradas: 500 }),
    ).toBe(true);
  });

  it('RF-PRG-10 · distingue suspendida de agotada', () => {
    expect(recurrenciaSuspendida({ ...base, suspendida: true })).toBe(true);
    expect(recurrenciaSuspendida(base)).toBe(false);
    expect(recurrenciaAgotada({ ...base, suspendida: true })).toBe(false);
  });
});
