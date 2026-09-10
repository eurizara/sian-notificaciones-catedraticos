/// SIAN — Aviso de que la suscripción de push rotó (DT-23).
///
/// ────────────────────────────────────────────────────────────────────────────
/// El SDK de Firebase rota el token solo. Nadie le avisa a nuestro servidor.
/// ────────────────────────────────────────────────────────────────────────────
///
/// `firebase-messaging-compat.js` registra su propio `pushsubscriptionchange`
/// dentro del service worker: borra el token viejo y acuña uno nuevo. Su estado
/// interno queda al día y la colección `dispositivos` se queda con el token
/// muerto, así que el envío siguiente falla sin que nadie se entere.
///
/// El worker no puede arreglarlo por su cuenta —el SDK no expone `getToken`
/// fuera del contexto de ventana—, así que deja una marca y avisa a las ventanas
/// abiertas. Este archivo es el otro extremo de ese aviso.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Escucha el aviso del worker y llama a [alRotar] cuando llegue.
///
/// Se escucha aunque la aplicación acabe de registrarse: el punto es que el
/// registro se rehaga **en el momento** en que la suscripción cambia, sin
/// esperar a que alguien cierre y vuelva a abrir.
void escucharRotacionDeSuscripcion(void Function() alRotar) {
  try {
    web.window.navigator.serviceWorker.addEventListener(
      'message',
      (web.Event evento) {
        final web.MessageEvent mensaje = evento as web.MessageEvent;
        final JSAny? dato = mensaje.data;
        if (dato == null) {
          return;
        }
        final Object? mapa = dato.dartify();
        if (mapa is Map && mapa['tipo'] == 'sian:reregistrar') {
          alRotar();
        }
      }.toJS,
    );
  } on Object catch (_) {
    // Sin service worker no hay nada que escuchar, y eso no es un fallo: la
    // aplicación funciona igual, solo que sin este atajo.
  }
}

/// No se consulta la marca de IndexedDB desde aquí.
///
/// Leerla exigiría abrir la misma base que el worker desde otro hilo, y el
/// beneficio sería adelantar un registro que ya ocurre al abrir la bandeja. El
/// aviso en vivo es la parte que sí aporta algo que antes no existía.
Future<bool> huboRotacionPendiente() async => false;
