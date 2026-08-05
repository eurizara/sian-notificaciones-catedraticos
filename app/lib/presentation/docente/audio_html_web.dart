/// Reproductor sobre el elemento `<audio>` del navegador.
///
/// Se usa el nativo y no uno propio por dos razones que pesan más que el
/// aspecto: entiende tanto el `audio/mp4` que graba Safari como el
/// `audio/webm` de Chrome —y no hay un formato que ambos produzcan—, y trae
/// resueltos el teclado y el lector de pantalla. Reimplementarlo sería trabajo
/// para quedar peor.
library;

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Vistas ya registradas. Registrar dos veces el mismo identificador lanza.
final Set<String> _registradas = <String>{};

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
          // Nada se descarga hasta que alguien le da al play: un catedrático
          // con datos móviles no tiene por qué gastar en un audio que quizá
          // no escuche.
          ..preload = 'metadata';
        audio.style
          ..width = '100%'
          ..height = '54px';
        return audio as JSObject;
      });
    }

    return HtmlElementView(viewType: _tipo);
  }
}
