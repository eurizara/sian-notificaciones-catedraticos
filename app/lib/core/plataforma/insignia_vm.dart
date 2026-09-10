/// Sustituto para la máquina virtual: pruebas y herramientas.
///
/// No hay icono de aplicación fuera del navegador, así que no hay dónde pintar
/// la insignia. Se guarda lo último que se pidió, que es lo que una prueba
/// puede comprobar.
library;

/// Último valor pedido. `null` significa «insignia retirada».
///
/// ────────────────────────────────────────────────────────────────────────────
/// Cero se anota como `null` a propósito: es lo que hace la versión real.
/// ────────────────────────────────────────────────────────────────────────────
///
/// En el navegador, `fijarInsignia(0)` llama a `clearAppBadge()`, no pinta un
/// «0» sobre el icono. Un sustituto que anotara `0` estaría describiendo algo
/// que no ocurre, y las pruebas que lo usan quedarían comprobando una ficción.
int? insigniaPedida;

/// Cuántas veces se pidió, para distinguir «se pidió cero» de «no se pidió».
int vecesQueSePidioInsignia = 0;

/// Los identificadores que se mandaron la última vez (DT-26).
List<String> ultimosIdsSinLeer = const <String>[];

bool get insigniaSoportada => false;

void fijarInsignia(int cuenta, {List<String> idsSinLeer = const <String>[]}) {
  insigniaPedida = cuenta > 0 ? cuenta : null;
  ultimosIdsSinLeer = idsSinLeer;
  vecesQueSePidioInsignia += 1;
}

void retirarInsignia() => fijarInsignia(0);
