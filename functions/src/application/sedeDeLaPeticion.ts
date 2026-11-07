/**
 * SIAN — En qué sede actúa una petición, y con qué rol (2.0, ADR-009).
 *
 * Toda función que trabaja con datos de una sede empieza por aquí: decide en
 * qué sede actúa quien llama (`elegirSede`) y con qué rol ALLÍ, y ese rol —no
 * el global— es el que se pasa a `exigirPermiso`. Es la segunda de las tres
 * defensas del ADR-009: el dominio recibe la sede como dato obligatorio.
 *
 * Funciones puras, para probarlas sin levantar nada.
 */

import type { Sujeto } from '../domain/autorizacion';
import { elegirSede, membresiasDe, rolEnSede, sedesDelToken, type SedesDelToken } from '../domain/sede';
import { ROLES, type Rol } from '../domain/tipos';

export interface SedeDeLaPeticion {
  readonly sedeId: string;
  /** El rol en ESA sede. */
  readonly rol: Rol;
  readonly sedes: SedesDelToken;
}

/**
 * En qué sede actúa la petición y con qué rol. Lanza `SEDE_AJENA` o
 * `FALTA_SEDE` (errores de dominio) si no se puede decidir sin adivinar.
 */
export function sedeDeLaPeticion(token: Readonly<Record<string, unknown>>, pedida?: unknown): SedeDeLaPeticion {
  const rolGlobal = (ROLES as readonly string[]).includes(token.rol as string)
    ? (token.rol as Rol)
    : 'CATEDRATICO';
  const sedes = sedesDelToken(token, rolGlobal);
  const sedeId = elegirSede(sedes, pedida);
  return { sedeId, rol: rolEnSede(sedes, sedeId) ?? rolGlobal, sedes };
}

/**
 * Quién pide, en qué sede y con qué rol ALLÍ: lo que `exigirPermiso` necesita.
 * Lanza errores de dominio (`SEDE_AJENA`, `FALTA_SEDE`) para que cada función
 * los traduzca como traduce los demás.
 */
export function sujetoEnSede(
  auth: { uid: string; token: Readonly<Record<string, unknown>> },
  pedida?: unknown,
): Sujeto & { sedeId: string } {
  const { sedeId, rol } = sedeDeLaPeticion(auth.token, pedida);
  return {
    uid: auth.uid,
    rol,
    sedeId,
    activo: auth.token.activo === true,
    puedeEmitirUrgentes: auth.token.puedeEmitirUrgentes === true,
    puedeCrearRecurrentes: auth.token.puedeCrearRecurrentes === true,
  };
}

/**
 * El rol de alguien en una sede según su perfil guardado, o `null` si no
 * pertenece. Un perfil sin membresías es de la sede inicial con su rol.
 */
export function rolDelPerfilEnSede(
  datos: { readonly rol?: unknown; readonly membresias?: unknown },
  sedeId: string,
): Rol | null {
  const rol = (ROLES as readonly string[]).includes(datos.rol as string) ? (datos.rol as Rol) : 'CATEDRATICO';
  return membresiasDe({ rol, membresias: datos.membresias })[sedeId]?.rol ?? null;
}
