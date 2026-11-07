/**
 * SIAN — Mantenimiento de catálogos (2.0 · RF-CAT-01 a RF-CAT-05).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Un solo patrón para todos los catálogos: sedes, facultades y los que vengan.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Un catálogo es una lista que alguien mantiene y el resto del sistema usa para
 * elegir. Todos se comportan igual (heurística de consistencia):
 *
 *   · el nombre es obligatorio, legible, y no se repite en el mismo catálogo
 *     —sin distinguir mayúsculas ni tildes: «Ingeniería» e «ingenieria» son el
 *     mismo nombre para quien elige de una lista— (RF-CAT-03);
 *   · el identificador nace del nombre y NO cambia después: está en rutas, en
 *     tokens y en los datos que ya lo usan;
 *   · no se borra nada: se desactiva, y lo ya registrado conserva su nombre
 *     (RF-CAT-02).
 *
 * Funciones puras (RNF-19).
 */

import { ErrorValidacion } from './errores';
import { esIdDeSede } from './sede';

export const LARGO_MINIMO_NOMBRE = 2;
export const LARGO_MAXIMO_NOMBRE = 80;

export interface ElementoCatalogo {
  readonly id: string;
  readonly nombre: string;
  readonly activa: boolean;
}

export interface EntradaCatalogo {
  /** Ausente al crear: se deriva del nombre. */
  readonly id?: unknown;
  readonly nombre?: unknown;
  readonly activa?: unknown;
}

export interface DecisionCatalogo {
  readonly elemento: ElementoCatalogo;
  readonly nuevo: boolean;
  /** Qué cambió, para la bitácora (RF-CAT-04). Vacío si no cambió nada. */
  readonly cambios: readonly string[];
}

/** Para comparar nombres: sin tildes, sin mayúsculas, sin espacios de más. */
export function claveDeNombre(nombre: string): string {
  return nombre
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Un identificador legible a partir del nombre: «Ingeniería en Sistemas» →
 * `ingenieria-en-sistemas`. Con la misma forma que exigen las sedes, para que
 * sirva igual en rutas, en el token y en las reglas.
 */
export function idDesdeNombre(nombre: string): string {
  const base = claveDeNombre(nombre)
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 32)
    .replace(/-+$/g, '');
  return base;
}

/**
 * Decide qué guardar (alta o edición), o lanza con un mensaje que dice qué
 * corregir. `existentes` es el catálogo tal como está ahora.
 */
export function decidirGuardado(
  entrada: EntradaCatalogo,
  existentes: readonly ElementoCatalogo[],
): DecisionCatalogo {
  const nombre = typeof entrada.nombre === 'string' ? entrada.nombre.replace(/\s+/g, ' ').trim() : '';
  if (nombre.length < LARGO_MINIMO_NOMBRE || nombre.length > LARGO_MAXIMO_NOMBRE) {
    throw new ErrorValidacion(
      'NOMBRE_INVALIDO',
      `El nombre debe tener entre ${LARGO_MINIMO_NOMBRE} y ${LARGO_MAXIMO_NOMBRE} caracteres.`,
    );
  }

  const pedido = entrada.id;
  const previo =
    pedido === undefined || pedido === null || pedido === ''
      ? undefined
      : existentes.find((e) => e.id === pedido);

  if (pedido !== undefined && pedido !== null && pedido !== '' && previo === undefined) {
    throw new ErrorValidacion('ELEMENTO_INEXISTENTE', 'Ese elemento no existe en el catálogo.', {
      id: String(pedido),
    });
  }

  const id = previo?.id ?? idDesdeNombre(nombre);
  if (!esIdDeSede(id)) {
    throw new ErrorValidacion(
      'NOMBRE_INVALIDO',
      'El nombre tiene que incluir letras o números.',
    );
  }

  const clave = claveDeNombre(nombre);
  const repetido = existentes.find((e) => e.id !== id && claveDeNombre(e.nombre) === clave);
  if (repetido !== undefined) {
    throw new ErrorValidacion('NOMBRE_REPETIDO', `Ya existe «${repetido.nombre}» en este catálogo.`, {
      id: repetido.id,
    });
  }
  if (previo === undefined && existentes.some((e) => e.id === id)) {
    // Mismo identificador derivado con otro nombre visible (p. ej. signos
    // distintos): se trata como repetido, porque el identificador es para
    // siempre.
    throw new ErrorValidacion('NOMBRE_REPETIDO', 'Ya existe un elemento con un nombre equivalente.', { id });
  }

  const activa = typeof entrada.activa === 'boolean' ? entrada.activa : (previo?.activa ?? true);
  const elemento: ElementoCatalogo = { id, nombre, activa };

  const cambios: string[] = [];
  if (previo === undefined) {
    cambios.push('alta');
  } else {
    if (previo.nombre !== nombre) cambios.push(`nombre: «${previo.nombre}» → «${nombre}»`);
    if (previo.activa !== activa) cambios.push(activa ? 'reactivado' : 'desactivado');
  }

  return { elemento, nuevo: previo === undefined, cambios };
}
