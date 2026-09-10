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

/** Prefijo con el que la aplicación nombra sus identificadores de instalación. */
export const PREFIJO_INSTALACION = 'ins_';

/**
 * ¿Esto es un identificador de instalación y no un token de notificaciones?
 *
 * Sirve para que la limpieza de tokens muertos no borre por identificador de
 * documento algo que no es un token. Sin esta distinción, un fallo aguas
 * arriba —mandar el identificador donde iba el token— convierte la limpieza en
 * un borrador de dispositivos vivos, y eso fue exactamente lo que pasó el 28 de
 * agosto de 2026: cada envío dejaba a la gente sin dispositivo, y reinstalar no
 * servía porque al primer envío volvía a desaparecer.
 */
export function esIdentificadorDeInstalacion(valor: string): boolean {
  return valor.startsWith(PREFIJO_INSTALACION);
}

// --- Sonda de canal y retiro por antigüedad (DT-22, DT-18) -------------------

/**
 * Días sin actividad tras los cuales un dispositivo se considera abandonado.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Sesenta, y el número está elegido, no redondeado por gusto.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Por debajo se retiraría gente que simplemente estuvo de vacaciones: la
 * aplicación se refresca sola al abrirla, y quien la abre una vez al mes nunca
 * llega a este umbral. Por encima, los registros arrastrados —71 medidos en
 * producción, algunos de agosto— seguirían ahí ensuciando el diagnóstico justo
 * cuando hay que averiguar por qué alguien no recibió.
 *
 * Retirar de más cuesta poco: la persona vuelve a registrarse sola la próxima
 * vez que abra. Es la misma asimetría que ya rige `esTokenMuerto`, pero al
 * revés, porque aquí no hay ninguna duda de que el dispositivo está en desuso.
 */
export const DIAS_PARA_RETIRO_POR_INACTIVIDAD = 60;

/** Un dispositivo, reducido a lo que la sonda necesita para decidir. */
export interface DispositivoAEvaluar {
  readonly uid: string;
  readonly id: string;
  readonly tokenFCM: string;
  readonly ultimaActividad: Date | null;
}

/** Qué hacer con un dispositivo después de mirarlo. */
export type DecisionDeSonda = 'conservar' | 'retirar-por-muerto' | 'retirar-por-inactivo';

/**
 * ¿Qué se hace con este dispositivo?
 *
 * `vivoSegunFcm` es lo que contestó el envío en seco. Se decide primero por ahí
 * porque un token que FCM rechaza no sirve por muy reciente que sea; la
 * antigüedad solo manda sobre los que siguen siendo válidos.
 */
export function decidirSobreDispositivo(
  dispositivo: DispositivoAEvaluar,
  vivoSegunFcm: boolean,
  ahora: Date,
): DecisionDeSonda {
  if (!vivoSegunFcm) {
    return 'retirar-por-muerto';
  }

  const actividad = dispositivo.ultimaActividad;
  if (actividad === null) {
    // Sin fecha de actividad no se retira nada. Un campo que falta es una
    // incógnita, no una prueba de abandono, y borrar por una incógnita es
    // exactamente lo que dejó a gente sin avisos en agosto.
    return 'conservar';
  }

  const dias = (ahora.getTime() - actividad.getTime()) / 86_400_000;
  return dias > DIAS_PARA_RETIRO_POR_INACTIVIDAD ? 'retirar-por-inactivo' : 'conservar';
}

/** Cómo está una persona respecto de poder recibir avisos. */
export type EstadoDeCanal =
  | 'al-dia'
  | 'sin-dispositivo'
  | 'token-muerto'
  | 'solo-en-pestana'
  | 'permiso-denegado'
  | 'sin-actividad-reciente';

/** Lo mínimo de un dispositivo para juzgar el canal de su dueño. */
export interface DispositivoDeCanal {
  readonly esPWAInstalada: boolean;
  readonly permisoNotificacion: string;
  readonly ultimaActividad: Date | null;

  /**
   * ¿FCM acepta todavía este token?
   *
   * ───────────────────────────────────────────────────────────────────────────
   * Sin este dato la evaluación se equivoca justo con quien peor está.
   * ───────────────────────────────────────────────────────────────────────────
   *
   * Un documento puede verse impecable —aplicación instalada, permiso
   * concedido, actividad reciente— y llevar dentro un token que FCM ya rechaza.
   * Desde Firestore es indistinguible de uno sano: la única forma de saberlo es
   * preguntárselo a FCM.
   *
   * Se vio en desarrollo el 10 de septiembre de 2026. Un coordinador con un
   * iPhone instalado y permiso concedido no recibió el aviso, y la pantalla de
   * Alcance lo daba por bien: su token estaba muerto y nada en el documento lo
   * decía.
   *
   * `undefined` significa «no se preguntó», y entonces no se penaliza: suponer
   * que está muerto sin haberlo comprobado mandaría a coordinación a buscar a
   * gente que está bien.
   */
  readonly tokenVivo?: boolean;
}

/**
 * En qué estado está el canal de una persona.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Devuelve el estado MÁS GRAVE, no el primero que encuentra.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Quien tiene un aparato instalado y otro en pestaña está al día: le va a
 * llegar. Lo que importa no es que algo esté mal en algún sitio, sino si la
 * persona puede recibir un aviso o no, y para eso basta con que uno de sus
 * dispositivos sirva.
 *
 * El orden de gravedad es el orden en que hay que buscar a la gente: primero
 * quien no puede recibir nada.
 */
export function estadoDeCanal(
  dispositivos: readonly DispositivoDeCanal[],
  ahora: Date,
  diasParaAvisar = 30,
): EstadoDeCanal {
  if (dispositivos.length === 0) {
    return 'sin-dispositivo';
  }

  // Un token que FCM rechaza no sirve por muy bien que se vea el resto del
  // documento. Se descarta ANTES de mirar nada más, porque lo demás describe
  // condiciones necesarias y esto describe el hecho.
  const conCanal = dispositivos.filter((d) => d.tokenVivo !== false);

  if (conCanal.length === 0) {
    return 'token-muerto';
  }

  const utiles = conCanal.filter(
    (d) => d.esPWAInstalada && d.permisoNotificacion === 'concedido',
  );

  if (utiles.length === 0) {
    // Se distingue el motivo porque lo que hay que pedirle a la persona es
    // distinto: instalar la aplicación, o volver a conceder el permiso.
    return conCanal.some((d) => d.permisoNotificacion === 'denegado')
      ? 'permiso-denegado'
      : 'solo-en-pestana';
  }

  const masReciente = utiles
    .map((d) => d.ultimaActividad)
    .filter((f): f is Date => f !== null)
    .sort((a, b) => b.getTime() - a.getTime())[0];

  if (masReciente === undefined) {
    return 'al-dia';
  }

  const dias = (ahora.getTime() - masReciente.getTime()) / 86_400_000;
  return dias > diasParaAvisar ? 'sin-actividad-reciente' : 'al-dia';
}

/** Orden en que conviene buscar a la gente: primero quien no recibe nada. */
export const GRAVEDAD_DE_CANAL: Record<EstadoDeCanal, number> = {
  // Los dos primeros comparten consecuencia —no reciben nada— y por eso van
  // juntos arriba. Lo que cambia entre ellos es qué hay que pedirle a la
  // persona, no la urgencia.
  'sin-dispositivo': 0,
  'token-muerto': 1,
  'permiso-denegado': 2,
  'solo-en-pestana': 3,
  'sin-actividad-reciente': 4,
  'al-dia': 5,
};
