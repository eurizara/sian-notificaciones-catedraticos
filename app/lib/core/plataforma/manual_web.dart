/// SIAN — Abre el manual (DT-28).
///
/// ────────────────────────────────────────────────────────────────────────────
/// En el navegador, en una pestaña aparte, y el nombre del botón lo avisa.
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
///
/// ────────────────────────────────────────────────────────────────────────────
/// Instalada, en la MISMA ventana, a propósito.
/// ────────────────────────────────────────────────────────────────────────────
///
/// En la aplicación instalada en iPhone no hay pestañas: el manual está dentro
/// del alcance de la aplicación, así que iOS lo abría en la misma ventana, sin
/// barra del navegador y sin forma de volver. Se vio el 11 de septiembre de
/// 2026: la única salida era cerrar la aplicación.
///
/// Así que instalada se navega a propósito en la misma ventana —con lo que el
/// gesto de atrás de Android vuelve a la aplicación— y el manual enseña su
/// propio botón «Volver a SIAN», que es lo que en iPhone hace falta.
library;

import 'package:web/web.dart' as web;

import 'deteccion_navegador.dart';

void abrirManual(String ruta) {
  if (manualSeAbreEnOtraPestana()) {
    web.window.open(ruta, '_blank', 'noopener');
  } else {
    web.window.location.assign(ruta);
  }
}

/// En el navegador sí; instalada, no.
bool manualSeAbreEnOtraPestana() => !detectarEntorno().instalada;
