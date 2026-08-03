/**
 * Pruebas de las estrategias de recurrencia — RF-PRG-05 a RF-PRG-09, RF-PRG-14.
 *
 * Zona de referencia: America/Guatemala (UTC-6, sin horario de verano), que es
 * la zona institucional por omisión del documento 05, sección 2.11.
 *
 * Fechas de referencia usadas en todo el archivo:
 *   2026-08-03 lunes · 2026-08-05 miércoles · 2026-08-07 viernes
 */

import { DateTime } from 'luxon';

import { ErrorRecurrencia } from '../../src/domain/errores';
import { PorDias, PorDiasDeSemana, PorHoras, PorMinutos } from '../../src/domain/recurrencia/estrategias';
import { crearEstrategia } from '../../src/domain/recurrencia/fabricaRecurrencia';
import { calcularProximasOcurrencias } from '../../src/domain/recurrencia/planificacion';
import type { Recurrencia } from '../../src/domain/tipos';

const ZONA = 'America/Guatemala';

/** Formatea el resultado en hora local, que es como lo lee un humano. */
function local(fechas: { previstaPara: Date }[]): string[] {
  return fechas.map((o) => DateTime.fromJSDate(o.previstaPara, { zone: ZONA }).toFormat('yyyy-LL-dd HH:mm'));
}

function enUtc(fechaLocal: string): string {
  return DateTime.fromISO(fechaLocal, { zone: ZONA }).toUTC().toISO() as string;
}

function recurrenciaBase(parcial: Partial<Recurrencia> = {}): Recurrencia {
  return {
    fechaInicio: enUtc('2026-08-03T07:00'),
    fechaFin: enUtc('2026-08-31T23:59'),
    unidadIntervalo: 'DIAS',
    valorIntervalo: 1,
    maxOcurrencias: 500,
    ...parcial,
  };
}

describe('RF-PRG-06 · intervalo en minutos', () => {
  it('dispara cada N minutos desde la fecha de inicio', () => {
    const rec = recurrenciaBase({
      unidadIntervalo: 'MINUTOS',
      valorIntervalo: 2,
      fechaInicio: enUtc('2026-08-03T07:00'),
      fechaFin: enUtc('2026-08-03T07:10'),
    });

    // Es el caso de la lista de verificación de la demostración (documento 06,
    // etapa E.6): recurrente cada 2 minutos con fin en 10 minutos.
    expect(local(calcularProximasOcurrencias(rec, ZONA, 20))).toEqual([
      '2026-08-03 07:00',
      '2026-08-03 07:02',
      '2026-08-03 07:04',
      '2026-08-03 07:06',
      '2026-08-03 07:08',
      '2026-08-03 07:10',
    ]);
  });

  it('no produce ninguna ocurrencia después de la fecha de fin', () => {
    const rec = recurrenciaBase({
      unidadIntervalo: 'MINUTOS',
      valorIntervalo: 15,
      fechaInicio: enUtc('2026-08-03T07:00'),
      fechaFin: enUtc('2026-08-03T07:20'),
    });

    const ocurrencias = calcularProximasOcurrencias(rec, ZONA, 50);
    expect(ocurrencias).toHaveLength(2); // 07:00 y 07:15
    expect(local(ocurrencias).at(-1)).toBe('2026-08-03 07:15');
  });
});

describe('RF-PRG-08 · franja horaria diaria', () => {
  it('reanuda al inicio de la franja del día siguiente en vez de seguir sumando en el vacío', () => {
    const rec = recurrenciaBase({
      unidadIntervalo: 'HORAS',
      valorIntervalo: 4,
      fechaInicio: enUtc('2026-08-03T07:00'),
      fechaFin: enUtc('2026-08-04T23:59'),
      franjaHoraria: { desde: '07:00', hasta: '19:00' },
    });

    expect(local(calcularProximasOcurrencias(rec, ZONA, 8))).toEqual([
      '2026-08-03 07:00',
      '2026-08-03 11:00',
      '2026-08-03 15:00',
      '2026-08-03 19:00',
      // 23:00 cae fuera de la franja: se reanuda el día siguiente a las 07:00.
      '2026-08-04 07:00',
      '2026-08-04 11:00',
      '2026-08-04 15:00',
      '2026-08-04 19:00',
    ]);
  });
});

describe('RF-PRG-07 · restricción por días de la semana', () => {
  it('con intervalo de 1 día, dispara solo en los días indicados a la hora fijada', () => {
    const rec = recurrenciaBase({
      unidadIntervalo: 'DIAS',
      valorIntervalo: 1,
      diasSemana: [1, 3, 5], // lunes, miércoles, viernes
      horaDelDia: '07:30',
      fechaInicio: enUtc('2026-08-03T00:00'),
      fechaFin: enUtc('2026-08-14T23:59'),
    });

    expect(local(calcularProximasOcurrencias(rec, ZONA, 6))).toEqual([
      '2026-08-03 07:30', // lunes
      '2026-08-05 07:30', // miércoles
      '2026-08-07 07:30', // viernes
      '2026-08-10 07:30',
      '2026-08-12 07:30',
      '2026-08-14 07:30',
    ]);
  });

  it('salta los minutos que caen en un día no permitido', () => {
    const rec = recurrenciaBase({
      unidadIntervalo: 'HORAS',
      valorIntervalo: 12,
      diasSemana: [1], // solo lunes
      fechaInicio: enUtc('2026-08-03T08:00'),
      fechaFin: enUtc('2026-08-11T23:59'),
    });

    expect(local(calcularProximasOcurrencias(rec, ZONA, 4))).toEqual([
      '2026-08-03 08:00',
      '2026-08-03 20:00',
      // martes a domingo quedan fuera: se reanuda el lunes siguiente a las 00:00.
      '2026-08-10 00:00',
      '2026-08-10 12:00',
    ]);
  });
});

describe('Selección de estrategia (Factory Method)', () => {
  it('elige PorMinutos, PorHoras, PorDias y PorDiasDeSemana según el patrón', () => {
    expect(crearEstrategia(recurrenciaBase({ unidadIntervalo: 'MINUTOS', valorIntervalo: 5 }), ZONA))
      .toBeInstanceOf(PorMinutos);

    expect(crearEstrategia(recurrenciaBase({ unidadIntervalo: 'HORAS', valorIntervalo: 3 }), ZONA))
      .toBeInstanceOf(PorHoras);

    // Días sin restricción semanal → rejilla de N días.
    expect(crearEstrategia(recurrenciaBase({ unidadIntervalo: 'DIAS', valorIntervalo: 3 }), ZONA))
      .toBeInstanceOf(PorDias);

    // «Cada 1 día, solo lunes y miércoles» es en realidad un patrón semanal.
    expect(
      crearEstrategia(
        recurrenciaBase({ unidadIntervalo: 'DIAS', valorIntervalo: 1, diasSemana: [1, 3] }),
        ZONA,
      ),
    ).toBeInstanceOf(PorDiasDeSemana);

    // «Cada 3 días, solo lunes y miércoles» sí es una rejilla de 3 días con
    // filtro: nada de lo que escribió el emisor se ignora en silencio.
    expect(
      crearEstrategia(
        recurrenciaBase({ unidadIntervalo: 'DIAS', valorIntervalo: 3, diasSemana: [1, 3] }),
        ZONA,
      ),
    ).toBeInstanceOf(PorDias);
  });

  it('ancla al día siguiente cuando la hora del día ya pasó en la fecha de inicio', () => {
    const rec = recurrenciaBase({
      unidadIntervalo: 'DIAS',
      valorIntervalo: 1,
      horaDelDia: '07:30',
      fechaInicio: enUtc('2026-08-03T10:00'), // ya pasaron las 07:30
      fechaFin: enUtc('2026-08-06T23:59'),
    });

    expect(local(calcularProximasOcurrencias(rec, ZONA, 2))).toEqual([
      '2026-08-04 07:30',
      '2026-08-05 07:30',
    ]);
  });
});

describe('RF-PRG-14 · salvaguardas contra bucles de envío', () => {
  it('respeta el máximo de ocurrencias del patrón', () => {
    const rec = recurrenciaBase({
      unidadIntervalo: 'MINUTOS',
      valorIntervalo: 1,
      fechaInicio: enUtc('2026-08-03T07:00'),
      fechaFin: enUtc('2026-08-03T23:00'),
      maxOcurrencias: 3,
    });

    expect(calcularProximasOcurrencias(rec, ZONA, 100)).toHaveLength(3);
  });

  it('descuenta las ocurrencias ya generadas y numera de forma continua', () => {
    const rec = recurrenciaBase({
      unidadIntervalo: 'MINUTOS',
      valorIntervalo: 1,
      fechaInicio: enUtc('2026-08-03T07:00'),
      fechaFin: enUtc('2026-08-03T23:00'),
      maxOcurrencias: 5,
      ocurrenciasGeneradas: 3,
    });

    const restantes = calcularProximasOcurrencias(rec, ZONA, 100);
    expect(restantes).toHaveLength(2);
    expect(restantes.map((o) => o.numero)).toEqual([4, 5]);
  });

  it('rechaza un máximo por encima del tope duro de 500', () => {
    expect(() => crearEstrategia(recurrenciaBase({ maxOcurrencias: 501 }), ZONA)).toThrow(
      ErrorRecurrencia,
    );
  });
});

describe('Validación del patrón al construirlo', () => {
  const casos: ReadonlyArray<[string, Partial<Recurrencia>, string]> = [
    ['sin fecha de fin', { fechaFin: '' }, 'FECHA_FIN_OBLIGATORIA'],
    ['fin anterior al inicio', { fechaFin: enUtc('2026-08-01T00:00') }, 'RANGO_INVALIDO'],
    ['intervalo cero', { valorIntervalo: 0 }, 'INTERVALO_INVALIDO'],
    ['intervalo fraccionario', { valorIntervalo: 1.5 }, 'INTERVALO_INVALIDO'],
    ['intervalo desmedido', { unidadIntervalo: 'MINUTOS', valorIntervalo: 5000 }, 'INTERVALO_FUERA_DE_RANGO'],
    ['día de la semana fuera de rango', { diasSemana: [0] }, 'DIA_SEMANA_INVALIDO'],
    ['franja invertida', { franjaHoraria: { desde: '19:00', hasta: '07:00' } }, 'FRANJA_INVALIDA'],
    [
      'hora del día fuera de la franja',
      { horaDelDia: '06:00', franjaHoraria: { desde: '07:00', hasta: '19:00' } },
      'HORA_FUERA_DE_FRANJA',
    ],
    ['máximo de ocurrencias en cero', { maxOcurrencias: 0 }, 'MAX_OCURRENCIAS_INVALIDO'],
  ];

  it.each(casos)('rechaza %s', (_descripcion, parcial, codigoEsperado) => {
    expect.assertions(2);
    try {
      crearEstrategia(recurrenciaBase(parcial), ZONA);
    } catch (e) {
      expect(e).toBeInstanceOf(ErrorRecurrencia);
      expect((e as ErrorRecurrencia).codigo).toBe(codigoEsperado);
    }
  });

  it('rechaza una zona horaria que no existe', () => {
    expect(() => crearEstrategia(recurrenciaBase(), 'Marte/Olympus')).toThrow(/ZONA_HORARIA_INVALIDA|zona horaria/i);
  });

  it('rechaza una fecha que no es ISO 8601', () => {
    expect(() => crearEstrategia(recurrenciaBase({ fechaInicio: '3 de agosto' }), ZONA)).toThrow(
      ErrorRecurrencia,
    );
  });
});

describe('Continuidad del cálculo', () => {
  it('reanuda desde la última ocurrencia enviada, como hace el despachador', () => {
    const rec = recurrenciaBase({
      unidadIntervalo: 'DIAS',
      valorIntervalo: 1,
      horaDelDia: '07:30',
      fechaInicio: enUtc('2026-08-03T00:00'),
      fechaFin: enUtc('2026-08-31T23:59'),
    });

    const ultima = DateTime.fromISO(enUtc('2026-08-05T07:30')).toJSDate();
    expect(local(calcularProximasOcurrencias(rec, ZONA, 2, ultima))).toEqual([
      '2026-08-06 07:30',
      '2026-08-07 07:30',
    ]);
  });

  it('rechaza una cantidad de vista previa inválida', () => {
    expect(() => calcularProximasOcurrencias(recurrenciaBase(), ZONA, 0)).toThrow(ErrorRecurrencia);
  });
});
