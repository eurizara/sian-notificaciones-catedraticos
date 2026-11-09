/**
 * SIAN — Sedes, facultades y membresías (2.0 · ADR-009 · RF-SED, RF-FAC).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Una persona pertenece a sedes, con un rol en cada una.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * SIAN nació para Boca del Monte sin que nada en los datos lo dijera. La 2.0
 * lo hace explícito: cada persona tiene **membresías** —en qué sede, con qué
 * rol y en qué facultades— y el token de sesión lleva sus sedes con el rol en
 * cada una, para que las reglas decidan sin leer Firestore, como ya hacían con
 * el rol.
 *
 * La migración es de «ampliar y después contraer» (ADR-009): mientras dure,
 * conviven perfiles con y sin membresías. Un perfil sin ellas **es** de la sede
 * inicial con el rol que ya tenía; así nada de lo que funciona cambia hasta
 * que el guion de migración escribe el dato y las reglas lo exigen.
 *
 * Funciones puras: no importan nada de Firebase (RNF-19).
 */

import { ErrorAutorizacion, ErrorValidacion } from './errores';
import { ROLES, type Rol } from './tipos';

/** La sede con que nació SIAN, Boca del Monte. */
export const SEDE_INICIAL = 'bdm';

/** La primera facultad, decidida el 06/11/2026 (documento 14, sección 7). */
export const FACULTAD_INICIAL = {
  id: 'ing-sistemas',
  nombre: 'Ingeniería en Sistemas',
} as const;

/** Forma de un identificador de sede o facultad: corto, en minúsculas, legible. */
const FORMA_DE_ID = /^[a-z0-9](?:[a-z0-9-]{0,30}[a-z0-9])?$/;

/**
 * El token de sesión admite unos 1000 bytes de claims propios. Se deja margen
 * para los que ya existen: si una persona tuviera tantas sedes que no cupieran,
 * se rechaza el cambio en vez de que Firebase falle al fijar el token.
 */
export const MAXIMO_DE_SEDES = 15;

export interface Membresia {
  readonly rol: Rol;
  /** Identificadores de facultad dentro de esa sede. Puede estar vacía. */
  readonly facultades: readonly string[];
}

/** `sedeId` → membresía. */
export type Membresias = Readonly<Record<string, Membresia>>;

/** Lo que viaja en el token: `sedeId` → rol. Las facultades no hacen falta ahí. */
export type SedesDelToken = Readonly<Record<string, Rol>>;

export function esIdDeSede(valor: unknown): valor is string {
  return typeof valor === 'string' && FORMA_DE_ID.test(valor);
}

/** Mismo formato que la sede: así un identificador sirve igual en rutas y reglas. */
export const esIdDeFacultad = esIdDeSede;

function esRol(valor: unknown): valor is Rol {
  return typeof valor === 'string' && (ROLES as readonly string[]).includes(valor);
}

/**
 * Las membresías de un perfil, tal como están guardadas o, si aún no las
 * tiene, las que tendría: la sede inicial con su rol de siempre.
 *
 * Lo que no tiene forma válida se descarta en silencio, entrada por entrada:
 * un dato mal escrito a mano en la consola no puede dejar a alguien sin acceso
 * a la sede donde sí está bien escrito. Si no queda ninguna válida, se usa la
 * de omisión.
 */
export function membresiasDe(perfil: { readonly rol: Rol; readonly membresias?: unknown }): Membresias {
  const crudas = perfil.membresias;
  const validas: Record<string, Membresia> = {};
  if (crudas !== null && typeof crudas === 'object' && !Array.isArray(crudas)) {
    for (const [sedeId, valor] of Object.entries(crudas as Record<string, unknown>)) {
      if (!esIdDeSede(sedeId) || valor === null || typeof valor !== 'object') {
        continue;
      }
      const rol = (valor as { rol?: unknown }).rol;
      if (!esRol(rol)) {
        continue;
      }
      const facultades = (valor as { facultades?: unknown }).facultades;
      validas[sedeId] = {
        rol,
        facultades: Array.isArray(facultades)
          ? [...new Set(facultades.filter(esIdDeFacultad))].sort()
          : [],
      };
    }
  }
  if (Object.keys(validas).length > 0) {
    return validas;
  }
  return { [SEDE_INICIAL]: { rol: perfil.rol, facultades: [] } };
}

/** Lo que va al token: una entrada por sede, en orden estable. */
export function sedesDeMembresias(membresias: Membresias): SedesDelToken {
  const sedes: Record<string, Rol> = {};
  for (const [sedeId, membresia] of Object.entries(membresias).sort(([a], [b]) => a.localeCompare(b))) {
    sedes[sedeId] = membresia.rol;
  }
  return sedes;
}

/**
 * La sede «de siempre» de una persona: la inicial si pertenece a ella, si no
 * la primera en orden alfabético.
 *
 * Existe por compatibilidad: el campo `rol` del perfil y del token sigue
 * diciendo el rol en esta sede, porque las versiones de la aplicación
 * anteriores a la 2.0 solo saben leer ese campo.
 */
export function sedePrincipal(membresias: Membresias): string {
  const ids = Object.keys(membresias).sort();
  if (ids.includes(SEDE_INICIAL)) {
    return SEDE_INICIAL;
  }
  return ids[0] ?? SEDE_INICIAL;
}

/**
 * Las sedes del token. Un token sin `sedes` es de antes de la 2.0: equivale a
 * la sede inicial con el rol global, igual que un perfil sin membresías.
 */
export function sedesDelToken(token: Readonly<Record<string, unknown>>, rolGlobal: Rol): SedesDelToken {
  const crudas = token.sedes;
  const sedes: Record<string, Rol> = {};
  if (crudas !== null && typeof crudas === 'object' && !Array.isArray(crudas)) {
    for (const [sedeId, rol] of Object.entries(crudas as Record<string, unknown>)) {
      if (esIdDeSede(sedeId) && esRol(rol)) {
        sedes[sedeId] = rol;
      }
    }
  }
  return Object.keys(sedes).length > 0 ? sedes : { [SEDE_INICIAL]: rolGlobal };
}

/**
 * ¿En qué sede actúa esta petición? (RF-SED-04, RF-SED-05)
 *
 *   · Si la petición dice una sede, tiene que ser una de las suyas.
 *   · Si no dice ninguna y la persona tiene una sola, es esa: con una sede no
 *     se le pregunta nada.
 *   · Si tiene varias y no dice cuál, se rechaza: adivinar la sede es la forma
 *     más rápida de mandar un aviso a la gente equivocada.
 */
export function elegirSede(sedes: SedesDelToken, pedida?: unknown): string {
  const propias = Object.keys(sedes);
  if (pedida !== undefined && pedida !== null && pedida !== '') {
    if (!esIdDeSede(pedida) || !propias.includes(pedida)) {
      throw new ErrorAutorizacion(
        'SEDE_AJENA',
        'Esa sede no es una de las suyas.',
        { sedePedida: String(pedida) },
      );
    }
    return pedida;
  }
  const unica = propias.length === 1 ? propias[0] : undefined;
  if (unica !== undefined) {
    return unica;
  }
  throw new ErrorValidacion(
    'FALTA_SEDE',
    'Pertenece a más de una sede: hay que decir en cuál se trabaja.',
    { sedes: propias.join(',') },
  );
}

/** El rol de la persona en esa sede, o `null` si no pertenece a ella. */
export function rolEnSede(sedes: SedesDelToken, sedeId: string): Rol | null {
  return Object.prototype.hasOwnProperty.call(sedes, sedeId) ? (sedes[sedeId] ?? null) : null;
}

/** ¿Pertenece a esa sede, según sus membresías (o su sede por omisión)? */
export function perteneceASede(
  perfil: { readonly rol: Rol; readonly membresias?: unknown },
  sedeId: string,
): boolean {
  return Object.prototype.hasOwnProperty.call(membresiasDe(perfil), sedeId);
}

/** La sede de un documento. Sin `sedeId` es de antes de la 2.0: la inicial. */
export function sedeDelDocumento(datos: { readonly sedeId?: unknown } | undefined): string {
  return esIdDeSede(datos?.sedeId) ? datos.sedeId : SEDE_INICIAL;
}

/**
 * Cambia el rol de una persona en una sede, sin tocar las demás.
 *
 * Si la persona aún no tenía membresías guardadas, parte de las de omisión:
 * así el primer cambio después de la 2.0 deja el perfil migrado.
 */
export function conRolEnSede(
  perfil: { readonly rol: Rol; readonly membresias?: unknown },
  sedeId: string,
  rol: Rol,
): Membresias {
  const actuales = membresiasDe(perfil);
  const previa = actuales[sedeId];
  const nuevas: Record<string, Membresia> = {
    ...actuales,
    [sedeId]: { rol, facultades: previa?.facultades ?? [] },
  };
  if (Object.keys(nuevas).length > MAXIMO_DE_SEDES) {
    throw new ErrorValidacion(
      'DEMASIADAS_SEDES',
      `Una persona puede pertenecer a ${MAXIMO_DE_SEDES} sedes como máximo.`,
    );
  }
  return nuevas;
}

/**
 * Las facultades de una persona en una sede (RF-FAC-01), sin tocar su rol ni
 * sus otras sedes. Tiene que pertenecer a la sede, y cada facultad tiene que
 * estar en el catálogo de esa sede y activa: una facultad inventada dejaría a
 * esa persona fuera de los avisos por facultad sin que nadie lo notara.
 */
export function conFacultadesEnSede(
  perfil: { readonly rol: Rol; readonly membresias?: unknown },
  sedeId: string,
  facultades: unknown,
  catalogo: readonly { readonly id: string; readonly activa: boolean }[],
): Membresias {
  const actuales = membresiasDe(perfil);
  const membresia = actuales[sedeId];
  if (membresia === undefined) {
    throw new ErrorValidacion('NO_PERTENECE_A_LA_SEDE', 'Esa persona no pertenece a esta sede.');
  }
  if (!Array.isArray(facultades) || !facultades.every(esIdDeFacultad)) {
    throw new ErrorValidacion('FACULTADES_INVALIDAS', 'La lista de facultades no es válida.');
  }
  const activas = new Set(catalogo.filter((f) => f.activa).map((f) => f.id));
  for (const f of facultades) {
    if (!activas.has(f)) {
      throw new ErrorValidacion(
        'FACULTAD_INEXISTENTE',
        `La facultad «${f}» no existe o está inactiva en esta sede.`,
        { facultadId: f },
      );
    }
  }
  return {
    ...actuales,
    [sedeId]: { rol: membresia.rol, facultades: [...new Set(facultades)].sort() },
  };
}

/**
 * Saca a una persona de una sede (RF-SED-06), sin tocar las demás. No puede
 * quedarse sin ninguna: una cuenta sin sede no tendría dónde trabajar ni de
 * dónde recibir avisos; para eso está desactivarla.
 */
export function sinSede(
  perfil: { readonly rol: Rol; readonly membresias?: unknown },
  sedeId: string,
): Membresias {
  const actuales = membresiasDe(perfil);
  if (actuales[sedeId] === undefined) {
    throw new ErrorValidacion('NO_PERTENECE_A_LA_SEDE', 'Esa persona no pertenece a esa sede.');
  }
  const restantes: Record<string, Membresia> = {};
  for (const [id, m] of Object.entries(actuales)) {
    if (id !== sedeId) {
      restantes[id] = m;
    }
  }
  if (Object.keys(restantes).length === 0) {
    throw new ErrorValidacion(
      'ULTIMA_SEDE',
      'Es su única sede. Si ya no debe usar SIAN, desactive la cuenta en lugar de quitarle la sede.',
    );
  }
  return restantes;
}

/**
 * ¿Puede esta persona dar o quitar la administración general a otra? (2.0.2)
 *
 * La da quien coordina: la coordinación de una sede, a gente de su sede, o la
 * administración general, a gente de cualquier sede. Se da solo a quien
 * coordina en alguna sede, y nadie se la cambia a sí mismo: así siempre queda
 * otra persona que pueda corregirlo.
 *
 * Devuelve `null` si puede, o el motivo por el que no.
 */
export function motivoParaNoCambiarAdminGeneral(entrada: {
  readonly actorUid: string;
  readonly actorEsAdminGeneral: boolean;
  /** El rol de quien pide en la sede donde actúa. */
  readonly actorRolEnSede: Rol | null;
  readonly sedeId: string;
  readonly objetivo: { readonly uid: string; readonly rol: Rol; readonly membresias?: unknown };
  readonly valor: boolean;
}): string | null {
  const { objetivo } = entrada;
  if (objetivo.uid === entrada.actorUid) {
    return 'No puede cambiar su propia administración general.';
  }
  const coordinaAqui = entrada.actorRolEnSede === 'COORDINADOR';
  const esDeSuSede = membresiasDe(objetivo)[entrada.sedeId] !== undefined;
  if (!entrada.actorEsAdminGeneral && !(coordinaAqui && esDeSuSede)) {
    return 'Solo la coordinación de la sede de esa persona, o la administración general, puede cambiarla.';
  }
  if (entrada.valor && !Object.values(membresiasDe(objetivo)).some((m) => m.rol === 'COORDINADOR')) {
    return 'La administración general se da a quien coordina en alguna sede.';
  }
  return null;
}

