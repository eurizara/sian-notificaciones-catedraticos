/**
 * SIAN — Functions de administración: invitaciones, usuarios y grupos.
 *
 * Todas comparten la misma disciplina, que es la del patrón Command auditable
 * del documento 02, sección 3:
 *
 *   1. Comprobar el permiso **en el servidor**, contra los custom claims. La
 *      interfaz ya oculta lo que no corresponde, pero ocultar no es impedir
 *      (RN-01).
 *   2. Validar con el dominio.
 *   3. Aplicar el efecto.
 *   4. Dejar asiento en bitácora, sin excepción (RNF-17).
 */

import { HttpsError, onCall, type CallableRequest } from 'firebase-functions/v2/https';

import { crearAsiento, type Actor, type TipoEvento } from '../domain/bitacora';
import { ErrorDominio } from '../domain/errores';
import { crearGrupo, normalizarMiembros, rozaElLimite } from '../domain/grupo';
import { crearInvitacion, interpretarCsv } from '../domain/invitacion';
import { exigirPermiso, type Permiso } from '../domain/autorizacion';
import { ROLES, type Rol } from '../domain/tipos';
import { FieldValue, OPCIONES_FUNCION, RUTAS, auth, db } from '../infrastructure/firebase';
import {
  actualizarPerfil,
  buscarPerfil,
  eliminarInvitacion,
  escribirAsiento,
  escribirAsientos,
  guardarInvitaciones,
} from '../infrastructure/repositorios';

// ---------------------------------------------------------------------------
// Comprobación de permisos, del lado del servidor
// ---------------------------------------------------------------------------

interface Solicitante {
  readonly actor: Actor;
  readonly rol: Rol;
}

/**
 * Verifica que quien llama esté autenticado, activo y tenga el permiso.
 *
 * Lee el rol de los **custom claims**, no de lo que mande el cliente: el
 * cliente puede decir lo que quiera, el token lo firma el servidor.
 */
async function exigir(
  peticion: CallableRequest,
  permiso: Permiso,
): Promise<Solicitante> {
  if (!peticion.auth) {
    throw new HttpsError('unauthenticated', 'Hay que iniciar sesión.');
  }

  const uid = peticion.auth.uid;
  const rol = peticion.auth.token.rol as Rol | undefined;
  const activo = peticion.auth.token.activo === true;
  const correo = (peticion.auth.token.email as string | undefined) ?? '';

  if (!rol || !ROLES.includes(rol)) {
    throw new HttpsError('permission-denied', 'Tu sesión no tiene un rol asignado.');
  }

  try {
    exigirPermiso(
      {
        uid,
        rol,
        activo,
        puedeEmitirUrgentes: peticion.auth.token.puedeEmitirUrgentes === true,
        puedeCrearRecurrentes: peticion.auth.token.puedeCrearRecurrentes === true,
      },
      permiso,
    );
  } catch (e) {
    throw new HttpsError(
      'permission-denied',
      e instanceof ErrorDominio ? e.message : 'No tienes permiso para esta operación.',
    );
  }

  return { actor: { uid, correo, rol }, rol };
}

/** Traduce un error del dominio a algo que el cliente pueda mostrar. */
function comoHttps(e: unknown): HttpsError {
  if (e instanceof HttpsError) {
    return e;
  }
  if (e instanceof ErrorDominio) {
    return new HttpsError('invalid-argument', e.message, { codigo: e.codigo });
  }
  return new HttpsError('internal', 'Ocurrió un error inesperado.');
}

function asiento(
  tipo: TipoEvento,
  solicitante: Solicitante,
  entidad: 'USUARIO' | 'GRUPO' | 'INVITACION',
  entidadId: string,
  resumen: string,
  datos: Record<string, unknown> = {},
) {
  return crearAsiento({
    tipo,
    actor: solicitante.actor,
    entidad,
    entidadId,
    resumen,
    datos,
    origen: 'PANEL_WEB',
  });
}

// ---------------------------------------------------------------------------
// Invitaciones — RF-USR-01, RF-AUT-03
// ---------------------------------------------------------------------------

export const crearInvitaciones = onCall(OPCIONES_FUNCION, async (peticion) => {
  const solicitante = await exigir(peticion, 'ADMINISTRAR_USUARIOS');

  try {
    const datos = peticion.data as {
      correo?: string;
      rol?: string;
      nombre?: string;
      csv?: string;
    };

    // Dos formas de entrada, un solo camino de validación: una invitación
    // suelta es una carga masiva de una línea.
    if (typeof datos.csv === 'string' && datos.csv.trim().length > 0) {
      const resultado = interpretarCsv(datos.csv, solicitante.actor.uid);
      await guardarInvitaciones(resultado.validas);
      await escribirAsientos(
        resultado.validas.map((i) =>
          asiento(
            'INVITACION_CREADA',
            solicitante,
            'INVITACION',
            i.correo,
            `Invitación por carga masiva: ${i.correo} como ${i.rolAsignado}`,
            { rolAsignado: i.rolAsignado, origenCarga: 'CSV' },
          ),
        ),
      );

      return {
        creadas: resultado.validas.length,
        rechazadas: resultado.rechazadas,
      };
    }

    const invitacion = crearInvitacion({
      correo: datos.correo ?? '',
      rolAsignado: datos.rol ?? '',
      nombre: datos.nombre ?? '',
      creadaPor: solicitante.actor.uid,
    });

    await guardarInvitaciones([invitacion]);
    await escribirAsiento(
      asiento(
        'INVITACION_CREADA',
        solicitante,
        'INVITACION',
        invitacion.correo,
        `Invitación creada para ${invitacion.correo} como ${invitacion.rolAsignado}`,
        { rolAsignado: invitacion.rolAsignado },
      ),
    );

    return { creadas: 1, rechazadas: [] };
  } catch (e) {
    throw comoHttps(e);
  }
});

export const revocarInvitacion = onCall(OPCIONES_FUNCION, async (peticion) => {
  const solicitante = await exigir(peticion, 'ADMINISTRAR_USUARIOS');
  const correo = String((peticion.data as { correo?: string }).correo ?? '')
    .trim()
    .toLowerCase();

  if (!correo) {
    throw new HttpsError('invalid-argument', 'Falta el correo de la invitación.');
  }

  await eliminarInvitacion(correo);
  await escribirAsiento(
    asiento(
      'INVITACION_ELIMINADA',
      solicitante,
      'INVITACION',
      correo,
      `Invitación revocada para ${correo}`,
    ),
  );

  return { revocada: correo };
});

// ---------------------------------------------------------------------------
// Usuarios — RF-USR-02, RF-AUT-08, RN-10
// ---------------------------------------------------------------------------

export const cambiarRol = onCall(OPCIONES_FUNCION, async (peticion) => {
  const solicitante = await exigir(peticion, 'ADMINISTRAR_USUARIOS');
  const { uid, rol } = peticion.data as { uid?: string; rol?: string };

  const nuevoRol = String(rol ?? '').toUpperCase() as Rol;
  if (!uid || !ROLES.includes(nuevoRol)) {
    throw new HttpsError('invalid-argument', 'Hace falta el usuario y un rol válido.');
  }

  const perfil = await buscarPerfil(uid);
  if (!perfil) {
    throw new HttpsError('not-found', 'Ese usuario no existe.');
  }
  if (uid === solicitante.actor.uid) {
    // Quitarse a uno mismo el rol de coordinador dejaría el sistema sin nadie
    // que pueda administrarlo.
    throw new HttpsError('failed-precondition', 'No puedes cambiar tu propio rol.');
  }

  await actualizarPerfil(uid, { rol: nuevoRol });
  await auth.setCustomUserClaims(uid, {
    rol: nuevoRol,
    activo: perfil.activo,
    puedeEmitirUrgentes: perfil.puedeEmitirUrgentes,
    puedeCrearRecurrentes: perfil.puedeCrearRecurrentes,
  });
  await escribirAsiento(
    asiento(
      'USUARIO_ROL_CAMBIADO',
      solicitante,
      'USUARIO',
      uid,
      `Rol de ${perfil.correo}: ${perfil.rol} → ${nuevoRol}`,
      { rolAnterior: perfil.rol, rolNuevo: nuevoRol },
    ),
  );

  return { uid, rol: nuevoRol };
});

export const cambiarEstadoUsuario = onCall(OPCIONES_FUNCION, async (peticion) => {
  const solicitante = await exigir(peticion, 'ADMINISTRAR_USUARIOS');
  const { uid, activo } = peticion.data as { uid?: string; activo?: boolean };

  if (!uid || typeof activo !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Hace falta el usuario y el estado.');
  }
  if (uid === solicitante.actor.uid) {
    throw new HttpsError('failed-precondition', 'No puedes desactivar tu propia cuenta.');
  }

  const perfil = await buscarPerfil(uid);
  if (!perfil) {
    throw new HttpsError('not-found', 'Ese usuario no existe.');
  }

  // RN-10: se desactiva, no se borra. El historial queda íntegro.
  await actualizarPerfil(uid, { activo });
  await auth.setCustomUserClaims(uid, {
    rol: perfil.rol,
    activo,
    puedeEmitirUrgentes: perfil.puedeEmitirUrgentes,
    puedeCrearRecurrentes: perfil.puedeCrearRecurrentes,
  });
  // Revocar los tokens hace efectiva la desactivación de inmediato; sin esto
  // el usuario seguiría operando hasta que su token caducara, hasta una hora.
  await auth.revokeRefreshTokens(uid);

  await escribirAsiento(
    asiento(
      activo ? 'USUARIO_REACTIVADO' : 'USUARIO_DESACTIVADO',
      solicitante,
      'USUARIO',
      uid,
      `${activo ? 'Reactivación' : 'Desactivación'} de ${perfil.correo}`,
      { correo: perfil.correo },
    ),
  );

  return { uid, activo };
});

export const cambiarAutorizacionesFinas = onCall(OPCIONES_FUNCION, async (peticion) => {
  const solicitante = await exigir(peticion, 'ADMINISTRAR_USUARIOS');
  const { uid, puedeEmitirUrgentes, puedeCrearRecurrentes } = peticion.data as {
    uid?: string;
    puedeEmitirUrgentes?: boolean;
    puedeCrearRecurrentes?: boolean;
  };

  if (!uid) {
    throw new HttpsError('invalid-argument', 'Falta el usuario.');
  }

  const perfil = await buscarPerfil(uid);
  if (!perfil) {
    throw new HttpsError('not-found', 'Ese usuario no existe.');
  }

  const urgentes = puedeEmitirUrgentes ?? perfil.puedeEmitirUrgentes;
  const recurrentes = puedeCrearRecurrentes ?? perfil.puedeCrearRecurrentes;

  await actualizarPerfil(uid, {
    puedeEmitirUrgentes: urgentes,
    puedeCrearRecurrentes: recurrentes,
  });
  await auth.setCustomUserClaims(uid, {
    rol: perfil.rol,
    activo: perfil.activo,
    puedeEmitirUrgentes: urgentes,
    puedeCrearRecurrentes: recurrentes,
  });
  await escribirAsiento(
    asiento(
      'USUARIO_ROL_CAMBIADO',
      solicitante,
      'USUARIO',
      uid,
      `Autorizaciones finas de ${perfil.correo}: urgentes=${urgentes}, recurrentes=${recurrentes}`,
      { puedeEmitirUrgentes: urgentes, puedeCrearRecurrentes: recurrentes },
    ),
  );

  return { uid, puedeEmitirUrgentes: urgentes, puedeCrearRecurrentes: recurrentes };
});

// ---------------------------------------------------------------------------
// Grupos — RF-USR-03, RF-USR-04, DT-08
// ---------------------------------------------------------------------------

export const guardarGrupo = onCall(OPCIONES_FUNCION, async (peticion) => {
  const solicitante = await exigir(peticion, 'ADMINISTRAR_GRUPOS');
  const { grupoId, nombre, descripcion, miembros } = peticion.data as {
    grupoId?: string;
    nombre?: string;
    descripcion?: string;
    miembros?: string[];
  };

  try {
    const grupo = crearGrupo({
      nombre: nombre ?? '',
      descripcion: descripcion ?? '',
      miembros: normalizarMiembros(miembros ?? []),
      creadoPor: solicitante.actor.uid,
    });

    const ref = grupoId
      ? db.collection(RUTAS.grupos).doc(grupoId)
      : db.collection(RUTAS.grupos).doc();

    await ref.set(
      {
        nombre: grupo.nombre,
        descripcion: grupo.descripcion,
        miembros: grupo.miembros,
        totalMiembros: grupo.totalMiembros,
        creadoPor: grupo.creadoPor,
        activo: grupo.activo,
        ...(grupoId ? {} : { creadoEn: FieldValue.serverTimestamp() }),
        actualizadoEn: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    await escribirAsiento(
      asiento(
        grupoId ? 'GRUPO_MODIFICADO' : 'GRUPO_CREADO',
        solicitante,
        'GRUPO',
        ref.id,
        `${grupoId ? 'Modificación' : 'Creación'} del grupo «${grupo.nombre}» con ${grupo.totalMiembros} miembros`,
        { totalMiembros: grupo.totalMiembros },
      ),
    );

    return {
      grupoId: ref.id,
      totalMiembros: grupo.totalMiembros,
      // Aviso temprano de DT-08: llegar a 200 y descubrirlo el día que hace
      // falta agregar a alguien es peor que saberlo con margen.
      rozaElLimite: rozaElLimite(grupo.totalMiembros),
    };
  } catch (e) {
    throw comoHttps(e);
  }
});
