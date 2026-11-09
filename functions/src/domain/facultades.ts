/**
 * SIAN — Catálogo único de facultades y lo que ofrece cada sede (2.0.6).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Tres niveles: catálogo → sede → persona.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   1. `facultades/{id}`: la lista única de la UMG. Solo la mantiene el
 *      superadministrador, para que «Ingeniería en Sistemas» exista una vez y
 *      sea la misma en todas las sedes (reportes por facultad, RF-FAC-05).
 *   2. `sedes/{sede}/facultades/{id}`: las que esa sede ofrece, elegidas del
 *      catálogo (no se escriben de nuevo). Las eligen el superadministrador y
 *      la coordinación de la sede. Se guarda una copia del nombre para que lo
 *      que ya leía esa lista —envío por facultad, invitaciones— siga igual.
 *   3. `membresias[sede].facultades` de cada persona: solo entre las que su
 *      sede ofrece (`conFacultadesEnSede`).
 *
 * Nada queda colgando: no se deja de ofrecer una facultad que alguien de la
 * sede tiene asignada, ni se desactiva en el catálogo una que alguna sede
 * ofrece (decisión del responsable, 08/11/2026).
 *
 * Funciones puras (RNF-19).
 */

import { ErrorValidacion } from './errores';

export interface FacultadDelCatalogo {
  readonly nombre: string;
  readonly activa: boolean;
}

/** Lo que una sede tiene hoy de esa facultad: nada, ofrecida o retirada. */
export interface OfertaActual {
  readonly activa: boolean;
}

export type CambioDeOferta = 'alta' | 'reactivada' | 'retirada';

/**
 * Qué hacer al pedir que una sede ofrezca —o deje de ofrecer— una facultad.
 * `null` si ya está como se pide. Lanza con un mensaje que dice qué hacer.
 *
 * `personas`: cuántas de esa sede la tienen asignada (solo importa al
 * retirarla).
 */
export function decidirOferta(entrada: {
  readonly ofrecer: boolean;
  readonly catalogo: FacultadDelCatalogo | undefined;
  readonly actual: OfertaActual | undefined;
  readonly personas: number;
}): CambioDeOferta | null {
  const { ofrecer, catalogo, actual, personas } = entrada;
  if (ofrecer) {
    if (catalogo === undefined) {
      throw new ErrorValidacion('FACULTAD_INEXISTENTE', 'Esa facultad no está en el catálogo.');
    }
    if (!catalogo.activa) {
      throw new ErrorValidacion(
        'FACULTAD_INACTIVA',
        `«${catalogo.nombre}» está desactivada en el catálogo: un superadministrador tiene que reactivarla.`,
      );
    }
    if (actual?.activa === true) {
      return null;
    }
    return actual === undefined ? 'alta' : 'reactivada';
  }
  if (actual === undefined || !actual.activa) {
    return null;
  }
  if (personas > 0) {
    const quien = personas === 1 ? 'La tiene 1 persona' : `La tienen ${personas} personas`;
    throw new ErrorValidacion(
      'FACULTAD_EN_USO',
      `${quien} en esta sede. Quítesela primero en Usuarios y después retírela de la sede.`,
      { personas: String(personas) },
    );
  }
  return 'retirada';
}

/**
 * Desactivar una facultad del catálogo: solo si ninguna sede la ofrece. Lanza
 * diciendo cuáles la ofrecen, para que se sepa por dónde empezar.
 */
export function exigirQueNingunaSedeLaOfrezca(nombre: string, sedesQueLaOfrecen: readonly string[]): void {
  if (sedesQueLaOfrecen.length > 0) {
    throw new ErrorValidacion(
      'FACULTAD_OFRECIDA',
      `«${nombre}» la ofrece${sedesQueLaOfrecen.length === 1 ? '' : 'n'}: ${sedesQueLaOfrecen.join(', ')}. ` +
        'Retírela primero de esas sedes, en Catálogos.',
    );
  }
}
