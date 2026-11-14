/**
 * SIAN — Functions de administración: invitaciones, usuarios y grupos.
 *
 * Todas comparten la misma disciplina, que es la del patrón Command auditable
 * del documento 02, sección 4:
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
import { crearInvitacion, interpretarCsv, type Invitacion } from '../domain/invitacion';
import { exigirPermiso, type Permiso , recibeAvisos } from '../domain/autorizacion';
import { ROLES, type Rol } from '../domain/tipos';
import { claimsDe, type PerfilUsuario } from '../application/activarSesion';
import {
  SEDE_INICIAL,
  conFacultadesEnSede,
  conRolEnSede,
  esIdDeFacultad,
  exigirMiembrosEnLugar,
  membresiasDe,
  miembrosFueraDeLugar,
  perteneceASede,
  rolEnSede,
  sedeDelDocumento,
  sedePrincipal,
  sedesDeMembresias,
} from '../domain/sede';
import { rolDelPerfilEnSede, sedeDeLaPeticion } from '../application/sedeDeLaPeticion';
import { leerFacultades } from '../infrastructure/sedes';
import { FieldValue, OPCIONES_LLAMABLE, RUTAS, auth, db } from '../infrastructure/firebase';
import {
  actualizarPerfil,
  buscarPerfil,
  eliminarInvitacion,
  escribirAsiento,
  escribirAsientos,
  guardarInvitaciones,
  reemplazarMembresias,
} from '../infrastructure/repositorios';

// ---------------------------------------------------------------------------
// Comprobación de permisos, del lado del servidor
// ---------------------------------------------------------------------------

interface Solicitante {
  readonly actor: Actor;
  /** El rol EN la sede donde actúa (2.0). */
  readonly rol: Rol;
  /** La sede donde actúa: solo administra gente y grupos de ella (RF-SED-05). */
  readonly sedeId: string;
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
  const rolGlobal = peticion.auth.token.rol as Rol | undefined;
  const activo = peticion.auth.token.activo === true;
  const correo = (peticion.auth.token.email as string | undefined) ?? '';

  if (!rolGlobal || !ROLES.includes(rolGlobal)) {
    throw new HttpsError('permission-denied', 'Tu sesión no tiene un rol asignado.');
  }

  // El permiso se mira con el rol en la sede donde actúa (2.0).
  let sedeId: string;
  let rol: Rol;
  try {
    ({ sedeId, rol } = sedeDeLaPeticion(peticion.auth.token, (peticion.data as { sedeId?: unknown } | undefined)?.sedeId));
  } catch (e) {
    throw new HttpsError('permission-denied', e instanceof Error ? e.message : 'No se pudo decidir la sede.');
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

  return { actor: { uid, correo, rol }, rol, sedeId };
}

/**
 * Un coordinador solo administra a gente de su sede (RF-SED-05). Para quien no
 * es de ella se responde lo mismo que si no existiera: no se confirma ni que
 * esa persona exista en otra sede.
 */
function exigirDeLaSede(perfil: PerfilUsuario | null, solicitante: Solicitante): PerfilUsuario {
  if (!perfil || !perteneceASede(perfil, solicitante.sedeId)) {
    throw new HttpsError('not-found', 'Ese usuario no existe.');
  }
  return perfil;
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

export const crearInvitaciones = onCall(OPCIONES_LLAMABLE, async (peticion) => {
  const solicitante = await exigir(peticion, 'ADMINISTRAR_USUARIOS');

  try {
    const datos = peticion.data as {
      correo?: string;
      rol?: string;
      nombre?: string;
      csv?: string;
      /** 2.0.1: facultades de la sede con que entra. Opcional. */
      facultades?: unknown;
    };
    // La persona entra en la sede de quien la invita (2.0.1).
    const conSede = (i: Invitacion): Invitacion => ({ ...i, sedeId: solicitante.sedeId });

    // Dos formas de entrada, un solo camino de validación: una invitación
    // suelta es una carga masiva de una línea.
    if (typeof datos.csv === 'string' && datos.csv.trim().length > 0) {
      const resultado = interpretarCsv(datos.csv, solicitante.actor.uid);
      const guardado = await guardarInvitaciones(resultado.validas.map(conSede));
      const rolDe = new Map(resultado.validas.map((i) => [i.correo, i.rolAsignado]));

      // Cada asiento dice lo que de verdad ocurrió con ese correo. Antes se
      // escribía «INVITACION_CREADA» para los tres casos, así que una carga
      // repetida dejaba en la bitácora doscientas altas de gente que ya estaba.
      await escribirAsientos([
        ...guardado.creadas.map((correo) =>
          asiento(
            'INVITACION_CREADA',
            solicitante,
            'INVITACION',
            correo,
            `Invitación por carga masiva: ${correo} como ${rolDe.get(correo)}`,
            { rolAsignado: rolDe.get(correo), origenCarga: 'CSV' },
          ),
        ),
        ...guardado.actualizadas.map((correo) =>
          asiento(
            'INVITACION_ACTUALIZADA',
            solicitante,
            'INVITACION',
            correo,
            `Invitación ya existente, actualizada a ${rolDe.get(correo)}: ${correo}`,
            { rolAsignado: rolDe.get(correo), origenCarga: 'CSV' },
          ),
        ),
      ]);

      return {
        creadas: guardado.creadas.length,
        actualizadas: guardado.actualizadas.length,
        yaEntraron: guardado.yaEntraron,
        rechazadas: resultado.rechazadas,
      };
    }

    const invitacion = crearInvitacion({
      correo: datos.correo ?? '',
      rolAsignado: datos.rol ?? '',
      nombre: datos.nombre ?? '',
      creadaPor: solicitante.actor.uid,
    });

    // Las facultades, solo activas del catálogo de la sede (RF-FAC-01).
    let facultades: string[] = [];
    if (datos.facultades !== undefined) {
      facultades = [
        ...(conFacultadesEnSede(
          { rol: invitacion.rolAsignado },
          SEDE_INICIAL,
          datos.facultades,
          await leerFacultades(solicitante.sedeId),
        )[SEDE_INICIAL]?.facultades ?? []),
      ];
    }
    const guardado = await guardarInvitaciones([
      { ...conSede(invitacion), ...(facultades.length > 0 ? { facultades } : {}) },
    ]);

    if (guardado.yaEntraron.length === 0) {
      const nueva = guardado.creadas.length === 1;
      await escribirAsiento(
        asiento(
          nueva ? 'INVITACION_CREADA' : 'INVITACION_ACTUALIZADA',
          solicitante,
          'INVITACION',
          invitacion.correo,
          nueva
            ? `Invitación creada para ${invitacion.correo} como ${invitacion.rolAsignado}`
            : `Invitación ya existente, actualizada a ${invitacion.rolAsignado}: ${invitacion.correo}`,
          { rolAsignado: invitacion.rolAsignado },
        ),
      );
    }

    return {
      creadas: guardado.creadas.length,
      actualizadas: guardado.actualizadas.length,
      yaEntraron: guardado.yaEntraron,
      rechazadas: [],
    };
  } catch (e) {
    throw comoHttps(e);
  }
});

export const revocarInvitacion = onCall(OPCIONES_LLAMABLE, async (peticion) => {
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

export const cambiarRol = onCall(OPCIONES_LLAMABLE, async (peticion) => {
  const solicitante = await exigir(peticion, 'ADMINISTRAR_USUARIOS');
  const { uid, rol } = peticion.data as { uid?: string; rol?: string };

  const nuevoRol = String(rol ?? '').toUpperCase() as Rol;
  if (!uid || !ROLES.includes(nuevoRol)) {
    throw new HttpsError('invalid-argument', 'Hace falta el usuario y un rol válido.');
  }

  const perfil = exigirDeLaSede(await buscarPerfil(uid), solicitante);
  if (uid === solicitante.actor.uid) {
    // Quitarse a uno mismo el rol de coordinador dejaría el sistema sin nadie
    // que pueda administrarlo.
    throw new HttpsError('failed-precondition', 'No puedes cambiar tu propio rol.');
  }

  // El rol es por sede (2.0): se cambia en la sede donde actúa quien lo pide.
  const sedeId = solicitante.sedeId;
  let membresias;
  try {
    membresias = conRolEnSede(perfil, sedeId, nuevoRol);
  } catch (e) {
    throw comoHttps(e);
  }
  // `rol` sigue siendo el de la sede principal, para las versiones anteriores.
  const rolPrincipal = membresias[sedePrincipal(membresias)]?.rol ?? nuevoRol;
  const actualizado: PerfilUsuario = { ...perfil, rol: rolPrincipal, membresias };
  await reemplazarMembresias(uid, membresias, rolPrincipal);
  await auth.setCustomUserClaims(uid, { ...claimsDe(actualizado) });
  await escribirAsiento(
    asiento(
      'USUARIO_ROL_CAMBIADO',
      solicitante,
      'USUARIO',
      uid,
      `Rol de ${perfil.correo} en ${sedeId}: ${rolEnSede(sedesDeMembresias(membresiasDe(perfil)), sedeId) ?? '—'} → ${nuevoRol}`,
      { rolAnterior: rolEnSede(sedesDeMembresias(membresiasDe(perfil)), sedeId) ?? '', rolNuevo: nuevoRol, sedeId },
    ),
  );

  return { uid, rol: nuevoRol };
});

export const cambiarEstadoUsuario = onCall(OPCIONES_LLAMABLE, async (peticion) => {
  const solicitante = await exigir(peticion, 'ADMINISTRAR_USUARIOS');
  const { uid, activo } = peticion.data as { uid?: string; activo?: boolean };

  if (!uid || typeof activo !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Hace falta el usuario y el estado.');
  }
  if (uid === solicitante.actor.uid) {
    throw new HttpsError('failed-precondition', 'No puedes desactivar tu propia cuenta.');
  }

  const perfil = exigirDeLaSede(await buscarPerfil(uid), solicitante);

  // RN-10: se desactiva, no se borra. El historial queda íntegro.
  await actualizarPerfil(uid, { activo });
  await auth.setCustomUserClaims(uid, { ...claimsDe({ ...perfil, activo }) });
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

export const cambiarAutorizacionesFinas = onCall(OPCIONES_LLAMABLE, async (peticion) => {
  const solicitante = await exigir(peticion, 'ADMINISTRAR_USUARIOS');
  const { uid, puedeEmitirUrgentes, puedeCrearRecurrentes, recibeAvisos: recibe } =
    peticion.data as {
      uid?: string;
      puedeEmitirUrgentes?: boolean;
      puedeCrearRecurrentes?: boolean;
      recibeAvisos?: boolean;
    };

  if (!uid) {
    throw new HttpsError('invalid-argument', 'Falta el usuario.');
  }

  const perfil = exigirDeLaSede(await buscarPerfil(uid), solicitante);

  const urgentes = puedeEmitirUrgentes ?? perfil.puedeEmitirUrgentes;
  const recurrentes = puedeCrearRecurrentes ?? perfil.puedeCrearRecurrentes;
  // Al tocarla se fija explícitamente: a partir de ahí manda la decisión del
  // coordinador y ya no el valor por omisión del rol.
  const recibeFinal = recibe ?? recibeAvisos(perfil.rol, perfil.recibeAvisos);

  await actualizarPerfil(uid, {
    puedeEmitirUrgentes: urgentes,
    puedeCrearRecurrentes: recurrentes,
    recibeAvisos: recibeFinal,
  });
  await auth.setCustomUserClaims(uid, {
    ...claimsDe({
      ...perfil,
      puedeEmitirUrgentes: urgentes,
      puedeCrearRecurrentes: recurrentes,
      recibeAvisos: recibeFinal,
    }),
  });
  await escribirAsiento(
    asiento(
      'USUARIO_ROL_CAMBIADO',
      solicitante,
      'USUARIO',
      uid,
      `Autorizaciones finas de ${perfil.correo}: urgentes=${urgentes}, recurrentes=${recurrentes}, recibe=${recibeFinal}`,
      {
        puedeEmitirUrgentes: urgentes,
        puedeCrearRecurrentes: recurrentes,
        recibeAvisos: recibeFinal,
      },
    ),
  );

  return {
    uid,
    puedeEmitirUrgentes: urgentes,
    puedeCrearRecurrentes: recurrentes,
    recibeAvisos: recibeFinal,
  };
});

/**
 * A qué facultades de su sede pertenece una persona (2.0 · RF-FAC-01).
 *
 * Solo la coordinación de esa sede, y solo con facultades activas del catálogo
 * de la sede. No cambia el token: las facultades no viajan en él, se leen del
 * perfil al resolver un envío por facultad.
 */
export const cambiarFacultades = onCall(OPCIONES_LLAMABLE, async (peticion) => {
  const solicitante = await exigir(peticion, 'ADMINISTRAR_USUARIOS');
  const { uid, facultades } = peticion.data as { uid?: string; facultades?: unknown };
  if (!uid) {
    throw new HttpsError('invalid-argument', 'Falta el usuario.');
  }
  const perfil = exigirDeLaSede(await buscarPerfil(uid), solicitante);

  try {
    const membresias = conFacultadesEnSede(
      perfil,
      solicitante.sedeId,
      facultades,
      await leerFacultades(solicitante.sedeId),
    );
    const antes = membresiasDe(perfil)[solicitante.sedeId]?.facultades ?? [];
    const despues = membresias[solicitante.sedeId]?.facultades ?? [];
    await reemplazarMembresias(uid, membresias);
    await escribirAsiento(
      crearAsiento({
        tipo: 'USUARIO_FACULTADES_CAMBIADAS',
        actor: solicitante.actor,
        entidad: 'USUARIO',
        entidadId: uid,
        resumen: `Facultades de ${perfil.correo} en ${solicitante.sedeId}: ${antes.join(', ') || '—'} → ${despues.join(', ') || '—'}`,
        datos: { antes, despues },
        sedeId: solicitante.sedeId,
      }),
    );
    return { uid, facultades: despues };
  } catch (e) {
    throw comoHttps(e);
  }
});

// ---------------------------------------------------------------------------
// Grupos — RF-USR-03, RF-USR-04, DT-08
// ---------------------------------------------------------------------------

export const guardarGrupo = onCall(OPCIONES_LLAMABLE, async (peticion) => {
  const solicitante = await exigir(peticion, 'ADMINISTRAR_GRUPOS');
  const { grupoId, nombre, descripcion, miembros, facultadId } = peticion.data as {
    grupoId?: string;
    nombre?: string;
    descripcion?: string;
    miembros?: string[];
    /** Opcional (RF-FAC-03): la facultad a la que pertenece el grupo. */
    facultadId?: string | null;
  };

  try {
    if (facultadId !== undefined && facultadId !== null && !esIdDeFacultad(facultadId)) {
      throw new HttpsError('invalid-argument', 'La facultad no es válida.');
    }
    const grupo = crearGrupo({
      nombre: nombre ?? '',
      descripcion: descripcion ?? '',
      miembros: normalizarMiembros(miembros ?? []),
      creadoPor: solicitante.actor.uid,
    });

    const ref = grupoId
      ? db.collection(RUTAS.grupos).doc(grupoId)
      : db.collection(RUTAS.grupos).doc();

    // Un grupo es de una sede (RF-SED-01): la de quien lo crea. Editar uno de
    // otra sede se responde como si no existiera.
    let facultadPrevia: string | null = null;
    if (grupoId) {
      const previo = await ref.get();
      if (!previo.exists || sedeDelDocumento(previo.data()) !== solicitante.sedeId) {
        throw new HttpsError('not-found', 'Ese grupo no existe.');
      }
      facultadPrevia = (previo.get('facultadId') as string | null | undefined) ?? null;
    }

    // 2.0.7: la facultad tiene que ofrecerse en la sede, y cada miembro tiene
    // que ser de la sede (y de esa facultad, si el grupo tiene una).
    const facultadDelGrupo = facultadId === undefined ? facultadPrevia : facultadId;
    if (facultadDelGrupo !== null) {
      const ofrecidas = await leerFacultades(solicitante.sedeId);
      if (!ofrecidas.some((f) => f.id === facultadDelGrupo && f.activa)) {
        throw new HttpsError('invalid-argument', 'Esa facultad no se ofrece en esta sede.');
      }
    }
    if (grupo.miembros.length > 0) {
      const perfiles = await db.getAll(
        ...grupo.miembros.map((uid) => db.collection(RUTAS.usuarios).doc(uid)),
      );
      const porUid = new Map(
        perfiles
          .filter((p) => p.exists)
          .map((p) => [p.id, { rol: (p.get('rol') as Rol | undefined) ?? 'CATEDRATICO', membresias: p.get('membresias') as unknown }]),
      );
      const nombres = new Map(perfiles.map((p) => [p.id, (p.get('nombre') as string | undefined) ?? '']));
      exigirMiembrosEnLugar(
        miembrosFueraDeLugar(grupo.miembros, porUid, solicitante.sedeId, facultadDelGrupo).map((uid) => ({
          uid,
          nombre: nombres.get(uid) ?? '',
        })),
        facultadDelGrupo !== null,
      );
    }

    await ref.set(
      {
        sedeId: solicitante.sedeId,
        ...(facultadId === undefined ? {} : { facultadId: facultadId ?? null }),
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

/**
 * Activa o desactiva un grupo (RF-USR-04).
 *
 * No se borra: un grupo borrado dejaría mensajes históricos apuntando a algo
 * que ya no existe, y el reporte de entregas de un simulacro pasado tiene que
 * poder decir a qué grupo se envió. Desactivar lo saca de la lista de
 * destinatarios elegibles y conserva el rastro (RN-03 aplicado a grupos).
 */
export const cambiarEstadoGrupo = onCall(OPCIONES_LLAMABLE, async (peticion) => {
  const solicitante = await exigir(peticion, 'ADMINISTRAR_GRUPOS');
  const { grupoId, activo } = peticion.data as {
    grupoId?: string;
    activo?: boolean;
  };

  if (!grupoId) {
    throw new HttpsError('invalid-argument', 'Falta el identificador del grupo.');
  }

  try {
    const ref = db.collection(RUTAS.grupos).doc(grupoId);
    const instantanea = await ref.get();

    if (!instantanea.exists || sedeDelDocumento(instantanea.data()) !== solicitante.sedeId) {
      throw new HttpsError('not-found', 'Ese grupo no existe.');
    }

    await ref.update({
      activo: activo === true,
      actualizadoEn: FieldValue.serverTimestamp(),
    });

    await escribirAsiento(
      asiento(
        'GRUPO_MODIFICADO',
        solicitante,
        'GRUPO',
        grupoId,
        `${activo === true ? 'Reactivación' : 'Desactivación'} del grupo «${instantanea.get('nombre') as string}»`,
        { activo: activo === true },
      ),
    );

    return { grupoId, activo: activo === true };
  } catch (e) {
    throw comoHttps(e);
  }
});

/**
 * Quiénes se pueden meter en un grupo (RF-USR-03).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Existe porque un administrador académico NO puede leer el padrón.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Las reglas solo abren `usuarios` al coordinador, al auditor y al propio
 * interesado (documento 05, sección 5), y está bien que así sea: administrar
 * grupos no debería dar acceso a la lista completa de la institución con sus
 * roles y sus autorizaciones.
 *
 * Pero para armar un grupo hacen falta nombres. Aquí se devuelve lo mínimo
 * —quién recibe avisos, con su nombre y su correo— y nada más: ni rol, ni
 * banderas, ni quién está desactivado. Suficiente para elegir, insuficiente
 * para hacerse un directorio.
 */
export const destinatariosElegibles = onCall(OPCIONES_LLAMABLE, async (peticion) => {
  const solicitante = await exigir(peticion, 'ADMINISTRAR_GRUPOS');

  const instantanea = await db.collection(RUTAS.usuarios).get();

  const elegibles = instantanea.docs
    .filter((d) => {
      if (d.get('activo') !== true) {
        return false;
      }
      // Solo la gente de la sede, con el rol que tiene en ella (2.0).
      const rolAqui = rolDelPerfilEnSede(d.data(), solicitante.sedeId);
      return rolAqui !== null && recibeAvisos(rolAqui, d.get('recibeAvisos') as boolean | undefined);
    })
    .map((d) => ({
      uid: d.id,
      nombre: (d.get('nombre') as string | undefined) ?? d.id,
      correo: (d.get('correo') as string | undefined) ?? '',
      // 2.0.7: sus facultades EN esta sede, para ofrecer en un grupo de una
      // facultad solo a quien la tiene.
      facultades: membresiasDe({ rol: (d.get('rol') as Rol | undefined) ?? 'CATEDRATICO', membresias: d.get('membresias') as unknown })[
        solicitante.sedeId
      ]?.facultades ?? [],
    }));

  elegibles.sort((a, b) => a.nombre.localeCompare(b.nombre));

  return { elegibles };
});
