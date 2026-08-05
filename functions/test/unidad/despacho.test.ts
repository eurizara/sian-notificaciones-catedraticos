/**
 * Reglas del despacho — RF-PRG-04, RF-PRG-12, RF-ENT-10.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Un aviso que sale dos veces destruye más confianza que uno que no sale.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * El despachador corre cada minuto y puede solaparse consigo mismo. Estas
 * pruebas provocan ese solapamiento con relojes falsos, que es como se
 * descubren los fallos de idempotencia — nunca ejecutando el planificador de
 * verdad y esperando a ver qué pasa.
 */

import {
  BLOQUEO_MINUTOS,
  MARGEN_PASADO_SEGUNDOS,
  MAX_INTENTOS,
  bloqueoHasta,
  decidirSobreItem,
  ordenarLote,
  validarFechaFutura,
  type ItemCola,
} from '../../src/application/despacho';
import { esperarCodigo } from './ayudas';

const AHORA = new Date('2026-08-05T14:00:00Z');

function item(parcial: Partial<ItemCola> = {}): ItemCola {
  return {
    id: 'm1_1',
    estado: 'PENDIENTE',
    ejecutarEn: new Date('2026-08-05T13:59:00Z'),
    intentos: 0,
    bloqueoHasta: null,
    prioridad: 0,
    ...parcial,
  };
}

describe('RF-PRG-12 · dos ejecuciones no despachan lo mismo', () => {
  it('un ítem pendiente se toma', () => {
    expect(decidirSobreItem(item(), AHORA)).toBe('TOMAR');
  });

  it('uno TOMADO con bloqueo vigente NO se vuelve a tomar', () => {
    // Es el caso central: la segunda ejecución del despachador lo ve ocupado
    // y lo deja pasar. Sin esto, el simulacro se anuncia dos veces.
    const ocupado = item({
      estado: 'TOMADO',
      bloqueoHasta: new Date('2026-08-05T14:03:00Z'),
    });
    expect(decidirSobreItem(ocupado, AHORA)).toBe('YA_TOMADO');
  });

  it('uno TOMADO con bloqueo VENCIDO se recupera', () => {
    // La ejecución que lo tomó murió a mitad. Sin recuperarlo, el aviso
    // quedaría encallado para siempre y nadie se enteraría.
    const abandonado = item({
      estado: 'TOMADO',
      bloqueoHasta: new Date('2026-08-05T13:50:00Z'),
    });
    expect(decidirSobreItem(abandonado, AHORA)).toBe('TOMAR');
  });

  it('uno ya completado no se repite', () => {
    expect(decidirSobreItem(item({ estado: 'COMPLETADO' }), AHORA)).toBe(
      'TERMINADO',
    );
  });

  it('el bloqueo dura cinco minutos', () => {
    const hasta = bloqueoHasta(AHORA);
    expect(hasta.getTime() - AHORA.getTime()).toBe(BLOQUEO_MINUTOS * 60_000);
  });
});

describe('RF-ENT-10 · los reintentos se agotan', () => {
  it('tras tres intentos se deja de insistir', () => {
    // Insistir para siempre con un token muerto gastaría cuota sin que llegue
    // nada, y escondería el problema real detrás de reintentos infinitos.
    expect(decidirSobreItem(item({ intentos: MAX_INTENTOS }), AHORA)).toBe(
      'AGOTADO',
    );
  });

  it('con dos todavía se intenta', () => {
    expect(decidirSobreItem(item({ intentos: 2 }), AHORA)).toBe('TOMAR');
  });
});

describe('orden del lote', () => {
  it('las urgentes salen primero', () => {
    // Con doscientos avisos encolados y un minuto de ventana, una alerta de
    // evacuación no puede quedar detrás de treinta recordatorios de reunión.
    const lote = ordenarLote([
      item({ id: 'info', prioridad: 0 }),
      item({ id: 'urgente', prioridad: 100 }),
    ]);
    expect(lote.map((i) => i.id)).toEqual(['urgente', 'info']);
  });

  it('a igual prioridad, primero la más atrasada', () => {
    const lote = ordenarLote([
      item({ id: 'nueva', ejecutarEn: new Date('2026-08-05T13:59:00Z') }),
      item({ id: 'vieja', ejecutarEn: new Date('2026-08-05T13:30:00Z') }),
    ]);
    expect(lote.map((i) => i.id)).toEqual(['vieja', 'nueva']);
  });

  it('no muta el arreglo recibido', () => {
    const original = [item({ id: 'a' }), item({ id: 'b', prioridad: 100 })];
    ordenarLote(original);
    expect(original[0]!.id).toBe('a');
  });
});

describe('RF-PRG-04 · no se programa hacia el pasado', () => {
  it('una fecha futura se admite', () => {
    expect(() =>
      validarFechaFutura(new Date('2026-08-05T15:00:00Z'), AHORA),
    ).not.toThrow();
  });

  it('una fecha claramente pasada se rechaza', () => {
    esperarCodigo(
      () => validarFechaFutura(new Date('2026-08-04T10:00:00Z'), AHORA),
      'FECHA_EN_EL_PASADO',
    );
  });

  it('se tolera un minuto de margen', () => {
    // Entre pulsar «programar» y que llegue la petición pasan segundos.
    // Rechazar por eso una programación para «dentro de un minuto» sería
    // incomprensible desde fuera.
    const hace30s = new Date(AHORA.getTime() - 30_000);
    expect(() => validarFechaFutura(hace30s, AHORA)).not.toThrow();

    const hace2min = new Date(AHORA.getTime() - 120_000);
    esperarCodigo(() => validarFechaFutura(hace2min, AHORA), 'FECHA_EN_EL_PASADO');
  });

  it('el margen es de un minuto exacto', () => {
    expect(MARGEN_PASADO_SEGUNDOS).toBe(60);
  });

  it('una fecha inválida se rechaza con su propio motivo', () => {
    esperarCodigo(() => validarFechaFutura(new Date('vaya'), AHORA), 'FECHA_INVALIDA');
  });
});
