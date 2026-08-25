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

extension type _ControladorSw._(JSObject _) implements JSObject {
  external void postMessage(JSAny? mensaje);
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
void _avisarAlWorker(int cuenta) {
  try {
    final JSObject? controlador =
        web.window.navigator.serviceWorker.controller as JSObject?;
    if (controlador == null) {
      return;
    }
    (controlador as _ControladorSw).postMessage(
      <String, Object>{'tipo': 'sian:insignia', 'cuenta': cuenta}.jsify(),
    );
  } on Object catch (_) {
    // El worker puede no estar controlando todavía (primera carga, o recarga
    // dura). No es un problema: la próxima sincronización lo alcanza.
  }
}
