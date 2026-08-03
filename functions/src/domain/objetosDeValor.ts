/**
 * SIAN — Objetos de valor.
 *
 * Un objeto de valor no se construye con `new`: se construye con `crear`, que
 * o devuelve una instancia válida o lanza. Esa es toda la idea. Si un `Titulo`
 * existe, mide entre 1 y 80 caracteres; no hace falta volver a comprobarlo en
 * ninguna otra capa (RF-MSG-06).
 */

import { ErrorValidacion } from './errores';
import { LIMITES } from './tipos';

/**
 * Base común: inmutable, comparable por valor, serializable a su primitivo.
 *
 * El congelado NO se hace aquí: cuando corre el constructor de la base, las
 * propiedades declaradas en el constructor de la subclase todavía no se han
 * asignado, y congelar en este punto haría fallar la construcción de cualquier
 * objeto de valor con campos propios. Se congela en cada `crear`.
 */
abstract class ObjetoDeValor<T> {
  protected constructor(readonly valor: T) {}

  equals(otro: ObjetoDeValor<T> | null | undefined): boolean {
    return otro != null && otro.constructor === this.constructor && otro.valor === this.valor;
  }

  toString(): string {
    return String(this.valor);
  }

  toJSON(): T {
    return this.valor;
  }
}

// ---------------------------------------------------------------------------
// Titulo — RF-MSG-06
// ---------------------------------------------------------------------------

export class Titulo extends ObjetoDeValor<string> {
  static crear(bruto: string): Titulo {
    const v = (bruto ?? '').trim();
    if (v.length === 0) {
      throw new ErrorValidacion('TITULO_VACIO', 'El título del mensaje es obligatorio.');
    }
    if ([...v].length > LIMITES.TITULO_MAX) {
      throw new ErrorValidacion(
        'TITULO_MUY_LARGO',
        `El título no puede exceder ${LIMITES.TITULO_MAX} caracteres.`,
        { longitud: [...v].length, maximo: LIMITES.TITULO_MAX },
      );
    }
    return Object.freeze(new Titulo(v));
  }
}

// ---------------------------------------------------------------------------
// Cuerpo — RF-MSG-06
// ---------------------------------------------------------------------------

export class Cuerpo extends ObjetoDeValor<string> {
  static crear(bruto: string): Cuerpo {
    const v = (bruto ?? '').trim();
    if (v.length === 0) {
      throw new ErrorValidacion('CUERPO_VACIO', 'El cuerpo del mensaje es obligatorio.');
    }
    if ([...v].length > LIMITES.CUERPO_MAX) {
      throw new ErrorValidacion(
        'CUERPO_MUY_LARGO',
        `El cuerpo no puede exceder ${LIMITES.CUERPO_MAX} caracteres.`,
        { longitud: [...v].length, maximo: LIMITES.CUERPO_MAX },
      );
    }
    return Object.freeze(new Cuerpo(v));
  }
}

// ---------------------------------------------------------------------------
// CorreoInstitucional — RF-AUT-03, documento 05, sección 2.10
//
// El identificador del documento de `invitaciones` ES el correo normalizado,
// así que la normalización no es cosmética: determina si la lista blanca
// encuentra o no al usuario.
// ---------------------------------------------------------------------------

const PATRON_CORREO = /^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$/;

export class CorreoInstitucional extends ObjetoDeValor<string> {
  static crear(bruto: string): CorreoInstitucional {
    const v = (bruto ?? '').trim().toLowerCase();
    if (v.length === 0) {
      throw new ErrorValidacion('CORREO_VACIO', 'El correo es obligatorio.');
    }
    if (!PATRON_CORREO.test(v)) {
      throw new ErrorValidacion('CORREO_INVALIDO', `El correo «${bruto}» no tiene forma válida.`, {
        correo: bruto,
      });
    }
    return Object.freeze(new CorreoInstitucional(v));
  }

  get dominio(): string {
    return this.valor.slice(this.valor.indexOf('@') + 1);
  }
}

// ---------------------------------------------------------------------------
// HoraLocal — 'HH:mm' en zona institucional (RF-PRG-07, RF-PRG-08)
// ---------------------------------------------------------------------------

const PATRON_HORA = /^([01]\d|2[0-3]):([0-5]\d)$/;

export class HoraLocal extends ObjetoDeValor<string> {
  private constructor(
    valor: string,
    readonly hora: number,
    readonly minuto: number,
  ) {
    super(valor);
  }

  static crear(bruto: string): HoraLocal {
    const v = (bruto ?? '').trim();
    const m = PATRON_HORA.exec(v);
    if (!m) {
      throw new ErrorValidacion(
        'HORA_INVALIDA',
        `«${bruto}» no es una hora válida. Formato esperado: HH:mm en 24 horas.`,
        { valor: bruto },
      );
    }
    return Object.freeze(new HoraLocal(v, Number(m[1]), Number(m[2])));
  }

  /** Minutos transcurridos desde la medianoche. Sirve para comparar franjas. */
  get minutosDesdeMedianoche(): number {
    return this.hora * 60 + this.minuto;
  }
}

// ---------------------------------------------------------------------------
// Contraseña — RF-AUT-06
//
// El dominio solo dicta la política. El hash y el almacenamiento son de
// Firebase Authentication y no pasan jamás por aquí.
// ---------------------------------------------------------------------------

export const POLITICA_CONTRASENA = {
  longitudMinima: 10,
  exigeMayuscula: true,
  exigeMinuscula: true,
  exigeDigito: true,
} as const;

export interface ResultadoPolitica {
  readonly valida: boolean;
  readonly incumplimientos: readonly string[];
}

export function evaluarContrasena(bruto: string): ResultadoPolitica {
  const v = bruto ?? '';
  const incumplimientos: string[] = [];

  if (v.length < POLITICA_CONTRASENA.longitudMinima) {
    incumplimientos.push('LONGITUD_MINIMA');
  }
  if (!/[A-ZÁÉÍÓÚÑÜ]/.test(v)) {
    incumplimientos.push('FALTA_MAYUSCULA');
  }
  if (!/[a-záéíóúñü]/.test(v)) {
    incumplimientos.push('FALTA_MINUSCULA');
  }
  if (!/\d/.test(v)) {
    incumplimientos.push('FALTA_DIGITO');
  }

  return { valida: incumplimientos.length === 0, incumplimientos };
}
