/// SIAN — Encontrar el service worker de verdad, sin quedarse esperando.
///
/// ────────────────────────────────────────────────────────────────────────────
/// `navigator.serviceWorker.ready` NUNCA resuelve en esta aplicación
/// ────────────────────────────────────────────────────────────────────────────
///
/// Es la forma habitual de pedir el registro del worker, y aquí es una trampa.
/// `ready` espera a que haya un worker **con alcance sobre esta página**, y en
/// SIAN no lo hay:
///
///   · el worker de Flutter se registra en `/`, pero esta compilación no
///     guarda nada en caché: en cuanto se activa **se da de baja solo**;
///   · el de Firebase —el nuestro, `firebase-messaging-sw.js`— se registra en
///     `/firebase-cloud-messaging-push-scope`, que no cubre `/`.
///
/// Así que la promesa se queda pendiente para siempre. No lanza, no se puede
/// atrapar con un `try`, y quien la espere se queda colgado sin decir nada.
///
/// Costó un envío: el 12 de septiembre de 2026, al estrenar la suscripción
/// propia, el registro del dispositivo pasó a esperar `ready` antes de pedir
/// nada. Ningún aparato volvió a registrarse —ni por la vía nueva ni por la
/// vieja—, no hubo un solo error en los registros, y un iPhone recién abierto
/// con la versión del día se quedó sin recibir el aviso.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Lo que se hace en su lugar
/// ────────────────────────────────────────────────────────────────────────────
///
/// Se busca el registro por su guion, se registra si todavía no está, y **todo
/// lleva plazo**. Si al cabo de unos segundos no hay worker, se devuelve nulo y
/// quien llamó sigue por donde pueda. Una espera sin plazo es peor que un
/// fallo: el fallo se ve.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'consola.dart';

/// El guion del worker de SIAN. Es el que atiende `push`, y el alcance es el
/// que usa el SDK de Firebase al registrarlo por su cuenta: si aquí se pusiera
/// otro, habría dos registros del mismo guion y dos suscripciones.
const String _guion = '/firebase-messaging-sw.js';
const String _alcance = '/firebase-cloud-messaging-push-scope';

/// Cuánto se espera como mucho. Bastante para un arranque lento, poco para que
/// nadie se quede mirando una pantalla que no avanza.
const Duration _plazo = Duration(seconds: 8);

/// El registro del worker de SIAN con un worker ya activo, o nulo.
///
/// Nunca lanza y nunca se queda esperando: al agotarse el plazo devuelve nulo.
Future<web.ServiceWorkerRegistration?> registroDelWorker() async {
  try {
    return await _buscarOCrear().timeout(
      _plazo,
      onTimeout: () {
        consolaError('SIAN.worker sin registro tras ${_plazo.inSeconds}s');
        return null;
      },
    );
  } on Object catch (e) {
    consolaError('SIAN.worker no se pudo obtener el registro | $e');
    return null;
  }
}

Future<web.ServiceWorkerRegistration?> _buscarOCrear() async {
  web.ServiceWorkerRegistration? registro = await _buscar();

  // Todavía no está: lo normal la primera vez, antes de que el SDK de Firebase
  // pida el token. Registrarlo aquí es inocuo — con el mismo guion y el mismo
  // alcance, el navegador devuelve el que ya hubiera.
  registro ??= await web.window.navigator.serviceWorker
      .register(_guion.toJS, web.RegistrationOptions(scope: _alcance))
      .toDart;

  return await _esperarActivo(registro);
}

/// Busca entre los registros el que corre nuestro guion.
///
/// Se mira `active`, `waiting` e `installing`: recién instalado, el worker
/// todavía no está en `active`, y descartarlo por eso llevaría a registrarlo
/// por segunda vez.
Future<web.ServiceWorkerRegistration?> _buscar() async {
  final JSArray<web.ServiceWorkerRegistration> registros =
      await web.window.navigator.serviceWorker.getRegistrations().toDart;

  for (final web.ServiceWorkerRegistration r in registros.toDart) {
    final String guion =
        r.active?.scriptURL ?? r.waiting?.scriptURL ?? r.installing?.scriptURL ?? '';
    if (guion.contains('firebase-messaging-sw.js')) {
      return r;
    }
  }
  return null;
}

/// Espera a que el worker esté activo: antes de eso no se le puede hablar ni
/// suscribir nada. Se comprueba cada poco en vez de escuchar `statechange`
/// porque el worker puede haberse activado ya entre una línea y la siguiente.
Future<web.ServiceWorkerRegistration?> _esperarActivo(
  web.ServiceWorkerRegistration registro,
) async {
  for (int intento = 0; intento < 40; intento += 1) {
    if (registro.active != null) {
      return registro;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  return registro.active != null ? registro : null;
}
