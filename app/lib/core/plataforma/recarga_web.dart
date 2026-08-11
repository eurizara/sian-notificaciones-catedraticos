/// Recarga real, sobre `location.reload()`.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Es la recarga del navegador, no un `setState`.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Volver a pedir los datos desde dentro dejaría intacto todo lo demás: el
/// paquete ya descargado, el trabajador de servicio, el estado acumulado de la
/// sesión. Y justo eso es lo que alguien quiere descartar cuando siente que la
/// pantalla «se quedó pegada».
///
/// Una recarga de verdad también trae la versión desplegada más reciente, que
/// en una aplicación instalada puede llevar días sin renovarse.
library;

import 'package:web/web.dart' as web;

void recargarAplicacion() {
  web.window.location.reload();
}
