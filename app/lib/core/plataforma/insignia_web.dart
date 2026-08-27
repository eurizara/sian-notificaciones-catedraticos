/// Insignia real, sobre la Badging API del navegador (RF-ENT-13).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Es el número que aparece pegado al icono de la aplicación instalada.
/// ────────────────────────────────────────────────────────────────────────────
///
/// `navigator.setAppBadge(n)` pinta el número sobre el icono en la pantalla de
/// inicio o en la barra de tareas, y `clearAppBadge()` lo quita. Funciona en
/// las tres superficies donde vive SIAN:
///
///   · Android, con Chrome y la aplicación instalada.
///   · Escritorio, con Chrome o Edge y la aplicación instalada.
///   · iOS 16.4 en adelante, con la aplicación agregada a la pantalla de inicio.
///
/// **Exige que la aplicación esté instalada.** En una pestaña normal la función
/// existe y no falla, pero no hay icono sobre el cual pintar, así que no se ve
/// nada. Es el mismo requisito que ya tienen las notificaciones en iOS
/// (documento 06, D.5), de modo que no agrega un motivo nuevo para instalar:
/// refuerza el que ya había.
///
/// En iOS la insignia es además la única señal de cantidad que el sistema nos
/// deja dar: no podemos definir sonido ni vibración propios (DT-02). Un número
/// sobre el icono es poco, pero es lo que hay, y no depende de que la persona
/// haya visto pasar la notificación.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Se llama sin preguntar antes si existe
/// ────────────────────────────────────────────────────────────────────────────
///
/// La primera versión comprobaba `navigator.has('setAppBadge')` y solo llamaba
/// si daba verdadero. Es una comprobación de más: si el método no existe, la
/// llamada lanza y ya se está atrapando. Preguntar antes agrega una forma de
/// fallar —que la comprobación diga que no donde el método sí está— sin evitar
/// ninguna, así que se llama directo.
///
/// Además del navegador se avisa al **service worker**, que lleva su propia
/// cuenta para poder sumar mientras la aplicación está cerrada. Sin ese aviso
/// el worker seguiría sumando sobre un número que la persona ya resolvió.
library;

import 'dart:async';

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Vista sobre `navigator` con los dos métodos de la Badging API.
///
/// `package:web` todavía no los declara, así que se describen aquí en lugar de
/// esperar a que aparezcan.
extension type _NavegadorConInsignia._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> setAppBadge(int cuenta);
  external JSPromise<JSAny?> clearAppBadge();
}

/// Se conserva para que las pruebas puedan preguntarlo, pero **no** condiciona
/// las llamadas: ver la nota de la biblioteca.
bool get insigniaSoportada => true;

/// Pinta [cuenta] sobre el icono. Con cero, retira la insignia.
///
/// Los fallos se tragan a propósito. Pintar un número es un adorno útil, no
/// parte de la entrega del mensaje: si el navegador se niega —porque la
/// aplicación no está instalada, o porque el sistema no lo permite—, la bandeja
/// ya muestra el mismo dato y nada se pierde. Reventar aquí sí rompería algo.
void fijarInsignia(int cuenta) {
  final int n = cuenta < 0 ? 0 : cuenta;
  _avisarAlWorker(n);

  try {
    final _NavegadorConInsignia navegador =
        web.window.navigator as _NavegadorConInsignia;
    if (n > 0) {
      navegador.setAppBadge(n);
    } else {
      navegador.clearAppBadge();
    }
  } on Object catch (_) {
    // Silencio deliberado: ver la nota de arriba.
  }
}

/// Quita la insignia del icono.
void retirarInsignia() => fijarInsignia(0);

/// Le pasa el número al service worker, que es quien manda cuando la
/// aplicación está cerrada.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Se avisa a TODOS los workers registrados, no al que controla la página.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Aquí conviven dos service workers con ámbitos distintos: el que genera
/// Flutter, que controla la página, y `firebase-messaging-sw.js`, que registra
/// el SDK de Firebase por su cuenta bajo `/firebase-cloud-messaging-push-scope`.
/// El de la insignia es **el segundo**.
///
/// La versión anterior usaba `navigator.serviceWorker.controller`, que es el
/// primero. El mensaje se iba al worker equivocado y el de mensajería no se
/// enteraba nunca del número real. Como es él quien guarda la lista de mensajes
/// ya avisados, y solo la limpia cuando la aplicación le manda el conteo
/// exacto, **esa lista no se limpiaba jamás**: iba acumulando todos los avisos
/// que habían llegado alguna vez, y el número del icono crecía sin volver a
/// bajar. En un teléfono con tres mensajes recibidos y uno solo sin leer, el
/// icono decía tres.
///
/// Recorrer los registros y avisar a todos cuesta lo mismo y no depende de qué
/// worker controle la página ni de bajo qué ámbito se registró cada uno. El que
/// no entienda el mensaje lo ignora.
void _avisarAlWorker(int cuenta) {
  unawaited(_repartirAlosWorkers(cuenta));
}

Future<void> _repartirAlosWorkers(int cuenta) async {
  try {
    final JSArray<web.ServiceWorkerRegistration> registros = await web
        .window
        .navigator
        .serviceWorker
        .getRegistrations()
        .toDart;

    final JSAny? aviso = <String, Object>{
      'tipo': 'sian:insignia',
      'cuenta': cuenta,
    }.jsify();

    for (final web.ServiceWorkerRegistration registro in registros.toDart) {
      registro.active?.postMessage(aviso);
    }
  } on Object catch (_) {
    // Puede no haber ninguno todavía en la primera carga. No es un problema:
    // la próxima sincronización lo alcanza.
  }
}
