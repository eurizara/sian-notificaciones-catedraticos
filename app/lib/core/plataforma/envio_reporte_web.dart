/// SIAN — Envío de reportes en el navegador.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> enviarReporte(String direccion, String cuerpo) async {
  try {
    await web.window
        .fetch(
          direccion.toJS,
          web.RequestInit(
            method: 'POST',
            headers:
                <String, String>{'Content-Type': 'application/json'}.jsify()!
                    as web.HeadersInit,
            body: cuerpo.toJS,
            // Que salga aunque la página se esté cerrando.
            keepalive: true,
          ),
        )
        .toDart;
  } on Object {
    // Sin red o servidor caído: el reporte se pierde, y está bien.
  }
}
