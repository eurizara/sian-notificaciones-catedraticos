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

import { enviarPorWebPush } from '../infrastructure/webpush';

import { crearAsiento } from '../domain/bitacora';
import {
  crearDispositivo,
  leerEntradaDeRegistro,
  motivoPorElQueNoRecibe,
  puedeRecibirNotificaciones,
} from '../domain/dispositivo';
import { ErrorDominio, ErrorValidacion } from '../domain/errores';
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
    instalacionId?: string;
    enviarPrueba?: boolean;
  };

  try {
    // Toda la traducción vive en el dominio y está probada. Enumerar los
    // campos aquí fue lo que perdió `webPush` y `versionApp` por el camino.
    const dispositivo = crearDispositivo(leerEntradaDeRegistro(peticion.data));

    // ──────────────────────────────────────────────────────────────────────
    // EL DOCUMENTO SE IDENTIFICA POR INSTALACIÓN, NO POR TOKEN.
    // ──────────────────────────────────────────────────────────────────────
    //
    // Antes el identificador era el propio token, con este razonamiento al
    // lado: «reabrir la aplicación cien veces no crea cien dispositivos,
    // refresca el mismo». Es cierto donde el token es estable. En iOS no lo
    // es: Safari lo rota, así que cada apertura escribía un documento nuevo y
    // el anterior se quedaba.
    //
    // Medido en producción el 28 de agosto de 2026: nueve tokens de un mismo
    // iPhone, de una sola persona, en dos días. Cada aviso se enviaba a los
    // nueve y, como los viejos estaban muertos, sus avisos constaban como no
    // entregados aunque tuviera la aplicación instalada y el permiso dado.
    //
    // El identificador de instalación lo genera la aplicación y lo guarda en
    // `localStorage`: sobrevive a cerrar sesión y a cerrar la aplicación, que
    // es exactamente lo que el token no hacía.
    //
    // Si no viene —un cliente que todavía no se actualizó— se cae al token,
    // como antes. Así la actualización no rompe a quien va un despliegue
    // atrás: sigue registrándose igual hasta que recargue.
    const coleccion = db.collection(RUTAS.usuarios).doc(uid).collection('dispositivos');
    const instalacionId = (datos.instalacionId ?? '').trim();
    // Un aparato que se suscribió con nuestra llave no tiene token: sin
    // identificador de instalación no habría nombre para el documento, y
    // `doc('')` revienta con un error que no explica nada.
    const nombre = instalacionId || dispositivo.tokenFCM;
    if (nombre.length === 0) {
      throw new ErrorValidacion(
        'SIN_IDENTIFICADOR_DE_APARATO',
        'No se pudo identificar este aparato. Vuelve a abrir la aplicación.',
      );
    }
    const ref = coleccion.doc(nombre);

    const yaExistia = (await ref.get()).exists;

    await ref.set(
      {
        ...dispositivo,
        ...(instalacionId ? { instalacionId } : {}),
        ultimaActividad: FieldValue.serverTimestamp(),
        ...(yaExistia ? {} : { registradoEn: FieldValue.serverTimestamp() }),
      },
      { merge: true },
    );

    // Retira el registro que el esquema viejo había dejado con este mismo
    // token como identificador. Sin esto convivirían los dos y la persona
    // recibiría cada aviso dos veces.
    // Con la llave propia no hay token, y `doc('')` no lanza una promesa
    // rechazada: revienta en el acto, por debajo del `catch`.
    if (
      instalacionId &&
      dispositivo.tokenFCM.length > 0 &&
      instalacionId !== dispositivo.tokenFCM
    ) {
      await coleccion
        .doc(dispositivo.tokenFCM)
        .delete()
        .catch(() => undefined);
    }

    let pruebaEnviada = false;
    const motivo = motivoPorElQueNoRecibe(dispositivo);

    if (datos.enviarPrueba !== false && puedeRecibirNotificaciones(dispositivo)) {
      try {
        // Mensaje SOLO de datos, a propósito.
        //
        // ──────────────────────────────────────────────────────────────────
        // Con un bloque `notification`, quien decide cómo se ve es el
        // navegador. Con datos, decidimos nosotros.
        // ──────────────────────────────────────────────────────────────────
        //
        // Y hay cosas que no se pueden delegar: el prefijo «URGENTE» del
        // título y el `requireInteraction` que impide que una alerta se
        // descarte sola son la única distinción disponible en iOS-PWA, donde
        // no se puede definir sonido ni vibración propios (deuda DT-02).
        //
        // El service worker es quien pinta la notificación, y lee estos
        // mismos nombres. Enviar `notification` dejaba el cuerpo vacío
        // porque buscaba `data.cuerpo` y nadie lo mandaba.
        const prueba = {
          tipo: 'PRUEBA_REGISTRO',
          titulo: 'SIAN UMG-BDM',
          cuerpo: 'Tu dispositivo quedó registrado. Aquí llegarán los avisos.',
        };

        // Por la vía de ESTE aparato: si se suscribió con nuestra llave, no
        // tiene token de FCM y la prueba va por Web Push directo (DT-23).
        if (dispositivo.webPush) {
          const r = await enviarPorWebPush(dispositivo.webPush, prueba);
          pruebaEnviada = r.ok;
        } else {
          await getMessaging().send({
            token: dispositivo.tokenFCM,
            data: prueba,
            webpush: { fcmOptions: { link: '/' } },
          });
          pruebaEnviada = true;
        }
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
        tipo: yaExistia ? 'SESION_INICIADA' : 'DISPOSITIVO_REGISTRADO',
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
      // Para que la aplicación le pueda decir al service worker a quién
      // pertenece este aparato: él no tiene sesión, y sin eso no podría
      // reportar una suscripción nueva (DT-23).
      uid,
    };
  } catch (e) {
    if (e instanceof ErrorDominio) {
      throw new HttpsError('invalid-argument', e.message, { codigo: e.codigo });
    }
    logger.error('Fallo registrando dispositivo', { uid, error: String(e) });
    throw new HttpsError('internal', 'No se pudo registrar el dispositivo.');
  }
});
