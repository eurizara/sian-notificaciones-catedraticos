/// Leer el destino con que se abrió la aplicación, y escuchar al worker.
///
/// Dos caminos, según si la aplicación ya estaba abierta al tocar la
/// notificación (C-6, DT-35):
///
///   · **Cerrada:** el worker la abre con el destino en la dirección
///     (`/?abrir=aviso&aviso=…`). Se lee al arrancar y se borra, para que
///     recargar no vuelva a abrir lo mismo.
///   · **Abierta:** el worker le manda `{tipo: 'sian:abrir', …}`. No puede
///     navegarla: no la controla, porque vive en otro alcance.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

Map<String, String> parametrosDeApertura() {
  try {
    return Map<String, String>.of(Uri.base.queryParameters);
  } on Object {
    return <String, String>{};
  }
}

void limpiarParametrosDeApertura() {
  try {
    // Se conserva el fragmento: es donde vive la ruta interna de Flutter.
    final String fragmento = web.window.location.hash;
    web.window.history.replaceState(null, '', '/$fragmento');
  } on Object {
    // Si no se puede, recargar volvería a abrir el mismo aviso: molesto, no
    // grave.
  }
}

void escucharAperturas(void Function(Map<String, String>) alAbrir) {
  try {
    web.window.navigator.serviceWorker.addEventListener(
      'message',
      (web.Event evento) {
        final Object? dato = (evento as web.MessageEvent).data?.dartify();
        if (dato is Map && dato['tipo'] == 'sian:abrir') {
          alAbrir(<String, String>{
            for (final MapEntry<Object?, Object?> e in dato.entries)
              '${e.key}': '${e.value ?? ''}',
          });
        }
      }.toJS,
    );
  } on Object {
    // Sin service worker no hay notificaciones que tocar.
  }
}
