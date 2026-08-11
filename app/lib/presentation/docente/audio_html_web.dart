/// Reproductor sobre el elemento `<audio>` del navegador.
///
/// Se usa el nativo y no uno propio por dos razones que pesan más que el
/// aspecto: entiende tanto el `audio/mp4` que graba Safari como el
/// `audio/webm` de Chrome —y no hay un formato que ambos produzcan—, y trae
/// resueltos el teclado y el lector de pantalla. Reimplementarlo sería trabajo
/// para quedar peor.
///
/// ────────────────────────────────────────────────────────────────────────────
/// UNA GRABACIÓN DE `MediaRecorder` NO SABE CUÁNTO DURA.
/// ────────────────────────────────────────────────────────────────────────────
///
/// El WebM que produce `MediaRecorder` se escribe sobre la marcha, así que su
/// cabecera se cierra sin la duración: el navegador la lee como infinita y sin
/// tramo reproducible. El efecto es exactamente el que se ve al recibir un
/// aviso: **se pulsa reproducir y no suena**, y solo después de rebobinar o de
/// volver a pulsar empieza a oírse.
///
/// En una nota de voz de emergencia eso es grave: quien la recibe concluye que
/// el audio está roto y sigue adelante sin escucharlo.
///
/// Se corrige con las dos piezas de abajo, y hacen falta las dos.
library;

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Vistas ya registradas. Registrar dos veces el mismo identificador lanza.
final Set<String> _registradas = <String>{};

/// Un instante inalcanzable, para obligar al navegador a buscar el final.
///
/// Al pedir una posición imposible, el navegador recorre el archivo hasta
/// donde de verdad termina y con eso descubre la duración real. Es el rodeo
/// habitual para las grabaciones sin cabecera completa; no hay una forma
/// directa de pedírselo.
const double _masAlladelFinal = 1e101;

class ReproductorAudio extends StatelessWidget {
  const ReproductorAudio({required this.url, super.key});

  final String url;

  /// Identificador estable por URL: así una reconstrucción reutiliza el mismo
  /// elemento y no reinicia la reproducción a mitad.
  String get _tipo => 'sian-audio-${url.hashCode}';

  @override
  Widget build(BuildContext context) {
    if (_registradas.add(_tipo)) {
      ui_web.platformViewRegistry.registerViewFactory(_tipo, (int _) {
        final web.HTMLAudioElement audio =
            web.document.createElement('audio') as web.HTMLAudioElement;
        audio
          ..src = url
          ..controls = true
          // ────────────────────────────────────────────────────────────────
          // PIEZA 1: se descarga entera, no solo la cabecera.
          // ────────────────────────────────────────────────────────────────
          //
          // Antes era `metadata`, para no gastar datos móviles en un audio
          // que quizá nadie escuche. Pero de una grabación sin duración la
          // cabecera sola no dice nada útil, y el primer intento de
          // reproducción se pierde.
          //
          // El coste está acotado: una nota de voz no pasa de 60 segundos ni
          // de 2 MB (RF-MSG-07), y esto solo ocurre cuando alguien despliega
          // el mensaje, es decir cuando ya quiere escucharlo. La imagen, que
          // sí puede pesar 5 MB, sigue detrás de su botón.
          ..preload = 'auto';
        audio.style
          ..width = '100%'
          ..height = '54px';

        // ──────────────────────────────────────────────────────────────────
        // PIEZA 2: se le saca la duración antes de que nadie pulse.
        // ──────────────────────────────────────────────────────────────────
        //
        // Se hace una sola vez, al conocerse los metadatos, y solo si la
        // duración llegó rota. Después se vuelve al principio, de modo que
        // quien pulse reproducir empiece donde espera empezar.
        bool arreglada = false;

        audio.onloadedmetadata = ((web.Event _) {
          if (arreglada || audio.duration.isFinite) {
            return;
          }
          arreglada = true;

          audio.ontimeupdate = ((web.Event _) {
            audio.ontimeupdate = null;
            audio.currentTime = 0;
          }).toJS;

          audio.currentTime = _masAlladelFinal;
        }).toJS;

        return audio as JSObject;
      });
    }

    return HtmlElementView(viewType: _tipo);
  }
}
