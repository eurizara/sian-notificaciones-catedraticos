/// SIAN — `localStorage`, con las dos salidas de emergencia que necesita.
///
/// Leer o escribir puede lanzar: Safari en navegación privada, o un navegador
/// con los datos de sitios bloqueados. Una preferencia de apariencia no merece
/// que la aplicación falle al arrancar, así que si no se puede, se sigue con el
/// valor por omisión y no se guarda.
library;

import 'package:web/web.dart' as web;

String? leerLocal(String clave) {
  try {
    return web.window.localStorage.getItem(clave);
  } catch (_) {
    return null;
  }
}

void guardarLocal(String clave, String valor) {
  try {
    web.window.localStorage.setItem(clave, valor);
  } catch (_) {
    // Sin almacén: la elección vale para esta sesión y se olvida al cerrar.
  }
}
