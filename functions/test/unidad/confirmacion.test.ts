/**
 * Confirmación de lectura — RF-CNF-02, 04, 05, 07.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Esto es la evidencia. Confirmar no se deshace ni se repite.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Cuando alguien pregunte «¿quién sabía del simulacro?», la respuesta sale de
 * aquí. Una confirmación que se pudiera editar no probaría nada.
 */

import {
  estadoTrasAbrir,
  exigirConfirmable,
  porcentajeConfirmacion,
} from '../../src/application/confirmacion';
import { esperarCodigo } from './ayudas';

describe('RF-CNF-04 y 05 · irreversible y sin duplicados', () => {
  it('una entrega entregada se puede confirmar', () => {
    expect(() => exigirConfirmable('ENTREGADO')).not.toThrow();
  });

  it('una abierta también', () => {
    expect(() => exigirConfirmable('ABIERTO')).not.toThrow();
  });

  it('una ya confirmada NO se vuelve a confirmar', () => {
    // No es un fallo del sistema: es que ya estaba hecho. Se distingue con su
    // propio código porque se responde distinto a quien pregunte.
    esperarCodigo(() => exigirConfirmable('CONFIRMADO'), 'YA_CONFIRMADO');
  });

  it('una que aún no se entregó, tampoco', () => {
    esperarCodigo(() => exigirConfirmable('PENDIENTE'), 'ENTREGA_NO_COMPLETADA');
    esperarCodigo(() => exigirConfirmable('ENVIADO_A_FCM'), 'ENTREGA_NO_COMPLETADA');
  });

  it('una fallida se distingue de una no entregada', () => {
    // Una fallida SÍ es algo que revisar; una pendiente solo hay que esperarla.
    esperarCodigo(() => exigirConfirmable('FALLIDO'), 'ENTREGA_FALLIDA');
    esperarCodigo(() => exigirConfirmable('DESCARTADO'), 'ENTREGA_FALLIDA');
  });
});

describe('RF-CNF-02 · abrir NO es confirmar', () => {
  it('una entregada pasa a abierta', () => {
    expect(estadoTrasAbrir('ENTREGADO')).toBe('ABIERTO');
  });

  it('una ya confirmada NO retrocede a abierta', () => {
    // Sería perder la evidencia por el simple hecho de volver a mirar.
    expect(estadoTrasAbrir('CONFIRMADO')).toBe('CONFIRMADO');
  });

  it('una que no llegó no se marca abierta porque la pantalla la pintara', () => {
    expect(estadoTrasAbrir('PENDIENTE')).toBe('PENDIENTE');
    expect(estadoTrasAbrir('FALLIDO')).toBe('FALLIDO');
  });

  it('abrir dos veces no cambia nada', () => {
    expect(estadoTrasAbrir(estadoTrasAbrir('ENTREGADO'))).toBe('ABIERTO');
  });
});

describe('RF-CNF-07 · el porcentaje dice la verdad', () => {
  const base = { total: 0, entregados: 0, abiertos: 0, confirmados: 0, fallidos: 0 };

  it('se calcula sobre el TOTAL, no sobre los entregados', () => {
    // Es lo único honesto: a quien no le llegó el aviso tampoco lo confirmó.
    // Con denominador «entregados» esto daría 100 % teniendo 5 personas sin
    // enterarse, que es exactamente el dato que un simulacro necesita ver.
    const r = { ...base, total: 10, entregados: 5, confirmados: 5, fallidos: 5 };
    expect(porcentajeConfirmacion(r)).toBe(50);
  });

  it('sin destinatarios es 0 y no revienta', () => {
    expect(porcentajeConfirmacion(base)).toBe(0);
  });

  it('todos confirmados es 100', () => {
    expect(
      porcentajeConfirmacion({ ...base, total: 8, entregados: 8, confirmados: 8 }),
    ).toBe(100);
  });

  it('redondea al entero más cercano', () => {
    expect(
      porcentajeConfirmacion({ ...base, total: 3, entregados: 3, confirmados: 1 }),
    ).toBe(33);
  });
});
