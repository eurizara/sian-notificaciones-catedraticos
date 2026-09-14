/// Implementación para navegador.
///
/// Se pide la notificación al **registro del service worker**, no con el
/// constructor `new Notification(...)`. Dos razones, y la segunda es la que
/// manda:
///
///   · Es la única forma admitida en Android y en iOS instalado como PWA. El
///     constructor directo está obsoleto ahí y sencillamente no hace nada.
///   · Al usar el mismo registro que entrega los mensajes en segundo plano, la
///     notificación sale igual esté la aplicación abierta o cerrada. Un aviso
///     que se ve distinto según dónde estabas mirando es un aviso que enseña a
///     desconfiar de él.
///
/// El sonido y la vibración los pone el sistema operativo con sus ajustes: en
/// iOS-PWA no se pueden definir propios, y esa es la deuda DT-02.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'consola.dart';
import 'registro_worker_web.dart';

Future<bool> mostrarNotificacionDelSistema({
  required String titulo,
  required String cuerpo,
  required bool urgente,
  String? etiqueta,
}) async {
  try {
    // Sin permiso concedido no se intenta: pedirlo aquí sería pedirlo sin que
    // nadie lo haya provocado, y el navegador lo rechazaría.
    final String permiso = web.Notification.permission;
    if (permiso != 'granted') {
      consolaError('SIAN.notif sin-permiso | estado=$permiso');
      return false;
    }

    final web.ServiceWorkerRegistration? registro = await registroDelWorker();
    if (registro == null) {
      consolaError('SIAN.notif sin worker | no se puede mostrar');
      return false;
    }

    consolaError('SIAN.notif registro | alcance=${registro.scope}');

    await registro
        .showNotification(
          titulo,
          web.NotificationOptions(
            body: cuerpo,
            icon: '/icons/Icon-192.png',
            // Silueta sobre transparente: Android pinta la insignia solo con
            // el canal alfa, y el icono opaco salía como un cuadrado blanco.
            badge: '/icons/insignia-notificacion.png',
            // Misma etiqueta que usa el service worker: si las dos rutas
            // muestran el mismo aviso, se reemplazan en vez de duplicarse.
            tag: etiqueta ?? 'sian',
            // Una alerta urgente no se descarta sola: exige un gesto.
            requireInteraction: urgente,
          ),
        )
        .toDart;

    consolaError('SIAN.notif mostrada | titulo=$titulo');
    return true;
  } on Object catch (e) {
    // Que el sistema no la muestre no puede tumbar la aplicación: el aviso
    // dentro de la pantalla sigue siendo el respaldo. Pero sí se deja dicho,
    // porque un `false` mudo es lo que impidió ver por qué no salía.
    consolaError('SIAN.notif falló | $e');
    return false;
  }
}

/// Cierra las notificaciones del sistema que lleven esta etiqueta.
///
/// ────────────────────────────────────────────────────────────────────────────
/// En Android, una notificación olvidada deja el icono marcado (DT-26).
/// ────────────────────────────────────────────────────────────────────────────
///
/// El lanzador cuenta las notificaciones pendientes, no solo la insignia. Las
/// de los avisos las cierra el service worker cuando la bandeja dice que ya se
/// leyeron; las de las respuestas (DT-27) no pasan por la bandeja, así que se
/// cierran aquí, al abrir la conversación que las provocó.
///
/// Si no se puede —sin service worker, sin permiso—, no pasa nada: quedaría
/// una notificación de más, no una de menos.
Future<void> cerrarNotificacionesDelSistema(String etiqueta) async {
  try {
    final web.ServiceWorkerRegistration? registro = await registroDelWorker();
    if (registro == null) {
      return;
    }
    final JSArray<web.Notification> abiertas = await registro
        .getNotifications(web.GetNotificationOptions(tag: etiqueta))
        .toDart;
    for (final web.Notification n in abiertas.toDart) {
      n.close();
    }
  } on Object catch (e) {
    consolaError('SIAN.notif no se pudo cerrar | etiqueta=$etiqueta | $e');
  }
}
