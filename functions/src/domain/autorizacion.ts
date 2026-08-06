/**
 * SIAN — Matriz RBAC como código (documento 01, sección 2.2 · RN-01).
 *
 * RN-01 dice que la matriz de permisos es «la única fuente de verdad de
 * autorización», y que se implementa en tres puntos que deben coincidir:
 * custom claims, reglas de Firestore y validación de servidor. Este archivo es
 * ese tercer punto, y es el único de los tres que se puede probar exhaustivamente
 * sin levantar nada.
 *
 * Una comprobación hecha solo en la interfaz se considera defecto de seguridad,
 * así que nada de lo que hay aquí debe darse por hecho en el cliente.
 */

import { ErrorAutorizacion } from './errores';
import type { Rol } from './tipos';

export const PERMISOS = [
  'CREAR_AVISO_INFORMATIVO',
  'CREAR_ALERTA_URGENTE',
  'ADJUNTAR_MULTIMEDIA',
  'PROGRAMAR_ENVIO',
  'CREAR_RECURRENTE',
  'CANCELAR_PROGRAMACION',
  'EXIGIR_CONFIRMACION',
  'VER_REPORTE_ENTREGAS',
  'VER_BITACORA_COMPLETA',
  'ADMINISTRAR_USUARIOS',
  'ADMINISTRAR_GRUPOS',
  'CONFIRMAR_LECTURA',
  'VER_HISTORIAL_PROPIO',
] as const;
export type Permiso = (typeof PERMISOS)[number];

/**
 * Alcance de un permiso para un rol:
 *   TODO         — sobre cualquier recurso
 *   PROPIO       — solo sobre lo que el propio sujeto creó
 *   CONDICIONADO — depende de una autorización fina del coordinador
 *   NINGUNO      — denegado
 */
export type Alcance = 'TODO' | 'PROPIO' | 'CONDICIONADO' | 'NINGUNO';

const T: Alcance = 'TODO';
const P: Alcance = 'PROPIO';
const C: Alcance = 'CONDICIONADO';
const N: Alcance = 'NINGUNO';

/** Traducción literal de la tabla del documento 01, sección 2.2. */
const MATRIZ: Readonly<Record<Permiso, Readonly<Record<Rol, Alcance>>>> = {
  //                          COORDINADOR  ADMINISTRADORA  CATEDRATICO  AUDITOR
  CREAR_AVISO_INFORMATIVO: { COORDINADOR: T, ADMINISTRADORA: T, CATEDRATICO: N, AUDITOR: N },
  CREAR_ALERTA_URGENTE: { COORDINADOR: T, ADMINISTRADORA: C, CATEDRATICO: N, AUDITOR: N },
  ADJUNTAR_MULTIMEDIA: { COORDINADOR: T, ADMINISTRADORA: T, CATEDRATICO: N, AUDITOR: N },
  PROGRAMAR_ENVIO: { COORDINADOR: T, ADMINISTRADORA: T, CATEDRATICO: N, AUDITOR: N },
  CREAR_RECURRENTE: { COORDINADOR: T, ADMINISTRADORA: C, CATEDRATICO: N, AUDITOR: N },
  CANCELAR_PROGRAMACION: { COORDINADOR: T, ADMINISTRADORA: P, CATEDRATICO: N, AUDITOR: N },
  EXIGIR_CONFIRMACION: { COORDINADOR: T, ADMINISTRADORA: T, CATEDRATICO: N, AUDITOR: N },
  VER_REPORTE_ENTREGAS: { COORDINADOR: T, ADMINISTRADORA: P, CATEDRATICO: N, AUDITOR: T },
  VER_BITACORA_COMPLETA: { COORDINADOR: T, ADMINISTRADORA: N, CATEDRATICO: N, AUDITOR: T },
  ADMINISTRAR_USUARIOS: { COORDINADOR: T, ADMINISTRADORA: N, CATEDRATICO: N, AUDITOR: N },
  ADMINISTRAR_GRUPOS: { COORDINADOR: T, ADMINISTRADORA: T, CATEDRATICO: N, AUDITOR: N },
  CONFIRMAR_LECTURA: { COORDINADOR: T, ADMINISTRADORA: T, CATEDRATICO: T, AUDITOR: N },
  VER_HISTORIAL_PROPIO: { COORDINADOR: T, ADMINISTRADORA: T, CATEDRATICO: T, AUDITOR: N },
};

/** Qué autorización fina gobierna cada permiso CONDICIONADO. */
const AUTORIZACION_FINA: Partial<Record<Permiso, keyof Sujeto>> = {
  CREAR_ALERTA_URGENTE: 'puedeEmitirUrgentes',
  CREAR_RECURRENTE: 'puedeCrearRecurrentes',
};

/**
 * ¿Esta persona RECIBE avisos?
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Recibir y emitir son dos ejes distintos, no dos casillas del mismo rol.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * «Qué puedes hacer en el sistema» lo dice el rol. «Si eres destinatario de
 * los avisos» lo dice tu situación en la sede, y no siempre coinciden: un
 * catedrático a quien se nombra administrador académico para que pueda emitir
 * sigue dando clases, y tiene que enterarse de una evacuación como el resto.
 *
 * Atarlo al rol obligaba a esa persona a tener DOS cuentas, y eso rompe lo que
 * sostiene todo el sistema: que una persona sea una cuenta. La bitácora
 * registraría dos identidades para un mismo humano y la confirmación de
 * lectura la firmaría la cuenta que recibe, no la que trabaja.
 *
 * Por eso hay una bandera por persona, que el coordinador enciende, con el rol
 * como valor por omisión. Es la misma forma que `puedeEmitirUrgentes`.
 */
export function recibeAvisos(rol: Rol, banderaFina?: boolean): boolean {
  // Si el coordinador se pronunció sobre esta persona, manda su decisión.
  if (typeof banderaFina === 'boolean') {
    return banderaFina;
  }
  return recibePorOmision(rol);
}

/**
 * Valor por omisión de la bandera, según el rol.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Que exista un valor por omisión es lo que evita migrar datos.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Los perfiles ya creados no tienen el campo, y no hace falta tocarlos: la
 * ausencia significa «lo que diga tu rol», que es exactamente cómo se comportó
 * el sistema hasta ahora. El coordinador solo toca las excepciones.
 *
 * Si el valor por omisión fuese `true` para todos, el primer envío llegaría a
 * la auditoría sin que nadie lo hubiera pedido.
 */
export function recibePorOmision(rol: Rol): boolean {
  return rol === 'CATEDRATICO';
}

/** Lo mínimo que hay que saber de quien pide hacer algo. */
export interface Sujeto {
  readonly uid: string;
  readonly rol: Rol;
  readonly activo: boolean;
  readonly puedeEmitirUrgentes?: boolean;
  readonly puedeCrearRecurrentes?: boolean;
}

/** Recurso sobre el que se actúa, cuando el permiso distingue «lo propio». */
export interface RecursoConDueno {
  readonly creadoPor: string;
}

export function alcanceDe(rol: Rol, permiso: Permiso): Alcance {
  return MATRIZ[permiso]?.[rol] ?? 'NINGUNO';
}

/**
 * ¿Puede este sujeto ejercer este permiso sobre este recurso?
 *
 * Un usuario desactivado no puede nada, ni siquiera lo que su rol permitiría:
 * conserva su historial, pero deja de operar (RN-10).
 */
export function puede(sujeto: Sujeto, permiso: Permiso, recurso?: RecursoConDueno): boolean {
  if (!sujeto.activo) {
    return false;
  }

  switch (alcanceDe(sujeto.rol, permiso)) {
    case 'TODO':
      return true;

    case 'PROPIO':
      return recurso !== undefined && recurso.creadoPor === sujeto.uid;

    case 'CONDICIONADO': {
      const bandera = AUTORIZACION_FINA[permiso];
      return bandera !== undefined && sujeto[bandera] === true;
    }

    case 'NINGUNO':
      return false;

    /* istanbul ignore next — la unión de Alcance está cubierta arriba */
    default:
      return false;
  }
}

/** Igual que {@link puede}, pero lanza en lugar de devolver `false`. */
export function exigirPermiso(sujeto: Sujeto, permiso: Permiso, recurso?: RecursoConDueno): void {
  if (!puede(sujeto, permiso, recurso)) {
    throw new ErrorAutorizacion(
      'PERMISO_DENEGADO',
      `El rol ${sujeto.rol} no puede ejercer ${permiso} sobre este recurso.`,
      { uid: sujeto.uid, rol: sujeto.rol, permiso, activo: sujeto.activo },
    );
  }
}
