/**
 * SIAN — Fallos que ocurren en el aparato (DT-34).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Lo que falla en el aparato solo llega a su consola, que nadie ve.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * El 12/09/2026 el registro de dispositivos se colgó en TODOS los aparatos
 * (`serviceWorker.ready` no resolvía) y el servidor no registró un solo error:
 * se supo porque un aviso de prueba no llegó. Esto es el punto de reporte
 * mínimo que faltó.
 *
 * Tres reglas, y las tres se prueban:
 *
 *   · **Nada personal.** Qué falló (de una lista cerrada), la versión, la
 *     plataforma y un identificador de aparato al azar que no está ligado a
 *     ninguna persona. El detalle técnico pasa por [limpiarDetalle].
 *   · **Con tope.** Un documento por aparato, tipo y día; como mucho una
 *     escritura por minuto en cada uno, y un máximo de documentos nuevos al
 *     día. Quien quiera llenar la base se topa con el tope, no con la factura.
 *   · **Se olvida.** La sonda diaria borra lo de más de 30 días.
 */

/** Qué puede fallar. Lo que no está aquí se descarta. */
export const TIPOS_DE_FALLO = [
  // Firebase no arrancó: la app muestra el diagnóstico en vez del ingreso.
  'arranque',
  // El registro del aparato para recibir avisos terminó en error.
  'registro-dispositivo',
  // La suscripción con llave propia no respondió a tiempo (se siguió por FCM).
  'suscripcion-propia',
  // No se obtuvo el registro del service worker.
  'worker',
  // No se pudo mostrar una notificación con la app abierta.
  'notificacion',
  // App Check no encendió (DT-33).
  'app-check',
  // Un error que nadie atrapó.
  'no-controlado',
] as const;

export type TipoDeFallo = (typeof TIPOS_DE_FALLO)[number];

const PLATAFORMAS = new Set(['WEB_IOS', 'WEB_ANDROID', 'WEB_ESCRITORIO']);

/** Como mucho una escritura por minuto por aparato y tipo. */
export const SEGUNDOS_ENTRE_REPORTES = 60;

/** Documentos nuevos por día, entre todos los aparatos. */
export const DOCUMENTOS_POR_DIA = 500;

/** Lo que la sonda conserva. */
export const DIAS_DE_FALLOS = 30;

export const LARGO_DE_DETALLE = 200;

export interface ReporteDeFallo {
  readonly que: TipoDeFallo;
  readonly version: string;
  readonly plataforma: string;
  readonly aparato: string;
  readonly detalle: string;
}

/** El cuerpo de la petición, o nulo si no es un reporte aceptable. */
export function leerReporte(cuerpo: unknown): ReporteDeFallo | null {
  if (cuerpo === null || typeof cuerpo !== 'object' || Array.isArray(cuerpo)) {
    return null;
  }
  const c = cuerpo as Record<string, unknown>;

  const que = TIPOS_DE_FALLO.find((t) => t === c.que);
  if (que === undefined) {
    return null;
  }
  // El que genera la aplicación: 16 a 64 caracteres seguros para un id.
  if (typeof c.aparato !== 'string' || !/^[A-Za-z0-9_-]{16,64}$/.test(c.aparato)) {
    return null;
  }

  const version =
    typeof c.version === 'string' && /^\d{1,3}\.\d{1,3}\.\d{1,4}$/.test(c.version.trim())
      ? c.version.trim()
      : '';
  const plataforma =
    typeof c.plataforma === 'string' && PLATAFORMAS.has(c.plataforma) ? c.plataforma : 'OTRA';

  return { que, version, plataforma, aparato: c.aparato, detalle: limpiarDetalle(c.detalle) };
}

/**
 * El detalle técnico, sin nada que identifique a alguien.
 *
 * Un mensaje de error puede traer un correo («user-not-found: ana@…»), un
 * token, o una dirección con credenciales en la consulta. Se queda lo que
 * sirve para diagnosticar —el nombre de la excepción, un código, una
 * duración— y se recorta.
 */
export function limpiarDetalle(texto: unknown): string {
  if (typeof texto !== 'string') {
    return '';
  }
  const limpio = texto
    // De una dirección, solo el sitio: la ruta y la consulta pueden llevar datos.
    .replace(/\bhttps?:\/\/([^/\s?#]+)\S*/gi, (_, sitio: string) => `https://${sitio}/…`)
    .replace(/[\w.+-]+@[\w-]+(?:\.[\w-]+)+/g, '[correo]')
    .replace(/[A-Za-z0-9_-]{24,}/g, '[clave]')
    .replace(/\+?\d[\d\s-]{4,}\d/g, (m) => (m.replace(/\D/g, '').length >= 6 ? '[número]' : m))
    .replace(/\s+/g, ' ')
    .trim();
  return limpio.length <= LARGO_DE_DETALLE ? limpio : `${limpio.slice(0, LARGO_DE_DETALLE - 1)}…`;
}

/** Un documento por aparato, tipo y día (UTC). */
export function idDeFallo(r: ReporteDeFallo, ahora: Date): string {
  const dia = ahora.toISOString().slice(0, 10).replace(/-/g, '');
  return `${dia}_${r.aparato}_${r.que}`;
}

/**
 * ¿Se escribe este reporte?
 *
 * `existente` es el documento de hoy de ese aparato y tipo, si lo hay;
 * `documentosHoy`, cuántos se crearon hoy entre todos.
 */
export function decidirEscritura(
  existente: { ultimo: Date } | null,
  documentosHoy: number,
  ahora: Date,
): 'nuevo' | 'sumar' | 'ignorar' {
  if (existente === null) {
    return documentosHoy >= DOCUMENTOS_POR_DIA ? 'ignorar' : 'nuevo';
  }
  const segundos = (ahora.getTime() - existente.ultimo.getTime()) / 1000;
  return segundos >= SEGUNDOS_ENTRE_REPORTES ? 'sumar' : 'ignorar';
}

export interface FalloGuardado {
  readonly aparato: string;
  readonly que: string;
  readonly ultimo: Date;
  readonly veces: number;
  readonly plataforma: string;
  readonly version: string;
  readonly detalle: string;
}

export interface ResumenDeFallos {
  /** Aparatos distintos con algún fallo en las últimas 24 horas. */
  readonly aparatos: number;
  readonly reportes: number;
  readonly porTipo: readonly {
    readonly que: string;
    readonly aparatos: number;
    readonly veces: number;
    readonly plataformas: readonly string[];
    readonly versiones: readonly string[];
    readonly ultimoDetalle: string;
  }[];
}

/** Lo que ve Alcance: las últimas 24 horas, por tipo. */
export function resumirFallos(fallos: readonly FalloGuardado[], ahora: Date): ResumenDeFallos {
  const desde = ahora.getTime() - 24 * 3_600_000;
  const recientes = fallos.filter((f) => f.ultimo.getTime() >= desde);

  const porTipo = new Map<string, FalloGuardado[]>();
  for (const f of recientes) {
    porTipo.set(f.que, [...(porTipo.get(f.que) ?? []), f]);
  }

  const tipos = [...porTipo.entries()].map(([que, lista]) => {
    const masReciente = [...lista].sort((a, b) => b.ultimo.getTime() - a.ultimo.getTime())[0]!;
    return {
      que,
      aparatos: new Set(lista.map((f) => f.aparato)).size,
      veces: lista.reduce((n, f) => n + f.veces, 0),
      plataformas: [...new Set(lista.map((f) => f.plataforma))].sort(),
      versiones: [...new Set(lista.map((f) => f.version).filter((v) => v.length > 0))].sort(
        (a, b) => a.localeCompare(b, 'es', { numeric: true }),
      ),
      ultimoDetalle: masReciente.detalle,
    };
  });
  tipos.sort((a, b) => b.aparatos - a.aparatos || b.veces - a.veces);

  return {
    aparatos: new Set(recientes.map((f) => f.aparato)).size,
    reportes: recientes.reduce((n, f) => n + f.veces, 0),
    porTipo: tipos,
  };
}
