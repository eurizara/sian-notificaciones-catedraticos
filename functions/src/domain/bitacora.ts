/**
 * SIAN — Bitácora: catálogo de eventos y construcción de asientos.
 *
 * Traducción literal del catálogo del documento 05, sección 3. RNF-17 dice que
 * «todo cambio de estado deja asiento, sin excepción», y RF-BIT-03 que la
 * bitácora es inmutable: nadie la edita, ni siquiera el servidor.
 *
 * El actor se guarda **desnormalizado** —correo y rol junto al UID— porque la
 * bitácora debe poder leerse dentro de dos años sin depender de que ese
 * usuario siga existiendo (documento 05, sección 2.9).
 */

import { ErrorValidacion } from './errores';
import type { Rol } from './tipos';

export const TIPOS_EVENTO = [
  'SESION_INICIADA',
  'SESION_RECHAZADA',
  'SESION_CERRADA',
  'USUARIO_CREADO',
  'USUARIO_ROL_CAMBIADO',
  'USUARIO_DESACTIVADO',
  'USUARIO_REACTIVADO',
  'INVITACION_CREADA',
  'INVITACION_ELIMINADA',
  'GRUPO_CREADO',
  'GRUPO_MODIFICADO',
  'MENSAJE_CREADO',
  'MENSAJE_PROGRAMADO',
  'MENSAJE_SUSPENDIDO',
  'MENSAJE_REANUDADO',
  'MENSAJE_CANCELADO',
  'OCURRENCIA_DISPARADA',
  'OCURRENCIA_OMITIDA',
  'ENVIO_INICIADO',
  'ENVIO_COMPLETADO',
  'ENTREGA_FALLIDA',
  'MENSAJE_ABIERTO',
  'LECTURA_CONFIRMADA',
  'BITACORA_CONSULTADA',
  'CONFIGURACION_MODIFICADA',
] as const;
export type TipoEvento = (typeof TIPOS_EVENTO)[number];

export const ENTIDADES = [
  'MENSAJE',
  'USUARIO',
  'GRUPO',
  'ENTREGA',
  'SESION',
  'CONFIGURACION',
  'INVITACION',
] as const;
export type EntidadBitacora = (typeof ENTIDADES)[number];

export const ORIGENES = ['PANEL_WEB', 'APP_DOCENTE', 'PLANIFICADOR'] as const;
export type OrigenEvento = (typeof ORIGENES)[number];

/** UID reservado para cuando actúa el sistema y no una persona. */
export const ACTOR_SISTEMA = 'SISTEMA';

export interface Actor {
  readonly uid: string;
  readonly correo: string;
  readonly rol: Rol | typeof ACTOR_SISTEMA;
}

export interface AsientoBitacora {
  readonly tipo: TipoEvento;
  readonly actorUid: string;
  readonly actorCorreo: string;
  readonly actorRol: string;
  readonly entidad: EntidadBitacora;
  readonly entidadId: string;
  readonly resumen: string;
  readonly datos: Readonly<Record<string, unknown>>;
  readonly ocurridoEn: Date;
  readonly origen: OrigenEvento;
}

export interface EntradaAsiento {
  readonly tipo: TipoEvento;
  readonly actor: Actor;
  readonly entidad: EntidadBitacora;
  readonly entidadId: string;
  readonly resumen: string;
  readonly datos?: Readonly<Record<string, unknown>>;
  readonly origen?: OrigenEvento;
  readonly ocurridoEn?: Date;
}

/**
 * Construye un asiento válido, o lanza.
 *
 * Un asiento sin resumen legible es un asiento inútil: dentro de dos años,
 * quien audite no va a reconstruir qué pasó a partir de un identificador.
 */
export function crearAsiento(entrada: EntradaAsiento): AsientoBitacora {
  if (!TIPOS_EVENTO.includes(entrada.tipo)) {
    throw new ErrorValidacion(
      'TIPO_EVENTO_INVALIDO',
      `Tipo de evento fuera del catálogo del documento 05: «${String(entrada.tipo)}».`,
    );
  }
  if (!ENTIDADES.includes(entrada.entidad)) {
    throw new ErrorValidacion(
      'ENTIDAD_INVALIDA',
      `Entidad fuera del catálogo: «${String(entrada.entidad)}».`,
    );
  }
  if (!entrada.entidadId) {
    throw new ErrorValidacion(
      'ENTIDAD_ID_OBLIGATORIO',
      'Todo asiento debe señalar sobre qué entidad ocurrió (RF-BIT-02).',
    );
  }
  if (!entrada.resumen.trim()) {
    throw new ErrorValidacion(
      'RESUMEN_OBLIGATORIO',
      'Todo asiento debe traer un resumen legible por una persona (RF-BIT-02).',
    );
  }

  return Object.freeze({
    tipo: entrada.tipo,
    actorUid: entrada.actor.uid,
    actorCorreo: entrada.actor.correo,
    actorRol: entrada.actor.rol,
    entidad: entrada.entidad,
    entidadId: entrada.entidadId,
    resumen: entrada.resumen.trim(),
    datos: Object.freeze({ ...(entrada.datos ?? {}) }),
    ocurridoEn: entrada.ocurridoEn ?? new Date(),
    origen: entrada.origen ?? 'PANEL_WEB',
  });
}

/** Actor que representa al propio sistema, no a una persona. */
export const actorSistema: Actor = Object.freeze({
  uid: ACTOR_SISTEMA,
  correo: ACTOR_SISTEMA,
  rol: ACTOR_SISTEMA,
});
