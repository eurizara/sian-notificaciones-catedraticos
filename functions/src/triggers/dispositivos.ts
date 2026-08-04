/**
 * SIAN — Registro de dispositivos y notificación de prueba (RF-USR-09).
 *
 * El registro pasa por el servidor, aunque las reglas permitirían al cliente
 * escribir su propia subcolección. Dos motivos:
 *
 *   1. La **notificación de prueba** solo puede enviarla el servidor, y es la
 *      única forma de saber que el canal funciona de verdad antes de que haya
 *      un aviso real que perder.
 *   2. Deja asiento en bitácora. Cuando un catedrático diga «no me llegó», la
 *      primera pregunta es si su dispositivo llegó a registrarse.
 *
 * Es además la mitigación viva del riesgo R-01: en iOS el identificador cambia
 * solo, así que la aplicación vuelve a llamar aquí **en cada apertura**, y el
 * token se refresca sin que nadie tenga que acordarse.
 */

import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import { getMessaging } from 'firebase-admin/messaging';

import { crearAsiento } from '../domain/bitacora';
import {
  crearDispositivo,
  motivoPorElQueNoRecibe,
  puedeRecibirNotificaciones,
} from '../domain/dispositivo';
import { ErrorDominio } from '../domain/errores';
import type { Rol } from '../domain/tipos';
import { FieldValue, OPCIONES_FUNCION, RUTAS, db } from '../infrastructure/firebase';
import { escribirAsiento } from '../infrastructure/repositorios';

export const registrarDispositivo = onCall(OPCIONES_FUNCION, async (peticion) => {
  if (!peticion.auth) {
    throw new HttpsError('unauthenticated', 'Hay que iniciar sesión.');
  }

  const uid = peticion.auth.uid;
  const correo = (peticion.auth.token.email as string | undefined) ?? '';
  const rol = (peticion.auth.token.rol as Rol | undefined) ?? 'CATEDRATICO';

  const datos = peticion.data as {
    tokenFCM?: string;
    plataforma?: string;
    esPWAInstalada?: boolean;
    navegador?: string;
    permisoNotificacion?: string;
    enviarPrueba?: boolean;
  };

  try {
    const dispositivo = crearDispositivo({
      tokenFCM: datos.tokenFCM ?? '',
      plataforma: datos.plataforma ?? '',
      esPWAInstalada: datos.esPWAInstalada ?? false,
      navegador: datos.navegador ?? '',
      permisoNotificacion: datos.permisoNotificacion ?? 'pendiente',
    });

    // El identificador del documento es el propio token: reabrir la
    // aplicación cien veces no crea cien dispositivos, refresca el mismo.
    const ref = db
      .collection(RUTAS.usuarios)
      .doc(uid)
      .collection('dispositivos')
      .doc(dispositivo.tokenFCM);

    const yaExistia = (await ref.get()).exists;

    await ref.set(
      {
        ...dispositivo,
        ultimaActividad: FieldValue.serverTimestamp(),
        ...(yaExistia ? {} : { registradoEn: FieldValue.serverTimestamp() }),
      },
      { merge: true },
    );

    // Se limpia cualquier registro anterior de este mismo usuario que el
    // servicio de push ya haya rechazado (RF-USR-10).
    let pruebaEnviada = false;
    const motivo = motivoPorElQueNoRecibe(dispositivo);

    if (datos.enviarPrueba !== false && puedeRecibirNotificaciones(dispositivo)) {
      try {
        await getMessaging().send({
          token: dispositivo.tokenFCM,
          notification: {
            title: 'SIAN UMG-BDM',
            body: 'Tu dispositivo quedó registrado. Aquí llegarán los avisos.',
          },
          data: { tipo: 'PRUEBA_REGISTRO' },
          webpush: {
            notification: { icon: '/icons/Icon-192.png', tag: 'sian-prueba' },
            fcmOptions: { link: '/' },
          },
        });
        pruebaEnviada = true;
      } catch (e) {
        // Que falle la prueba no invalida el registro: el token queda
        // guardado y el problema se ve en la bitácora.
        logger.warn('No se pudo enviar la notificación de prueba', {
          uid,
          error: String(e),
        });
      }
    }

    await escribirAsiento(
      crearAsiento({
        tipo: yaExistia ? 'SESION_INICIADA' : 'USUARIO_CREADO',
        actor: { uid, correo, rol },
        entidad: 'USUARIO',
        entidadId: uid,
        resumen: yaExistia
          ? `Dispositivo refrescado (${dispositivo.plataforma})`
          : `Dispositivo registrado (${dispositivo.plataforma})`,
        datos: {
          plataforma: dispositivo.plataforma,
          esPWAInstalada: dispositivo.esPWAInstalada,
          permiso: dispositivo.permisoNotificacion,
          pruebaEnviada,
          motivoSinRecepcion: motivo,
        },
        origen: 'APP_DOCENTE',
      }),
    );

    return {
      registrado: true,
      puedeRecibir: puedeRecibirNotificaciones(dispositivo),
      motivoSinRecepcion: motivo,
      pruebaEnviada,
    };
  } catch (e) {
    if (e instanceof ErrorDominio) {
      throw new HttpsError('invalid-argument', e.message, { codigo: e.codigo });
    }
    logger.error('Fallo registrando dispositivo', { uid, error: String(e) });
    throw new HttpsError('internal', 'No se pudo registrar el dispositivo.');
  }
});
