/**
 * Pruebas de las máquinas de estado — documento 01, secciones 9 y 10.
 *
 * Estas pruebas existen sobre todo para blindar dos requisitos que son fáciles
 * de romper sin darse cuenta al añadir funcionalidad más adelante:
 * RF-CNF-02 (abrir no es confirmar) y RF-CNF-04 (confirmar es irreversible).
 */

import { ErrorTransicionInvalida } from '../../src/domain/errores';
import {
  maquinaEntrega,
  maquinaItemCola,
  maquinaMensaje,
  maquinaOcurrencia,
} from '../../src/domain/estados/maquinaEstados';

describe('Máquina de estados del mensaje', () => {
  it('permite el camino feliz de un envío inmediato', () => {
    let estado = maquinaMensaje.transicionar('BORRADOR', 'EN_COLA');
    estado = maquinaMensaje.transicionar(estado, 'EN_ENVIO');
    estado = maquinaMensaje.transicionar(estado, 'ENVIADO');
    expect(estado).toBe('ENVIADO');
  });

  it('permite programar, suspender, reanudar y cancelar (RF-PRG-10, RF-PRG-11)', () => {
    let estado = maquinaMensaje.transicionar('BORRADOR', 'PROGRAMADO');
    estado = maquinaMensaje.transicionar(estado, 'SUSPENDIDO');
    estado = maquinaMensaje.transicionar(estado, 'PROGRAMADO');
    estado = maquinaMensaje.transicionar(estado, 'CANCELADO');
    expect(maquinaMensaje.esFinal(estado)).toBe(true);
  });

  it('encadena las ocurrencias de un mensaje recurrente (RN-07)', () => {
    let estado = maquinaMensaje.transicionar('EN_ENVIO', 'ENVIADO');
    estado = maquinaMensaje.transicionar(estado, 'RECURRENTE_PENDIENTE');
    estado = maquinaMensaje.transicionar(estado, 'EN_COLA');
    expect(estado).toBe('EN_COLA');
    expect(maquinaMensaje.transicionar('RECURRENTE_PENDIENTE', 'AGOTADO')).toBe('AGOTADO');
  });

  it('RN-03 · un mensaje enviado no vuelve a borrador ni se cancela', () => {
    expect(() => maquinaMensaje.transicionar('ENVIADO', 'BORRADOR')).toThrow(ErrorTransicionInvalida);
    expect(() => maquinaMensaje.transicionar('ENVIADO', 'CANCELADO')).toThrow(ErrorTransicionInvalida);
  });

  it('trata FALLIDO, CANCELADO y AGOTADO como estados finales', () => {
    for (const final of ['FALLIDO', 'CANCELADO', 'AGOTADO'] as const) {
      expect(maquinaMensaje.esFinal(final)).toBe(true);
    }
  });

  it('el error de transición nombra la máquina, el origen y el destino', () => {
    try {
      maquinaMensaje.transicionar('CANCELADO', 'EN_COLA');
      throw new Error('debió lanzar');
    } catch (e) {
      expect(e).toBeInstanceOf(ErrorTransicionInvalida);
      const err = e as ErrorTransicionInvalida;
      expect(err.codigo).toBe('TRANSICION_INVALIDA');
      expect(err.maquina).toBe('MENSAJE');
      expect(err.desde).toBe('CANCELADO');
      expect(err.hacia).toBe('EN_COLA');
    }
  });
});

describe('Máquina de estados de la entrega', () => {
  it('recorre pendiente → entregado → abierto → confirmado', () => {
    let estado = maquinaEntrega.transicionar('PENDIENTE', 'ENVIADO_A_FCM');
    estado = maquinaEntrega.transicionar(estado, 'ENTREGADO');
    estado = maquinaEntrega.transicionar(estado, 'ABIERTO');
    estado = maquinaEntrega.transicionar(estado, 'CONFIRMADO');
    expect(estado).toBe('CONFIRMADO');
  });

  it('RF-CNF-02 · abrir el mensaje nunca lo marca como confirmado', () => {
    // No existe la arista ENTREGADO → CONFIRMADO: hay que pasar por ABIERTO,
    // y de ABIERTO a CONFIRMADO solo por un acto deliberado del catedrático.
    expect(maquinaEntrega.puedeTransicionar('ENTREGADO', 'CONFIRMADO')).toBe(false);
    expect(() => maquinaEntrega.transicionar('ENTREGADO', 'CONFIRMADO')).toThrow(
      ErrorTransicionInvalida,
    );
  });

  it('RF-CNF-04 y RF-CNF-05 · la confirmación es irreversible y no se repite', () => {
    expect(maquinaEntrega.esFinal('CONFIRMADO')).toBe(true);
    expect(maquinaEntrega.transicionesDesde('CONFIRMADO')).toEqual([]);
    for (const destino of ['ABIERTO', 'ENTREGADO', 'PENDIENTE', 'CONFIRMADO'] as const) {
      expect(maquinaEntrega.puedeTransicionar('CONFIRMADO', destino)).toBe(false);
    }
  });

  it('RF-ENT-10 · un fallo puede reintentarse o descartarse', () => {
    expect(maquinaEntrega.puedeTransicionar('FALLIDO', 'ENVIADO_A_FCM')).toBe(true);
    expect(maquinaEntrega.puedeTransicionar('FALLIDO', 'DESCARTADO')).toBe(true);
    expect(maquinaEntrega.esFinal('DESCARTADO')).toBe(true);
  });
});

describe('Máquinas de ocurrencia y de cola de despacho', () => {
  it('una ocurrencia vencida puede omitirse sin haberse enviado (RF-PRG-13)', () => {
    expect(maquinaOcurrencia.transicionar('PENDIENTE', 'OMITIDA')).toBe('OMITIDA');
    expect(maquinaOcurrencia.esFinal('OMITIDA')).toBe(true);
  });

  it('el bloqueo vencido devuelve el ítem tomado a la cola (documento 02, 4.3)', () => {
    expect(maquinaItemCola.transicionar('TOMADO', 'PENDIENTE')).toBe('PENDIENTE');
    expect(maquinaItemCola.transicionar('FALLIDO', 'PENDIENTE')).toBe('PENDIENTE');
  });

  it('un ítem completado no vuelve a tomarse: es la barrera contra el envío doble', () => {
    expect(maquinaItemCola.esFinal('COMPLETADO')).toBe(true);
    expect(maquinaItemCola.puedeTransicionar('COMPLETADO', 'TOMADO')).toBe(false);
  });

  it('declara todos los estados del documento 05', () => {
    expect(maquinaOcurrencia.estados).toHaveLength(6);
    expect(maquinaItemCola.estados).toHaveLength(4);
  });
});
