/// SIAN — Abre el manual en una pestaña nueva (DT-28).
///
/// ────────────────────────────────────────────────────────────────────────────
/// En una pestaña aparte, y el nombre del botón lo avisa.
/// ────────────────────────────────────────────────────────────────────────────
///
/// El manual se lee mientras se usa la aplicación: sustituirla por él obligaría
/// a elegir entre leer y hacer. Pero un cambio de contexto sin anunciar es de lo
/// que más desorienta a quien navega sin ver la pantalla (WCAG 3.2.5), así que
/// el texto del botón dice que se abre aparte.
///
/// `noopener` impide que la pestaña nueva pueda tocar la aplicación desde
/// `window.opener`. El manual es nuestro, pero no cuesta nada no dejar esa
/// puerta abierta.
library;

import 'package:web/web.dart' as web;

void abrirManual(String ruta) {
  web.window.open(ruta, '_blank', 'noopener');
}
