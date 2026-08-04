/**
 * SIAN — Function que decide quién entra al sistema (RF-AUT-03).
 *
 * El cliente la invoca **inmediatamente después de autenticarse**, sea con
 * Google o con correo y contraseña. Hasta que esta Function responde, la
 * credencial no vale nada: no hay perfil, no hay rol en el token, y las reglas
 * de seguridad rechazan cualquier lectura.
 *
 * Por qué una Function invocable y no una función de bloqueo de Identity
 * Platform: ADR-008. Las de bloqueo exigen habilitar Identity Platform, que
 * cambia el modelo de precios del proyecto. Esta alternativa cuesta cero y
 * hace lo mismo, a cambio de una llamada explícita desde el cliente.
 *
 * Que el cliente pueda **no** llamarla no es un agujero: quien se salte este
 * paso se queda con un token sin rol, y sin rol las reglas no le dejan leer ni
 * un documento (RN-01).
 */

import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';

import { decidirActivacion } from '../application/activarSesion';
import { OPCIONES_FUNCION, auth } from '../infrastructure/firebase';
import {
  buscarInvitacion,
  buscarPerfil,
  escribirAsiento,
  guardarPerfil,
  marcarInvitacionConsumida,
  registrarUltimoAcceso,
  zonaHorariaInstitucional,
} from '../infrastructure/repositorios';

/** Lo que la Function devuelve al cliente. */
export interface RespuestaActivacion {
  readonly estado: 'ACTIVA' | 'CREADA';
  readonly rol: string;
  readonly nombre: string;
}

export const activarSesion = onCall(OPCIONES_FUNCION, async (peticion) => {
  const auth0 = peticion.auth;
  if (!auth0) {
    throw new HttpsError('unauthenticated', 'Hay que autenticarse antes de activar la sesión.');
  }

  const uid = auth0.uid;
  const correo = (auth0.token.email as string | undefined) ?? '';
  const proveedorAuth =
    (auth0.token.firebase?.sign_in_provider as string | undefined) ?? 'password';
  const nombreDelProveedor = auth0.token.name as string | undefined;

  const [invitacion, perfilExistente, zona] = await Promise.all([
    correo ? buscarInvitacion(correo.trim().toLowerCase()) : Promise.resolve(null),
    buscarPerfil(uid),
    zonaHorariaInstitucional(),
  ]);

  const decision = decidirActivacion({
    uid,
    correo,
    proveedorAuth,
    ...(nombreDelProveedor ? { nombreDelProveedor } : {}),
    invitacion,
    perfilExistente,
    zonaHorariaInstitucional: zona,
  });

  // El asiento se escribe SIEMPRE, decida lo que decida: aceptar, crear o
  // rechazar. RNF-17 no admite excepciones, y el rechazo es justamente el
  // evento que más interesa auditar.
  await escribirAsiento(decision.asiento);

  if (decision.tipo === 'RECHAZADO') {
    if (decision.borrarCredencial) {
      // Sin esto quedaría una cuenta autenticable, sin perfil y sin rol, que
      // volvería a intentarlo indefinidamente.
      await auth.deleteUser(uid).catch((e: unknown) => {
        logger.error('No se pudo borrar la credencial huérfana', { uid, error: String(e) });
      });
    }

    logger.info('Acceso rechazado', { uid, motivo: decision.motivo });

    throw new HttpsError(
      'permission-denied',
      decision.motivo === 'CUENTA_DESACTIVADA'
        ? 'Esta cuenta está desactivada.'
        : 'Este correo no está autorizado para usar el sistema.',
      { motivo: decision.motivo },
    );
  }

  if (decision.tipo === 'PERFIL_CREADO') {
    await guardarPerfil(decision.perfil);
    await marcarInvitacionConsumida(decision.invitacionConsumida, uid);
  } else {
    await registrarUltimoAcceso(uid);
  }

  // Los claims se siembran en los dos caminos aceptados: si el coordinador
  // cambió el rol mientras el usuario tenía sesión, esto lo pone al día.
  await auth.setCustomUserClaims(uid, { ...decision.claims });

  const respuesta: RespuestaActivacion = {
    estado: decision.tipo === 'PERFIL_CREADO' ? 'CREADA' : 'ACTIVA',
    rol: decision.perfil.rol,
    nombre: decision.perfil.nombre,
  };

  return respuesta;
});
