/**
 * SIAN — Política de contraseñas (RF-AUT-06).
 *
 * Va más allá de contar tipos de carácter, porque contar tipos de carácter es
 * lo que produce `Umg2026!` en todo el claustro: cumple cuatro reglas de
 * composición y no resiste ni un minuto de ataque por diccionario.
 *
 * Lo que de verdad protege una contraseña, por orden de importancia:
 *
 *   1. **Longitud.** Cada carácter multiplica el espacio de búsqueda. Es el
 *      único factor que crece exponencialmente, y por eso el mínimo se
 *      mantiene en 10 y no baja.
 *   2. **No ser adivinable a partir de quien la eligió.** Una contraseña que
 *      contiene el correo, el nombre o la institución la prueba cualquiera
 *      que conozca a la persona, antes de intentar nada más.
 *   3. **No estar en las listas de siempre.** `password`, `123456`, `qwerty`
 *      y sus variantes son lo primero que se prueba.
 *   4. **No ser una secuencia ni una repetición.** `abcdefghij` tiene diez
 *      caracteres y ninguna resistencia.
 *   5. Composición: mayúscula, minúscula, dígito y símbolo.
 *
 * Las cinco se comprueban. Las cuatro primeras son las que hacen el trabajo.
 *
 * > **Dónde se aplica.** Firebase Authentication crea la credencial desde el
 * > cliente, así que esta comprobación es del cliente y no del servidor. No es
 * > un descuido: está registrado como deuda **DT-13**, con su plan de pago.
 */

export const POLITICA_CONTRASENA = {
  /**
   * RF-AUT-06. No baja de 10: es el factor que más pesa, y rebajarlo para
   * añadir un símbolo sería cambiar entropía por la apariencia de rigor.
   */
  longitudMinima: 10,
  longitudRecomendada: 14,
  exigeMayuscula: true,
  exigeMinuscula: true,
  exigeDigito: true,
  exigeSimbolo: true,
  /** Longitud mínima de un fragmento personal para considerarlo delator. */
  fragmentoPersonalMinimo: 4,
  /** Longitud de secuencia o repetición que se considera inaceptable. */
  longitudSecuencia: 4,
} as const;

export type IncumplimientoContrasena =
  | 'LONGITUD_MINIMA'
  | 'FALTA_MAYUSCULA'
  | 'FALTA_MINUSCULA'
  | 'FALTA_DIGITO'
  | 'FALTA_SIMBOLO'
  | 'CONTIENE_DATOS_PERSONALES'
  | 'DEMASIADO_COMUN'
  | 'SECUENCIA_OBVIA'
  | 'CARACTER_REPETIDO';

export type Fuerza = 'INSUFICIENTE' | 'ACEPTABLE' | 'BUENA' | 'EXCELENTE';

export interface ContextoContrasena {
  readonly correo?: string;
  readonly nombre?: string;
  /** Palabras que delatan por contexto: institución, sede, sistema. */
  readonly palabrasProhibidas?: readonly string[];
}

export interface ResultadoPolitica {
  readonly valida: boolean;
  readonly incumplimientos: readonly IncumplimientoContrasena[];
  readonly fuerza: Fuerza;
}

/**
 * Contraseñas que no protegen nada.
 *
 * No pretende ser exhaustiva —eso exigiría una lista de millones y una
 * consulta de red—, sino cubrir lo que de verdad aparece en un entorno
 * universitario guatemalteco: el nombre del sistema, el de la universidad, el
 * año en curso y los clásicos de siempre.
 */
const COMUNES: readonly string[] = [
  'password',
  'contrasena',
  'contraseña',
  '123456',
  '12345678',
  '123456789',
  'qwerty',
  'qwertyui',
  'abc123',
  'iloveyou',
  'admin',
  'administrador',
  'usuario',
  'bienvenido',
  'sian',
  'umg',
  'umgbdm',
  'marianogalvez',
  'universidad',
  'guatemala',
  'catedratico',
  'coordinacion',
  'bocadelmonte',
  'simulacro',
  'letmein',
  'welcome',
];

/** Quita tildes y pasa a minúsculas, para comparar sin que la ñ despiste. */
function normalizar(texto: string): string {
  return texto
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase();
}

/**
 * Deshace las sustituciones de siempre: `P@ssw0rd` no es más segura que
 * `password`, solo más incómoda de teclear.
 */
function deshacerSustituciones(texto: string): string {
  return texto
    .replace(/[@4]/g, 'a')
    .replace(/[3€]/g, 'e')
    .replace(/[1!|]/g, 'i')
    .replace(/0/g, 'o')
    .replace(/[5$]/g, 's')
    .replace(/7/g, 't');
}

/** Fragmentos que delatan a quien eligió la contraseña. */
function fragmentosPersonales(ctx: ContextoContrasena): string[] {
  const crudos: string[] = [];

  if (ctx.correo) {
    const local = ctx.correo.split('@')[0] ?? '';
    crudos.push(local, ...local.split(/[._\-+\d]+/));
    const dominio = ctx.correo.split('@')[1] ?? '';
    crudos.push(...dominio.split('.'));
  }
  if (ctx.nombre) {
    crudos.push(...ctx.nombre.split(/\s+/));
  }
  crudos.push(...(ctx.palabrasProhibidas ?? []));

  return crudos
    .map(normalizar)
    .filter((f) => f.length >= POLITICA_CONTRASENA.fragmentoPersonalMinimo);
}

/** ¿Hay una secuencia ascendente o descendente lo bastante larga? */
function tieneSecuencia(texto: string): boolean {
  const n = POLITICA_CONTRASENA.longitudSecuencia;
  const teclado = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm', '1234567890'];

  for (let i = 0; i + n <= texto.length; i += 1) {
    const trozo = texto.slice(i, i + n);

    // Secuencias de código: abcd, 1234, y sus inversas.
    let ascendente = true;
    let descendente = true;
    for (let j = 1; j < trozo.length; j += 1) {
      const paso = trozo.charCodeAt(j) - trozo.charCodeAt(j - 1);
      if (paso !== 1) ascendente = false;
      if (paso !== -1) descendente = false;
    }
    if (ascendente || descendente) {
      return true;
    }

    // Secuencias de teclado: qwer, asdf.
    const invertido = [...trozo].reverse().join('');
    if (teclado.some((fila) => fila.includes(trozo) || fila.includes(invertido))) {
      return true;
    }
  }
  return false;
}

/** ¿Hay un mismo carácter repetido demasiadas veces seguidas? */
function tieneRepeticion(texto: string): boolean {
  const n = POLITICA_CONTRASENA.longitudSecuencia;
  let racha = 1;
  for (let i = 1; i < texto.length; i += 1) {
    racha = texto[i] === texto[i - 1] ? racha + 1 : 1;
    if (racha >= n) {
      return true;
    }
  }
  return false;
}

/**
 * Evalúa una contraseña contra la política completa.
 *
 * Devuelve **todos** los incumplimientos, no el primero: que alguien tenga que
 * corregir cuatro veces seguidas porque el sistema le va soltando una regla
 * cada vez es una forma segura de que acabe eligiendo `Umg2026!`.
 */
export function evaluarContrasena(
  bruto: string,
  contexto: ContextoContrasena = {},
): ResultadoPolitica {
  const v = bruto ?? '';
  const incumplimientos: IncumplimientoContrasena[] = [];

  if ([...v].length < POLITICA_CONTRASENA.longitudMinima) {
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
  // Símbolo: cualquier cosa que no sea letra, dígito ni espacio.
  if (!/[^\p{L}\p{N}\s]/u.test(v)) {
    incumplimientos.push('FALTA_SIMBOLO');
  }

  const normalizada = normalizar(v);
  const desustituida = deshacerSustituciones(normalizada);

  const personales = fragmentosPersonales(contexto);
  if (personales.some((f) => normalizada.includes(f) || desustituida.includes(f))) {
    incumplimientos.push('CONTIENE_DATOS_PERSONALES');
  }

  if (
    COMUNES.some(
      (c) =>
        desustituida.includes(c) ||
        normalizada.includes(c) ||
        // También al revés: `drowssap` es igual de conocida.
        [...desustituida].reverse().join('').includes(c),
    )
  ) {
    incumplimientos.push('DEMASIADO_COMUN');
  }

  if (tieneSecuencia(normalizada)) {
    incumplimientos.push('SECUENCIA_OBVIA');
  }
  if (tieneRepeticion(v)) {
    incumplimientos.push('CARACTER_REPETIDO');
  }

  return {
    valida: incumplimientos.length === 0,
    incumplimientos,
    fuerza: calcularFuerza(v, incumplimientos.length === 0),
  };
}

/**
 * Fuerza orientativa, para la barra de la interfaz.
 *
 * No es una medida de entropía real: es una señal para que la persona vea que
 * alargar la contraseña ayuda mucho más que añadirle otro signo de admiración.
 */
function calcularFuerza(v: string, cumple: boolean): Fuerza {
  if (!cumple) {
    return 'INSUFICIENTE';
  }
  const largo = [...v].length;
  const variedad = [
    /[a-záéíóúñü]/.test(v),
    /[A-ZÁÉÍÓÚÑÜ]/.test(v),
    /\d/.test(v),
    /[^\p{L}\p{N}\s]/u.test(v),
  ].filter(Boolean).length;

  if (largo >= 16 && variedad === 4) {
    return 'EXCELENTE';
  }
  if (largo >= POLITICA_CONTRASENA.longitudRecomendada) {
    return 'BUENA';
  }
  return 'ACEPTABLE';
}
