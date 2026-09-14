/// SIAN — Que el worker sepa quién es y revise el canal por su cuenta (DT-23).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Dos cosas que solo puede hacer la página, para que el worker haga el resto.
/// ────────────────────────────────────────────────────────────────────────────
///
/// El service worker no tiene sesión y no puede leer `localStorage`: si se
/// despierta de madrugada porque el navegador rotó la suscripción, no sabría a
/// qué registro pertenece. Así que al registrar el dispositivo se le deja
/// dicho, y él lo guarda en su propio almacén.
///
/// Y se le pide al navegador que lo despierte cada cierto tiempo para revisar
/// el canal. Eso **solo existe en Android con la aplicación instalada**: en
/// iPhone la API no está y la petición simplemente no se hace. No se rompe
/// nada; en iOS el canal se sigue renovando al abrir, como hasta ahora.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'consola.dart';
import 'registro_worker_web.dart';

/// Le dice al worker quién está usando este aparato.
Future<void> avisarIdentidadAlWorker({
  required String uid,
  required String instalacionId,
}) async {
  try {
    final web.ServiceWorkerRegistration? registro = await registroDelWorker();
    if (registro == null) {
      return;
    }
    // `active` es el que está atendiendo; si todavía se está instalando, no hay
    // a quién hablarle y se intentará en la próxima apertura.
    registro.active?.postMessage(
      <String, String>{
        'tipo': 'sian:identidad',
        'uid': uid,
        'instalacionId': instalacionId,
      }.jsify()!,
    );
  } on Object catch (e) {
    consolaError('SIAN.canal identidad no enviada | $e');
  }
}

/// Pide que el sistema despierte al worker cada cierto tiempo.
///
/// El navegador decide la frecuencia real —en la práctica, no más de una vez
/// cada doce horas— y puede negarse. Donde no exista la API, no pasa nada.
Future<void> pedirRevisionPeriodicaDelCanal() async {
  try {
    final web.ServiceWorkerRegistration? registro = await registroDelWorker();
    if (registro == null) {
      return;
    }
    final JSObject registroJS = registro as JSObject;
    if (!registroJS.has('periodicSync')) {
      // No existe en iPhone ni en los navegadores sin la API. El canal se
      // sigue renovando al abrir, como hasta ahora.
      return;
    }
    final JSObject periodica =
        registroJS.getProperty<JSObject>('periodicSync'.toJS);

    // Sin el permiso no se registra, y pedirlo no lo concede: lo da el
    // navegador según cuánto se use la aplicación instalada.
    final web.Permissions permisos = web.window.navigator.permissions;
    final web.PermissionStatus estado = await permisos
        .query(<String, String>{'name': 'periodic-background-sync'}.jsify()!
            as JSObject)
        .toDart;
    if (estado.state != 'granted') {
      consolaError('SIAN.canal revisión periódica no concedida | ${estado.state}');
      return;
    }

    await periodica
        .callMethod<JSPromise<JSAny?>>(
          'register'.toJS,
          'sian-revisar-canal'.toJS,
          <String, int>{'minInterval': 12 * 60 * 60 * 1000}.jsify()!,
        )
        .toDart;
    consolaError('SIAN.canal revisión periódica registrada');
  } on Object catch (e) {
    // Donde no existe —iPhone, y los navegadores sin la API— esto termina aquí
    // y el canal sigue renovándose al abrir la aplicación.
    consolaError('SIAN.canal sin revisión periódica | $e');
  }
}
