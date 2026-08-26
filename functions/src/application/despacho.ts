/**
 * SIAN — Reglas del despacho, sin Firestore de por medio.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Lo que decide si un aviso sale dos veces, o si sale tarde, vive aquí.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * El despachador corre cada minuto y puede solaparse consigo mismo: Cloud
 * Scheduler no garantiza una sola ejecución, y una Function puede reintentarse.
 * Que un simulacro se anuncie dos veces destruye la confianza en el sistema más
 * que no anunciarlo (RF-PRG-12).
 *
 * Separar estas decisiones de la lectura de Firestore permite probarlas con
 * relojes falsos y solapamientos provocados, que es como se descubren los
 * fallos de idempotencia — nunca ejecutando el planificador de verdad.
 */

import { ErrorValidacion } from '../domain/errores';
import type { EstadoItemCola } from '../domain/tipos';

/** Cuánto vale un bloqueo antes de considerarse muerto. */
export const BLOQUEO_MINUTOS = 5;

export interface ItemCola {
  readonly id: string;
  readonly estado: EstadoItemCola;
  readonly ejecutarEn: Date;
  readonly intentos: number;
  readonly bloqueoHasta?: Date | null;
  readonly prioridad: number;
}

export type DecisionItem = 'TOMAR' | 'YA_TOMADO' | 'TERMINADO' | 'AGOTADO';

/** Cuántos intentos antes de rendirse con un ítem (RF-ENT-10). */
export const MAX_INTENTOS = 3;

/**
 * ¿Puede esta ejecución tomar el ítem?
 *
 * Un ítem `TOMADO` con bloqueo vigente pertenece a otra ejecución y no se
 * toca. Si el bloqueo venció, la ejecución anterior murió a mitad y se
 * recupera: sin esa recuperación, un fallo puntual dejaría el aviso encallado
 * para siempre y nadie se enteraría.
 */
export function decidirSobreItem(item: ItemCola, ahora: Date = new Date()): DecisionItem {
  if (item.estado === 'COMPLETADO') {
    return 'TERMINADO';
  }
  if (item.intentos >= MAX_INTENTOS) {
    return 'AGOTADO';
  }
  if (item.estado === 'TOMADO') {
    const vence = item.bloqueoHasta;
    if (vence != null && vence.getTime() > ahora.getTime()) {
      return 'YA_TOMADO';
    }
    // Bloqueo vencido: la ejecución que lo tomó no terminó.
    return 'TOMAR';
  }
  return 'TOMAR';
}

/** Instante hasta el que queda bloqueado un ítem recién tomado. */
export function bloqueoHasta(ahora: Date = new Date()): Date {
  return new Date(ahora.getTime() + BLOQUEO_MINUTOS * 60_000);
}

/**
 * Ordena el lote: las urgentes primero, y dentro de cada prioridad las más
 * atrasadas antes.
 *
 * Con doscientos avisos encolados y un minuto de ventana, el orden decide cuál
 * sale ya y cuál espera al siguiente ciclo. Una alerta de evacuación no puede
 * quedar detrás de treinta recordatorios de reunión.
 */
export function ordenarLote(items: readonly ItemCola[]): ItemCola[] {
  return [...items].sort((a, b) => {
    if (a.prioridad !== b.prioridad) {
      return b.prioridad - a.prioridad;
    }
    return a.ejecutarEn.getTime() - b.ejecutarEn.getTime();
  });
}

/**
 * Valida una fecha de programación única (RF-PRG-04).
 *
 * Se admite un pequeño margen hacia atrás: entre que alguien pulsa «programar»
 * y llega la petición pasan segundos, y rechazar por eso una programación para
 * «dentro de un minuto» sería incomprensible desde fuera.
 */
export const MARGEN_PASADO_SEGUNDOS = 60;

export function validarFechaFutura(ejecutarEn: Date, ahora: Date = new Date()): void {
  if (Number.isNaN(ejecutarEn.getTime())) {
    throw new ErrorValidacion('FECHA_INVALIDA', 'La fecha de envío no es válida.');
  }

  const atrasoSegundos = (ahora.getTime() - ejecutarEn.getTime()) / 1000;
  if (atrasoSegundos > MARGEN_PASADO_SEGUNDOS) {
    throw new ErrorValidacion(
      'FECHA_EN_EL_PASADO',
      'Esa fecha y hora ya pasaron. Elige un momento futuro.',
      { ejecutarEn: ejecutarEn.toISOString(), ahora: ahora.toISOString() },
    );
  }
}
