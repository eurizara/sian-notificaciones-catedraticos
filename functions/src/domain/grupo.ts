/**
 * SIAN — Grupos de destinatarios (RF-USR-03, RF-USR-04, RF-USR-05).
 *
 * El límite de 200 miembros no es arbitrario: los miembros viven como arreglo
 * dentro del documento del grupo, y un documento de Firestore no puede pasar
 * de 1 MiB. Además, un arreglo grande genera contención cuando dos personas lo
 * modifican a la vez. Está registrado como deuda **DT-08**, con su umbral de
 * pago —150 miembros— y su plan: migrar a subcolección.
 */

import { ErrorValidacion } from './errores';
import { LIMITES } from './tipos';

export interface Grupo {
  readonly nombre: string;
  readonly descripcion: string;
  readonly miembros: readonly string[];
  readonly totalMiembros: number;
  readonly creadoPor: string;
  readonly creadoEn: Date;
  readonly activo: boolean;
}

export interface EntradaGrupo {
  readonly nombre: string;
  readonly descripcion?: string;
  readonly miembros?: readonly string[];
  readonly creadoPor: string;
  readonly creadoEn?: Date;
}

export const LONGITUD_MAX_NOMBRE_GRUPO = 60;

/**
 * Umbral a partir del cual conviene empezar a pagar DT-08.
 *
 * No bloquea nada: avisa. Llegar a 200 y descubrir el límite el día que hace
 * falta agregar a alguien es peor que saberlo con 50 de margen.
 */
export const UMBRAL_AVISO_MIEMBROS = 150;

export function crearGrupo(entrada: EntradaGrupo): Grupo {
  const nombre = (entrada.nombre ?? '').trim();
  if (nombre.length === 0) {
    throw new ErrorValidacion('NOMBRE_GRUPO_VACIO', 'El grupo necesita un nombre.');
  }
  if ([...nombre].length > LONGITUD_MAX_NOMBRE_GRUPO) {
    throw new ErrorValidacion(
      'NOMBRE_GRUPO_MUY_LARGO',
      `El nombre del grupo no puede exceder ${LONGITUD_MAX_NOMBRE_GRUPO} caracteres.`,
    );
  }
  if (!entrada.creadoPor) {
    throw new ErrorValidacion(
      'CREADOR_OBLIGATORIO',
      'Todo grupo debe registrar quién lo creó (RF-BIT-02).',
    );
  }

  const miembros = normalizarMiembros(entrada.miembros ?? []);

  return Object.freeze({
    nombre,
    descripcion: (entrada.descripcion ?? '').trim(),
    miembros: Object.freeze(miembros),
    totalMiembros: miembros.length,
    creadoPor: entrada.creadoPor,
    creadoEn: entrada.creadoEn ?? new Date(),
    activo: true,
  });
}

/**
 * Quita repetidos y comprueba el límite de DT-08.
 *
 * Un UID repetido no se rechaza: se colapsa. Que alguien aparezca dos veces en
 * una selección es un descuido de la interfaz, no una intención, y duplicarlo
 * generaría dos entregas al mismo destinatario.
 */
export function normalizarMiembros(miembros: readonly string[]): string[] {
  const limpios = [...new Set(miembros.map((m) => (m ?? '').trim()).filter((m) => m.length > 0))];

  if (limpios.length > LIMITES.MAX_MIEMBROS_POR_GRUPO) {
    throw new ErrorValidacion(
      'GRUPO_DEMASIADO_GRANDE',
      `Un grupo admite hasta ${LIMITES.MAX_MIEMBROS_POR_GRUPO} miembros (DT-08); llegaron ${limpios.length}.`,
      { miembros: limpios.length, maximo: LIMITES.MAX_MIEMBROS_POR_GRUPO },
    );
  }

  return limpios;
}

/** ¿Conviene ya empezar a pagar DT-08? */
export function rozaElLimite(totalMiembros: number): boolean {
  return totalMiembros >= UMBRAL_AVISO_MIEMBROS;
}

export function agregarMiembros(grupo: Grupo, nuevos: readonly string[]): Grupo {
  return Object.freeze({
    ...grupo,
    miembros: Object.freeze(normalizarMiembros([...grupo.miembros, ...nuevos])),
    totalMiembros: normalizarMiembros([...grupo.miembros, ...nuevos]).length,
  });
}

export function quitarMiembros(grupo: Grupo, salientes: readonly string[]): Grupo {
  const fuera = new Set(salientes);
  const restantes = grupo.miembros.filter((m) => !fuera.has(m));

  return Object.freeze({
    ...grupo,
    miembros: Object.freeze(restantes),
    totalMiembros: restantes.length,
  });
}
