/**
 * SIAN — Máquinas de estado (patrón State, documento 02, sección 4).
 *
 * Los diagramas de las secciones 9 y 10 del documento 01 están aquí como
 * tablas de transición, no como comentarios. Una transición que no aparece en
 * la tabla es imposible de ejecutar, no «desaconsejada».
 *
 * De aquí salen dos garantías que el documento exige explícitamente:
 *   · RF-CNF-04 — CONFIRMADO no tiene transiciones de salida: es irreversible.
 *   · RF-CNF-02 — no existe la arista ENTREGADO → CONFIRMADO: abrir un mensaje
 *     nunca lo confirma; hay que pasar por ABIERTO con un acto deliberado.
 */

import { ErrorTransicionInvalida } from '../errores';
import type { EstadoEntrega, EstadoItemCola, EstadoMensaje, EstadoOcurrencia } from '../tipos';

export type TablaTransiciones<E extends string> = Readonly<Record<E, readonly E[]>>;

/** Máquina de estados genérica, construida sobre una tabla de transiciones. */
export class MaquinaEstados<E extends string> {
  constructor(
    readonly nombre: string,
    private readonly tabla: TablaTransiciones<E>,
  ) {}

  /** Estados a los que se puede ir desde `desde`. */
  transicionesDesde(desde: E): readonly E[] {
    return this.tabla[desde] ?? [];
  }

  puedeTransicionar(desde: E, hacia: E): boolean {
    return this.transicionesDesde(desde).includes(hacia);
  }

  /** Devuelve `hacia` si la transición es legal; lanza si no lo es. */
  transicionar(desde: E, hacia: E): E {
    if (!this.puedeTransicionar(desde, hacia)) {
      throw new ErrorTransicionInvalida(this.nombre, desde, hacia);
    }
    return hacia;
  }

  /** Un estado es final cuando no tiene ninguna transición de salida. */
  esFinal(estado: E): boolean {
    return this.transicionesDesde(estado).length === 0;
  }

  get estados(): readonly E[] {
    return Object.keys(this.tabla) as E[];
  }
}

// ---------------------------------------------------------------------------
// Mensaje — documento 01, sección 9
// ---------------------------------------------------------------------------

const TRANSICIONES_MENSAJE: TablaTransiciones<EstadoMensaje> = {
  BORRADOR: ['PROGRAMADO', 'EN_COLA', 'CANCELADO'],
  PROGRAMADO: ['EN_COLA', 'SUSPENDIDO', 'CANCELADO'],
  SUSPENDIDO: ['PROGRAMADO', 'CANCELADO'],
  EN_COLA: ['EN_ENVIO'],
  EN_ENVIO: ['ENVIADO', 'ENVIADO_CON_FALLOS', 'FALLIDO'],
  ENVIADO: ['RECURRENTE_PENDIENTE'],
  ENVIADO_CON_FALLOS: ['RECURRENTE_PENDIENTE'],
  RECURRENTE_PENDIENTE: ['EN_COLA', 'AGOTADO'],
  // Estados terminales (RN-03: un mensaje enviado no se edita ni se borra).
  FALLIDO: [],
  CANCELADO: [],
  AGOTADO: [],
};

export const maquinaMensaje = new MaquinaEstados<EstadoMensaje>('MENSAJE', TRANSICIONES_MENSAJE);

// ---------------------------------------------------------------------------
// Entrega individual — documento 01, sección 10
// ---------------------------------------------------------------------------

const TRANSICIONES_ENTREGA: TablaTransiciones<EstadoEntrega> = {
  PENDIENTE: ['ENVIADO_A_FCM'],
  ENVIADO_A_FCM: ['ENTREGADO', 'FALLIDO'],
  // El reintento con espera creciente devuelve la entrega a la cola de FCM
  // hasta agotar los 3 intentos (RF-ENT-10).
  FALLIDO: ['ENVIADO_A_FCM', 'DESCARTADO'],
  ENTREGADO: ['ABIERTO'],
  ABIERTO: ['CONFIRMADO'],
  // Terminales.
  CONFIRMADO: [], // RF-CNF-04: irreversible
  DESCARTADO: [],
};

export const maquinaEntrega = new MaquinaEstados<EstadoEntrega>('ENTREGA', TRANSICIONES_ENTREGA);

// ---------------------------------------------------------------------------
// Ocurrencia — documento 05, sección 2.6
// ---------------------------------------------------------------------------

const TRANSICIONES_OCURRENCIA: TablaTransiciones<EstadoOcurrencia> = {
  PENDIENTE: ['EN_ENVIO', 'OMITIDA', 'CANCELADA'],
  EN_ENVIO: ['COMPLETADA', 'COMPLETADA_CON_FALLOS'],
  COMPLETADA: [],
  COMPLETADA_CON_FALLOS: [],
  OMITIDA: [],
  CANCELADA: [],
};

export const maquinaOcurrencia = new MaquinaEstados<EstadoOcurrencia>(
  'OCURRENCIA',
  TRANSICIONES_OCURRENCIA,
);

// ---------------------------------------------------------------------------
// Ítem de la cola de despacho — documento 05, sección 2.8
//
// TOMADO → PENDIENTE existe a propósito: es la liberación del bloqueo vencido
// a los 5 minutos, que evita que una ejecución muerta deje la ocurrencia
// bloqueada para siempre (documento 02, sección 5.3).
// ---------------------------------------------------------------------------

const TRANSICIONES_ITEM_COLA: TablaTransiciones<EstadoItemCola> = {
  PENDIENTE: ['TOMADO'],
  TOMADO: ['COMPLETADO', 'FALLIDO', 'PENDIENTE'],
  FALLIDO: ['PENDIENTE'],
  COMPLETADO: [],
};

export const maquinaItemCola = new MaquinaEstados<EstadoItemCola>(
  'ITEM_COLA',
  TRANSICIONES_ITEM_COLA,
);
