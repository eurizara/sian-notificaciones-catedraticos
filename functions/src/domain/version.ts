/**
 * SIAN — Versiones de la aplicación en los aparatos.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Se comparan por tramos numéricos, nunca como texto.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Como cadena, «1.5.10» va antes que «1.5.9». Mientras la versión no pasó de un
 * dígito nadie lo notó; el 13 de septiembre de 2026 salió 1.5.10, y dos sitios
 * que elegían «la versión más reciente» de una persona con `.sort()` empezaron
 * a quedarse con la vieja.
 */

/**
 * Negativo si `a` es anterior, positivo si es posterior, cero si son iguales.
 *
 * Lo que no tiene forma de versión va antes que cualquier versión: una versión
 * desconocida nunca puede pasar por la más reciente.
 */
export function compararVersiones(a: string, b: string): number {
  const ta = tramos(a);
  const tb = tramos(b);
  if (ta === null || tb === null) {
    return (ta === null ? 0 : 1) - (tb === null ? 0 : 1);
  }
  for (let i = 0; i < 3; i += 1) {
    if (ta[i] !== tb[i]) {
      return ta[i]! - tb[i]!;
    }
  }
  return 0;
}

/** La más alta de una lista, o vacío si ninguna tiene forma de versión. */
export function versionMasAlta(versiones: readonly string[]): string {
  const validas = versiones.map((v) => v.trim()).filter((v) => tramos(v) !== null);
  return [...validas].sort(compararVersiones).at(-1) ?? '';
}

function tramos(version: string): number[] | null {
  const partes = version.trim().split('.');
  if (partes.length !== 3 || partes.some((p) => !/^\d+$/.test(p))) {
    return null;
  }
  return partes.map((p) => Number.parseInt(p, 10));
}

// --- Qué versión tiene cada persona (pantalla de Alcance) --------------------

export interface PersonaConAparatos {
  readonly uid: string;
  readonly nombre: string;
  readonly correo: string;
}

export interface AparatoConVersion {
  readonly uid: string;
  readonly plataforma: string;
  /** «Safari», «Chrome», «Firefox»… Distingue un navegador de otro en el mismo teléfono. */
  readonly navegador: string;
  readonly versionApp: string;
  readonly ultimaActividad: Date | null;
}

export interface VersionesDePersona {
  readonly uid: string;
  readonly nombre: string;
  readonly correo: string;
  readonly aparatos: readonly {
    readonly plataforma: string;
    readonly navegador: string;
    readonly versionApp: string;
    readonly ultimaActividad: string | null;
  }[];
}

/**
 * Cada persona con sus aparatos y la versión de cada uno.
 *
 * Va **por aparato**, no una versión por persona: alguien puede tener el
 * teléfono al día y la computadora atrasada, y es la computadora la que hay que
 * pedirle abrir. Quien no tiene ningún aparato no aparece aquí — eso ya lo dice
 * la lista de canal.
 *
 * Aquí no se decide quién está atrasado: la versión publicada la conoce la
 * aplicación (`version.json` del ambiente), no las funciones.
 */
export function resumirVersiones(
  personas: readonly PersonaConAparatos[],
  aparatos: readonly AparatoConVersion[],
): VersionesDePersona[] {
  const porUid = new Map<string, AparatoConVersion[]>();
  for (const a of aparatos) {
    const lista = porUid.get(a.uid) ?? [];
    lista.push(a);
    porUid.set(a.uid, lista);
  }

  return personas
    .filter((p) => (porUid.get(p.uid)?.length ?? 0) > 0)
    .map((p) => ({
      uid: p.uid,
      nombre: p.nombre,
      correo: p.correo,
      aparatos: (porUid.get(p.uid) ?? []).map((a) => ({
        plataforma: a.plataforma,
        navegador: a.navegador.trim(),
        versionApp: a.versionApp.trim(),
        ultimaActividad: a.ultimaActividad?.toISOString() ?? null,
      })),
    }))
    .sort((a, b) => (a.nombre || a.correo).localeCompare(b.nombre || b.correo, 'es'));
}
