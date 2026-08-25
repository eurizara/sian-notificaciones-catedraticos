/// Insignia real, sobre la Badging API del navegador.
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
library;

import 'dart:js_interop';
// `has` —comprobar si una propiedad existe— vive aquí, no en `dart:js_interop`.
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Vista sobre `navigator` con los dos métodos de la Badging API.
///
/// `package:web` todavía no los declara, así que se describen aquí en lugar de
/// esperar a que aparezcan.
extension type _NavegadorConInsignia._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> setAppBadge(int cuenta);
  external JSPromise<JSAny?> clearAppBadge();
}

/// ¿Este navegador sabe pintar insignias?
///
/// Se comprueba la existencia del método en lugar de deducirlo del navegador o
/// de su versión: la lista de quién lo soporta cambia sola con el tiempo, y una
/// comprobación por nombre nunca se queda vieja.
bool get insigniaSoportada =>
    (web.window.navigator as JSObject).has('setAppBadge');

/// Pinta [cuenta] sobre el icono. Con cero, retira la insignia.
///
/// Los fallos se tragan a propósito. Pintar un número es un adorno útil, no
/// parte de la entrega del mensaje: si el navegador se niega —porque la
/// aplicación no está instalada, o porque el sistema no lo permite—, la bandeja
/// ya muestra el mismo dato y nada se pierde. Reventar aquí sí rompería algo.
void fijarInsignia(int cuenta) {
  if (!insigniaSoportada) {
    return;
  }
  if (cuenta <= 0) {
    retirarInsignia();
    return;
  }
  try {
    (web.window.navigator as _NavegadorConInsignia).setAppBadge(cuenta);
  } on Object catch (_) {
    // Silencio deliberado: ver la nota de arriba.
  }
}

/// Quita la insignia del icono.
void retirarInsignia() {
  if (!insigniaSoportada) {
    return;
  }
  try {
    (web.window.navigator as _NavegadorConInsignia).clearAppBadge();
  } on Object catch (_) {
    // Silencio deliberado: ver la nota de arriba.
  }
}
