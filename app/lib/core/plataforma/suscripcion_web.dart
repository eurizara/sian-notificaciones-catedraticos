/// SIAN — La suscripción propia del aparato (DT-23).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Por qué no se pide el token de FCM cuando hay llave propia
/// ────────────────────────────────────────────────────────────────────────────
///
/// Un navegador tiene **una sola** suscripción por aplicación. Si se pide el
/// token de FCM, esa suscripción queda hecha con la llave de Firebase y lo
/// único que podemos enviar es un token que solo la página sabe acuñar: cuando
/// el navegador rota de madrugada, no hay forma de recuperarlo sin que alguien
/// abra la aplicación. Es lo que se midió el 12 de septiembre de 2026.
///
/// Suscribiéndose con **nuestra** llave, lo que se guarda es la suscripción en
/// crudo, y esa el service worker sí la sabe renovar y reportar él solo.
///
/// `applicationServerKey` admite la llave en texto —base64url—, que es como
/// viaja desde la compilación.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'consola.dart';

/// Se suscribe y devuelve lo que hay que guardar, o nulo si no se pudo.
Future<Map<String, String>?> suscribirConLlavePropia(String clavePublica) async {
  if (clavePublica.isEmpty) {
    return null;
  }
  try {
    final web.ServiceWorkerRegistration registro =
        await web.window.navigator.serviceWorker.ready.toDart;

    // La que ya hubiera: si fue creada con otra llave, el navegador la
    // rechazaría al suscribir, así que se retira primero.
    web.PushSubscription? actual = await registro.pushManager
        .getSubscription()
        .toDart;
    if (actual != null && !_mismaLlave(actual, clavePublica)) {
      await actual.unsubscribe().toDart;
      actual = null;
    }

    final web.PushSubscription suscripcion =
        actual ??
        await registro.pushManager
            .subscribe(
              web.PushSubscriptionOptionsInit(
                userVisibleOnly: true,
                applicationServerKey: clavePublica.toJS,
              ),
            )
            .toDart;

    final Object? json = suscripcion.toJSON().dartify();
    if (json is! Map) {
      return null;
    }
    final Object? claves = json['keys'];
    final Map<Object?, Object?> k = claves is Map ? claves : <Object?, Object?>{};

    final String endpoint = '${json['endpoint'] ?? ''}';
    final String p256dh = '${k['p256dh'] ?? ''}';
    final String auth = '${k['auth'] ?? ''}';
    if (endpoint.isEmpty || p256dh.isEmpty || auth.isEmpty) {
      return null;
    }
    return <String, String>{'endpoint': endpoint, 'p256dh': p256dh, 'auth': auth};
  } on Object catch (e) {
    // Sin permiso, sin service worker o sin soporte: se sigue por FCM, que es
    // lo que había antes de esto.
    consolaError('SIAN.suscripcion no se pudo suscribir | $e');
    return null;
  }
}

/// ¿La suscripción que ya existe se hizo con esta misma llave?
bool _mismaLlave(web.PushSubscription suscripcion, String clavePublica) {
  try {
    final JSAny? llave = suscripcion.options.applicationServerKey;
    if (llave == null) {
      return false;
    }
    // Llega como buffer de bytes; se compara contra la llave en base64url sin
    // relleno, que es como la enviamos.
    final Object? bytes = llave.dartify();
    if (bytes is! List) {
      return false;
    }
    final String actual = _aBase64Url(bytes.cast<int>());
    return actual == clavePublica.replaceAll('=', '');
  } on Object {
    return false;
  }
}

String _aBase64Url(List<int> bytes) {
  const String alfabeto =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
  final StringBuffer salida = StringBuffer();
  for (int i = 0; i < bytes.length; i += 3) {
    final int b0 = bytes[i];
    final int b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
    final int b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
    salida.write(alfabeto[b0 >> 2]);
    salida.write(alfabeto[((b0 & 3) << 4) | (b1 >> 4)]);
    if (i + 1 < bytes.length) {
      salida.write(alfabeto[((b1 & 15) << 2) | (b2 >> 6)]);
    }
    if (i + 2 < bytes.length) {
      salida.write(alfabeto[b2 & 63]);
    }
  }
  return salida.toString();
}
