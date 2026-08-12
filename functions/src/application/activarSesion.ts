/**
 * SIAN — Alta y verificación de sesión contra la lista blanca (RF-AUT-03).
 *
 * Criterio de aceptación literal del documento 01:
 *
 *   «Un usuario con correo no incluido en la lista de autorizados que complete
 *    correctamente el flujo de Google recibe un rechazo explicativo, no se le
 *    crea perfil, y el intento queda registrado en la bitácora.»
 *
 * Las tres condiciones se deciden aquí, en una función **pura**: recibe lo que
 * dice la base de datos y devuelve qué hay que hacer, sin tocar nada. Los
 * efectos —crear el perfil, sembrar los claims, borrar la credencial huérfana,
 * escribir el asiento— los aplica el disparador.
 *
 * Separarlo así es lo que permite probar los seis caminos posibles sin
 * levantar un emulador, y es la razón de que la regla más delicada del sistema
 * tenga cobertura real en lugar de una prueba de humo.
 */

import {
  crearAsiento,
  type Actor,
  type AsientoBitacora,
} from '../domain/bitacora';
import { CorreoInstitucional } from '../domain/objetosDeValor';
import { recibeAvisos } from '../domain/autorizacion';
import type { Invitacion } from '../domain/invitacion';
import type { Rol } from '../domain/tipos';

/** Perfil tal como vive en `usuarios/{uid}` (documento 05, sección 2.1). */
export interface PerfilUsuario {
  /** Decisión del coordinador. Ausente = lo que diga el rol. */
  readonly recibeAvisos?: boolean;
  readonly uid: string;
  readonly correo: string;
  readonly nombre: string;
  readonly rol: Rol;
  readonly activo: boolean;
  readonly proveedorAuth: string;
  readonly puedeEmitirUrgentes: boolean;
  readonly puedeCrearRecurrentes: boolean;
  readonly zonaHoraria: string;
}

/** Custom claims que se siembran en el token (documento 02, sección 11). */
export interface ClaimsUsuario {
  readonly rol: Rol;
  readonly activo: boolean;
  readonly puedeEmitirUrgentes: boolean;
  readonly puedeCrearRecurrentes: boolean;
  /**
   * Si esta persona recibe avisos, según decidió el coordinador.
   *
   * Viaja en el token para que la aplicación pueda enseñarle su bandeja sin
   * preguntar a nadie. La decisión de a quién se le entrega sigue tomándose en
   * el servidor: esto es solo para pintar la pantalla (RN-01).
   */
  readonly recibeAvisos: boolean;
}

export type MotivoRechazo = 'FUERA_DE_LISTA_BLANCA' | 'CUENTA_DESACTIVADA';

export interface SolicitudActivacion {
  readonly uid: string;
  readonly correo: string;
  /** `google.com` o `password`. */
  readonly proveedorAuth: string;
  /** Nombre que trae el proveedor de identidad, si trae alguno. */
  readonly nombreDelProveedor?: string;
  /** Invitación encontrada en la lista blanca, o `null` si no hay. */
  readonly invitacion: Invitacion | null;
  /** Perfil existente, o `null` si es el primer acceso. */
  readonly perfilExistente: PerfilUsuario | null;
  readonly zonaHorariaInstitucional: string;
  readonly ahora?: Date;
}

export type ResultadoActivacion =
  | {
      readonly tipo: 'PERFIL_CREADO';
      readonly perfil: PerfilUsuario;
      readonly claims: ClaimsUsuario;
      readonly asiento: AsientoBitacora;
      /** La invitación pasa a consumida. */
      readonly invitacionConsumida: string;
    }
  | {
      readonly tipo: 'SESION_ACEPTADA';
      readonly perfil: PerfilUsuario;
      readonly claims: ClaimsUsuario;
      readonly asiento: AsientoBitacora;
    }
  | {
      readonly tipo: 'RECHAZADO';
      readonly motivo: MotivoRechazo;
      readonly asiento: AsientoBitacora;
      /**
       * Si es `true`, hay que borrar la credencial recién creada en el
       * proveedor de identidad.
       *
       * Sin esto quedaría una cuenta huérfana: autenticable, sin perfil y sin
       * rol, que volvería a intentarlo indefinidamente. El criterio de
       * aceptación dice «no se le crea perfil», y dejar la credencial suelta
       * cumple la letra pero no la intención.
       */
      readonly borrarCredencial: boolean;
    };

/** Claims derivados de un perfil. Una sola fuente, para que no diverjan. */
export function claimsDe(perfil: PerfilUsuario): ClaimsUsuario {
  return {
    rol: perfil.rol,
    activo: perfil.activo,
    puedeEmitirUrgentes: perfil.puedeEmitirUrgentes,
    puedeCrearRecurrentes: perfil.puedeCrearRecurrentes,
    recibeAvisos: recibeAvisos(perfil.rol, perfil.recibeAvisos),
  };
}

/**
 * Decide qué ocurre cuando alguien se autentica.
 *
 * Los seis caminos posibles:
 *
 *   1. Perfil existente y activo          → se acepta y se refrescan claims
 *   2. Perfil existente pero desactivado  → rechazo, sin borrar credencial
 *   3. Sin perfil, con invitación válida  → se crea el perfil
 *   4. Sin perfil, sin invitación         → rechazo y credencial borrada
 *   5. Sin perfil, invitación ya consumida por OTRO uid → rechazo
 *   6. Correo con forma inválida          → rechazo
 */
export function decidirActivacion(solicitud: SolicitudActivacion): ResultadoActivacion {
  const ahora = solicitud.ahora ?? new Date();

  // El correo se normaliza igual que la clave de la lista blanca; si no tiene
  // forma válida no puede coincidir con nada.
  let correo: string;
  try {
    correo = CorreoInstitucional.crear(solicitud.correo).valor;
  } catch {
    return rechazo({
      motivo: 'FUERA_DE_LISTA_BLANCA',
      uid: solicitud.uid,
      correo: solicitud.correo ?? '',
      resumen: 'Intento de acceso con un correo de forma inválida',
      ahora,
      borrarCredencial: true,
    });
  }

  const actor: Actor = { uid: solicitud.uid, correo, rol: 'CATEDRATICO' };

  // --- Camino 1 y 2: ya tiene perfil --------------------------------------
  if (solicitud.perfilExistente) {
    const perfil = solicitud.perfilExistente;

    if (!perfil.activo) {
      return rechazo({
        motivo: 'CUENTA_DESACTIVADA',
        uid: solicitud.uid,
        correo,
        rol: perfil.rol,
        resumen: 'Intento de acceso con una cuenta desactivada',
        ahora,
        // La credencial NO se borra: RN-10 dice que un usuario desactivado
        // conserva su historial y puede reactivarse.
        borrarCredencial: false,
      });
    }

    return {
      tipo: 'SESION_ACEPTADA',
      perfil,
      claims: claimsDe(perfil),
      asiento: crearAsiento({
        tipo: 'SESION_INICIADA',
        actor: { ...actor, rol: perfil.rol },
        entidad: 'SESION',
        entidadId: solicitud.uid,
        resumen: `${correo} inició sesión como ${perfil.rol}`,
        datos: { proveedorAuth: solicitud.proveedorAuth },
        ocurridoEn: ahora,
      }),
    };
  }

  // --- Caminos 4, 5 y 6: primer acceso sin invitación utilizable ----------
  const invitacion = solicitud.invitacion;

  if (!invitacion) {
    return rechazo({
      motivo: 'FUERA_DE_LISTA_BLANCA',
      uid: solicitud.uid,
      correo,
      resumen: `Acceso rechazado: ${correo} no está en la lista blanca institucional`,
      ahora,
      borrarCredencial: true,
      datos: { proveedorAuth: solicitud.proveedorAuth },
    });
  }

  if (invitacion.consumida && invitacion.consumidaPor !== solicitud.uid) {
    // Alguien ya usó esa invitación con otra credencial. Reutilizarla dejaría
    // dos cuentas para un mismo correo institucional.
    return rechazo({
      motivo: 'FUERA_DE_LISTA_BLANCA',
      uid: solicitud.uid,
      correo,
      resumen: `Acceso rechazado: la invitación de ${correo} ya fue consumida por otra cuenta`,
      ahora,
      borrarCredencial: true,
      datos: { consumidaPor: invitacion.consumidaPor ?? '' },
    });
  }

  // --- Camino 3: alta legítima --------------------------------------------
  const perfil: PerfilUsuario = {
    uid: solicitud.uid,
    correo,
    nombre: invitacion.nombre || solicitud.nombreDelProveedor?.trim() || correo,
    rol: invitacion.rolAsignado,
    activo: true,
    proveedorAuth: solicitud.proveedorAuth,
    // El coordinador concede estas autorizaciones finas después, desde el
    // panel: nadie nace pudiendo emitir alertas urgentes.
    puedeEmitirUrgentes: false,
    puedeCrearRecurrentes: false,
    zonaHoraria: solicitud.zonaHorariaInstitucional,
  };

  return {
    tipo: 'PERFIL_CREADO',
    perfil,
    claims: claimsDe(perfil),
    invitacionConsumida: correo,
    asiento: crearAsiento({
      tipo: 'USUARIO_CREADO',
      actor: { ...actor, rol: perfil.rol },
      entidad: 'USUARIO',
      entidadId: solicitud.uid,
      resumen: `Alta de ${correo} como ${perfil.rol} a partir de su invitación`,
      datos: {
        proveedorAuth: solicitud.proveedorAuth,
        invitacionCreadaPor: invitacion.creadaPor,
      },
      ocurridoEn: ahora,
    }),
  };
}

function rechazo(args: {
  motivo: MotivoRechazo;
  uid: string;
  correo: string;
  rol?: Rol;
  resumen: string;
  ahora: Date;
  borrarCredencial: boolean;
  datos?: Record<string, unknown>;
}): ResultadoActivacion {
  return {
    tipo: 'RECHAZADO',
    motivo: args.motivo,
    borrarCredencial: args.borrarCredencial,
    asiento: crearAsiento({
      tipo: 'SESION_RECHAZADA',
      actor: { uid: args.uid, correo: args.correo, rol: args.rol ?? 'CATEDRATICO' },
      entidad: 'SESION',
      entidadId: args.uid,
      resumen: args.resumen,
      datos: { motivo: args.motivo, ...(args.datos ?? {}) },
      ocurridoEn: args.ahora,
    }),
  };
}
