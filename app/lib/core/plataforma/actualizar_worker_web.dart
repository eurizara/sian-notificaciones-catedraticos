/// Comprueba si hay un service worker nuevo, en cada arranque.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Servir el archivo sin caché no basta: alguien tiene que PREGUNTAR.
/// ────────────────────────────────────────────────────────────────────────────
///
/// `firebase.json` sirve `firebase-messaging-sw.js` con `no-store`, y eso hace
/// que el navegador nunca se quede con una copia vieja **cuando va a buscarla**.
/// Lo que no hace es obligarlo a ir. Una PWA de iOS que se reabre no
/// necesariamente comprueba si su service worker cambió, y puede seguir
/// ejecutando el de hace días.
///
/// El resultado es de los que despistan, porque la aplicación **sí** se
/// actualiza: `main.dart.js` también va sin caché y ese sí se pide en cada
/// arranque. Así que se ve una aplicación con los cambios nuevos y un service
/// worker viejo por debajo, y como es el worker quien muestra las
/// notificaciones y lleva la insignia, los arreglos parecen no haber llegado.
///
/// Pasó el 28 de agosto de 2026: en desarrollo, recién reinstalado, las
/// notificaciones con la aplicación cerrada funcionaban; en producción, con la
/// misma versión desplegada pero sin reinstalar, no. La aplicación era la
/// nueva —lo probaban los identificadores de instalación que ya mandaba— y el
/// worker era el de antes.
///
/// `update()` fuerza la comprobación. Como el worker llama a `skipWaiting()` al
/// instalarse y a `clients.claim()` al activarse, el nuevo toma el control sin
/// esperar a que se cierren las ventanas. Con esto, **cerrar y volver a abrir
/// basta para que un arreglo llegue**; no hace falta desinstalar.
///
/// Se recorren todos los registros y no solo el que controla la página, por lo
/// mismo que la insignia: el de mensajería vive bajo su propio ámbito y no es
/// el `controller`.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Pide la comprobación. No espera el resultado ni la necesita.
void actualizarWorkers() {
  unawaited(_comprobar());
}

Future<void> _comprobar() async {
  try {
    final JSArray<web.ServiceWorkerRegistration> registros = await web
        .window
        .navigator
        .serviceWorker
        .getRegistrations()
        .toDart;

    for (final web.ServiceWorkerRegistration registro in registros.toDart) {
      // Si falla uno, los demás siguen: un registro puede estar a medio
      // instalar y no es motivo para dejar el resto sin comprobar.
      try {
        await registro.update().toDart;
      } on Object catch (_) {
        continue;
      }
    }
  } on Object catch (_) {
    // Sin service workers no hay nada que actualizar, y arrancar es más
    // importante que comprobarlo.
  }
}
