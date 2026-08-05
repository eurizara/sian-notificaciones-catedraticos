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

    final web.ServiceWorkerRegistration registro =
        await web.window.navigator.serviceWorker.ready.toDart;

    consolaError('SIAN.notif registro | alcance=${registro.scope}');

    await registro
        .showNotification(
          titulo,
          web.NotificationOptions(
            body: cuerpo,
            icon: '/icons/Icon-192.png',
            badge: '/icons/Icon-192.png',
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
