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

/// Tipo deducido de la extensión, para cuando el navegador no lo dice.
///
/// ────────────────────────────────────────────────────────────────────────────
/// `File.type` puede llegar vacío, y eso NO significa que el archivo sea malo.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Pasa con archivos servidos desde algunas galerías y gestores de archivos:
/// el navegador entrega el contenido pero no sabe decir qué es. Con la cadena
/// vacía, la validación lo rechaza por «formato no admitido» —un JPEG perfecto
/// rechazado por no llevar etiqueta— y quien lo intenta no tiene forma de
/// entender por qué.
String _tipoPorNombre(String nombre) {
  final String n = nombre.toLowerCase();
  if (n.endsWith('.png')) {
    return 'image/png';
  }
  if (n.endsWith('.webp')) {
    return 'image/webp';
  }
  if (n.endsWith('.jpg') || n.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  return '';
}

Future<ArchivoElegido?> elegirImagen() async {
  final Completer<ArchivoElegido?> completer = Completer<ArchivoElegido?>();

  final web.HTMLInputElement entrada =
      web.document.createElement('input') as web.HTMLInputElement;
  entrada.type = 'file';
  // Los tres formatos que admite RF-MSG-08. Filtrar aquí evita que alguien
  // elija un PDF y descubra el rechazo después de esperar la subida.
  entrada.accept = 'image/jpeg,image/png,image/webp';

  // ──────────────────────────────────────────────────────────────────────────
  // HAY ELECCIÓN EN CURSO: `cancel` YA NO PUEDE HABLAR.
  // ──────────────────────────────────────────────────────────────────────────
  //
  // Leer el archivo es asíncrono, así que entre `change` y el momento de
  // entregar el resultado hay un hueco. Si `cancel` llega en ese hueco —y los
  // navegadores lo disparan al cerrarse el diálogo, no solo al desistir—,
  // completa con `null` primero y la imagen recién elegida se pierde **sin
  // decir nada**: ni error, ni tarjeta, ni rastro. La persona ve que pulsó,
  // que eligió, y que no pasó nada.
  //
  // Esta bandera se pone al recibir `change`, antes de cualquier `await`, que
  // es lo único que garantiza ganar la carrera.
  bool eligiendo = false;

  entrada.onchange = ((web.Event _) {
    eligiendo = true;
    unawaited(() async {
      try {
        final web.FileList? archivos = entrada.files;
        if (archivos == null || archivos.length == 0) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
          return;
        }

        final web.File archivo = archivos.item(0)!;
        final JSArrayBuffer buffer = await archivo.arrayBuffer().toDart;

        if (!completer.isCompleted) {
          completer.complete(
            ArchivoElegido(
              bytes: buffer.toDart.asUint8List(),
              tipoMime: archivo.type.isEmpty
                  ? _tipoPorNombre(archivo.name)
                  : archivo.type,
              nombre: archivo.name,
            ),
          );
        }
      } on Object catch (e) {
        consolaError('SIAN.imagen lectura | $e');
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }
    }());
  }).toJS;

  // Si se cierra el diálogo sin elegir, `change` no llega nunca. `cancel` sí,
  // en los navegadores que lo implementan; en los que no, quien llama
  // simplemente sigue esperando hasta que se vuelva a intentar.
  entrada.oncancel = ((web.Event _) {
    if (!eligiendo && !completer.isCompleted) {
      completer.complete(null);
    }
  }).toJS;

  entrada.click();
  return completer.future;
}
