/// Guarda en el aparato una imagen de un aviso (U-3).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Dos caminos, porque iPhone no deja descargar dentro de una app instalada
/// ────────────────────────────────────────────────────────────────────────────
///
///   · **Android y computadora:** se guarda como archivo, con un enlace de
///     descarga sobre los bytes ya bajados. No se usa la dirección de Storage
///     directamente: es de otro dominio y el navegador ignoraría el nombre.
///   · **iPhone:** se abre el menú Compartir de iOS con la imagen, que ofrece
///     **«Guardar imagen»**. Es lo que hace cualquier app nativa, y dentro de
///     una PWA instalada es lo único que funciona.
///
/// Safari solo deja abrir Compartir **en el mismo gesto** que lo pide: si la
/// imagen se baja después del toque, lo bloquea por falta de «activación del
/// usuario». Por eso se prepara antes —al abrir la imagen ampliada— y el botón
/// solo la entrega.
///
/// El bucket ya permite leer desde los tres dominios (`storage.cors.json`).
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

class ImagenPreparada {
  const ImagenPreparada(this.blob, this.nombre);
  final web.Blob blob;
  final String nombre;
}

Future<ImagenPreparada?> prepararImagen(String url, String nombre) async {
  try {
    final web.Response r = await web.window.fetch(url.toJS).toDart;
    if (!r.ok) {
      return null;
    }
    final web.Blob blob = await r.blob().toDart;
    return ImagenPreparada(blob, _conExtension(nombre, blob.type));
  } on Object {
    return null;
  }
}

Future<bool> guardarImagen(
  ImagenPreparada imagen, {
  required bool compartir,
}) async {
  try {
    if (compartir) {
      final web.File archivo = web.File(
        <web.BlobPart>[imagen.blob].toJS,
        imagen.nombre,
        web.FilePropertyBag(type: imagen.blob.type),
      );
      final web.ShareData datos = web.ShareData(
        files: <web.File>[archivo].toJS,
      );
      if (web.window.navigator.canShare(datos)) {
        await web.window.navigator.share(datos).toDart;
        return true;
      }
      // Sin Compartir con archivos, se intenta la descarga normal.
    }
    final String url = web.URL.createObjectURL(imagen.blob);
    final web.HTMLAnchorElement a =
        web.document.createElement('a') as web.HTMLAnchorElement
          ..href = url
          ..download = imagen.nombre
          ..style.display = 'none';
    web.document.body?.append(a);
    a.click();
    a.remove();
    // Se suelta después: revocarlo en el acto cancela la descarga en Safari.
    Future<void>.delayed(
      const Duration(seconds: 30),
      () => web.URL.revokeObjectURL(url),
    );
    return true;
  } on Object {
    // Cancelar el menú Compartir también llega aquí: no es un error que
    // haya que contarle a nadie.
    return false;
  }
}

String _conExtension(String nombre, String tipo) {
  if (RegExp(r'\.[A-Za-z0-9]{2,5}$').hasMatch(nombre)) {
    return nombre;
  }
  final String ext = switch (tipo) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };
  return '$nombre.$ext';
}
