/**
 * SIAN — Errores del dominio.
 *
 * El dominio nunca lanza errores genéricos ni cadenas sueltas: cada fallo trae
 * un código estable, apto para registrarse en bitácora (RF-BIT-02) y para
 * traducirse a un mensaje de interfaz sin que la capa de presentación tenga que
 * interpretar texto libre.
 */

export class ErrorDominio extends Error {
  constructor(
    readonly codigo: string,
    mensaje: string,
    readonly detalle?: Readonly<Record<string, unknown>>,
  ) {
    super(mensaje);
    this.name = new.target.name;
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

/** Una invariante de entidad u objeto de valor no se cumple. */
export class ErrorValidacion extends ErrorDominio {}

/**
 * Se intentó una transición que la máquina de estados no permite.
 * Es el mecanismo que impide, por ejemplo, deshacer una confirmación de
 * lectura (RF-CNF-04).
 */
export class ErrorTransicionInvalida extends ErrorDominio {
  constructor(
    readonly maquina: string,
    readonly desde: string,
    readonly hacia: string,
  ) {
    super(
      'TRANSICION_INVALIDA',
      `Transición no permitida en ${maquina}: ${desde} → ${hacia}`,
      { maquina, desde, hacia },
    );
  }
}

/** El patrón de recurrencia es incoherente o no puede producir ocurrencias. */
export class ErrorRecurrencia extends ErrorDominio {}

/** El sujeto no tiene el permiso requerido según la matriz RBAC (RN-01). */
export class ErrorAutorizacion extends ErrorDominio {}
