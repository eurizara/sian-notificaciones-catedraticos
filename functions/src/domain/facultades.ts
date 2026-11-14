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
 * `personas`: cuántas de esa sede la tienen asignada, y `grupos`, cuántos
 * grupos de la sede son de esa facultad (2.0.7). Solo importan al retirarla.
 */
export function decidirOferta(entrada: {
  readonly ofrecer: boolean;
  readonly catalogo: FacultadDelCatalogo | undefined;
  readonly actual: OfertaActual | undefined;
  readonly personas: number;
  readonly grupos?: number;
}): CambioDeOferta | null {
  const { ofrecer, catalogo, actual, personas } = entrada;
  const grupos = entrada.grupos ?? 0;
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
  if (personas > 0 || grupos > 0) {
    const partes: string[] = [];
    const pasos: string[] = [];
    if (personas > 0) {
      partes.push(personas === 1 ? 'la tiene 1 persona' : `la tienen ${personas} personas`);
      pasos.push('quítesela en Usuarios');
    }
    if (grupos > 0) {
      partes.push(grupos === 1 ? 'la usa 1 grupo' : `la usan ${grupos} grupos`);
      pasos.push('cambie la facultad de esos grupos');
    }
    const frase = partes.join(' y ');
    throw new ErrorValidacion(
      'FACULTAD_EN_USO',
      `${frase.charAt(0).toUpperCase()}${frase.slice(1)} en esta sede. Primero ${pasos.join(' y ')}; ` +
        'después retírela de la sede.',
      { personas: String(personas), grupos: String(grupos) },
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
