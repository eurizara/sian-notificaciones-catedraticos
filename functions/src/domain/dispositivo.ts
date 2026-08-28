/**
 * SIAN — Dispositivos de un usuario (RF-USR-09, RF-USR-10).
 *
 * Un dispositivo es una pareja: quién eres y por dónde te llega el aviso. Sin
 * al menos uno registrado, un catedrático no puede recibir nada (RN-02), y esa
 * es la razón de que el registro sea un acto explícito con su asiento en
 * bitácora y no un efecto colateral de abrir la aplicación.
 *
 * Los dispositivos viven como **subcolección** y no como arreglo dentro del
 * usuario: un arreglo obligaría a reescribir el documento entero en cada
 * refresco de token y generaría contención (documento 05, sección 2.2).
 */

import { ErrorValidacion } from './errores';

export const PLATAFORMAS = ['WEB_ANDROID', 'WEB_IOS', 'WEB_ESCRITORIO'] as const;
export type Plataforma = (typeof PLATAFORMAS)[number];

export const PERMISOS_NOTIFICACION = ['concedido', 'denegado', 'pendiente'] as const;
export type PermisoNotificacion = (typeof PERMISOS_NOTIFICACION)[number];

export interface Dispositivo {
  /** Identificador de registro de Firebase Cloud Messaging. */
  readonly tokenFCM: string;
  readonly plataforma: Plataforma;
  /**
   * Crítico en iOS: sin la PWA instalada en la pantalla de inicio **no llega
   * ninguna notificación** (RES-05). Se guarda para poder distinguir «no le
   * llegó» de «nunca pudo llegarle».
   */
  readonly esPWAInstalada: boolean;
  readonly navegador: string;
  readonly permisoNotificacion: PermisoNotificacion;
  readonly activo: boolean;
}

export interface EntradaDispositivo {
  readonly tokenFCM: string;
  readonly plataforma: string;
  readonly esPWAInstalada?: boolean;
  readonly navegador?: string;
  readonly permisoNotificacion?: string;
}

/** Longitud mínima plausible de un token de FCM. */
const LONGITUD_MINIMA_TOKEN = 20;

export function crearDispositivo(entrada: EntradaDispositivo): Dispositivo {
  const token = (entrada.tokenFCM ?? '').trim();

  if (token.length < LONGITUD_MINIMA_TOKEN) {
    throw new ErrorValidacion(
      'TOKEN_FCM_INVALIDO',
      'El identificador de notificación no tiene forma válida.',
      { longitud: token.length },
    );
  }

  const plataforma = (entrada.plataforma ?? '').trim().toUpperCase() as Plataforma;
  if (!PLATAFORMAS.includes(plataforma)) {
    throw new ErrorValidacion(
      'PLATAFORMA_INVALIDA',
      `Plataforma desconocida: «${entrada.plataforma}». Se espera ${PLATAFORMAS.join(', ')}.`,
    );
  }

  const permiso = (entrada.permisoNotificacion ?? 'pendiente') as PermisoNotificacion;
  if (!PERMISOS_NOTIFICACION.includes(permiso)) {
    throw new ErrorValidacion(
      'PERMISO_INVALIDO',
      `Estado de permiso desconocido: «${entrada.permisoNotificacion}».`,
    );
  }

  return Object.freeze({
    tokenFCM: token,
    plataforma,
    esPWAInstalada: entrada.esPWAInstalada === true,
    navegador: (entrada.navegador ?? '').trim().slice(0, 120),
    permisoNotificacion: permiso,
    activo: permiso === 'concedido',
  });
}

/**
 * ¿Este dispositivo puede recibir notificaciones de verdad?
 *
 * En iOS la respuesta es «solo si la PWA está instalada en la pantalla de
 * inicio». Es la restricción RES-05, y la que convierte al instructivo de
 * instalación en parte del producto y no en un detalle de ayuda.
 */
export function puedeRecibirNotificaciones(d: Dispositivo): boolean {
  if (d.permisoNotificacion !== 'concedido') {
    return false;
  }
  if (d.plataforma === 'WEB_IOS') {
    return d.esPWAInstalada;
  }
  return true;
}

/**
 * Motivo por el que un dispositivo no puede recibir, en lenguaje llano.
 *
 * Devuelve `null` cuando sí puede. Existe para que la interfaz no tenga que
 * reconstruir el razonamiento y para que el emisor entienda, al ver el reporte
 * de entregas, por qué a alguien no le llegó nada.
 */
export function motivoPorElQueNoRecibe(d: Dispositivo): string | null {
  if (d.permisoNotificacion === 'denegado') {
    return 'PERMISO_DENEGADO';
  }
  if (d.permisoNotificacion === 'pendiente') {
    return 'PERMISO_NO_CONCEDIDO';
  }
  if (d.plataforma === 'WEB_IOS' && !d.esPWAInstalada) {
    return 'IOS_SIN_INSTALAR';
  }
  return null;
}

/**
 * ¿Este error del servicio de push significa que el token ya no sirve?
 *
 * ────────────────────────────────────────────────────────────────────────────
 * Solo dos códigos son definitivos. Todos los demás son tropiezos.
 * ────────────────────────────────────────────────────────────────────────────
 *
 * Distinguirlos importa en las dos direcciones, y equivocarse duele distinto:
 *
 *   · Si se da por muerto un token que no lo está —por un fallo de red, una
 *     cuota agotada, un servicio caído—, se borra el registro de alguien que
 *     estaba perfectamente bien, y esa persona **deja de recibir avisos** hasta
 *     que vuelva a abrir la aplicación. Puede no notarlo en semanas.
 *
 *   · Si se da por vivo un token muerto, se queda para siempre, se le sigue
 *     enviando y cada aviso cuenta como fallo. Es lo que pasaba: una persona
 *     con nueve tokens muertos aparecía como no localizable teniendo la
 *     aplicación instalada y el permiso concedido.
 *
 * Ante la duda, no se borra: recuperar un token perdido exige que la persona
 * abra la aplicación, y conservar uno muerto solo cuesta un intento fallido.
 */
export function esTokenMuerto(codigo: string | undefined): boolean {
  return (
    codigo === 'messaging/registration-token-not-registered' ||
    codigo === 'messaging/invalid-registration-token'
  );
}
