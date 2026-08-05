/// Implementación para navegador, sobre `<input type="file">`.
///
/// El elemento se crea al vuelo y no se añade al documento: no tiene que
/// verse, solo abrir el diálogo del sistema. En móvil, `accept` con tipos de
/// imagen hace que el propio sistema ofrezca cámara o galería.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'archivo_elegido.dart';
import 'consola.dart';

Future<ArchivoElegido?> elegirImagen() async {
  final Completer<ArchivoElegido?> completer = Completer<ArchivoElegido?>();

  final web.HTMLInputElement entrada =
      web.document.createElement('input') as web.HTMLInputElement;
  entrada.type = 'file';
  // Los tres formatos que admite RF-MSG-08. Filtrar aquí evita que alguien
  // elija un PDF y descubra el rechazo después de esperar la subida.
  entrada.accept = 'image/jpeg,image/png,image/webp';

  entrada.onchange = ((web.Event _) {
    unawaited(() async {
      try {
        final web.FileList? archivos = entrada.files;
        if (archivos == null || archivos.length == 0) {
          completer.complete(null);
          return;
        }

        final web.File archivo = archivos.item(0)!;
        final JSArrayBuffer buffer = await archivo.arrayBuffer().toDart;

        completer.complete(
          ArchivoElegido(
            bytes: buffer.toDart.asUint8List(),
            tipoMime: archivo.type,
            nombre: archivo.name,
          ),
        );
      } on Object catch (e) {
        consolaError('SIAN.imagen lectura | $e');
        completer.complete(null);
      }
    }());
  }).toJS;

  // Si se cierra el diálogo sin elegir, `change` no llega nunca. `cancel` sí,
  // en los navegadores que lo implementan; en los que no, quien llama
  // simplemente sigue esperando hasta que se vuelva a intentar.
  entrada.oncancel = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  }).toJS;

  entrada.click();
  return completer.future;
}
