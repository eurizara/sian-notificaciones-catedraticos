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

import 'dart:convert';
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

/// Cuánto vale un destino guardado por el worker. El mismo plazo que
/// `SEGUNDOS_DE_APERTURA` en `sw-decisiones.js`.
const Duration plazoDeApertura = Duration(seconds: 120);

/// Toma —lee y borra— el destino que el worker guardó al tocar una
/// notificación, si es reciente.
///
/// Es el camino que funciona en iPhone cuando el mensaje se pierde porque la app
/// estaba congelada, o cuando iOS la abre en su página inicial sin la dirección
/// con el destino (25/09/2026). Se borra al leerlo: se abre una sola vez aunque
/// también lleguen el mensaje o la dirección.
Future<Map<String, String>?> tomarAperturaGuardada() async {
  try {
    final web.Cache almacen = await web.window.caches.open('sian-apertura').toDart;
    final JSAny? respuesta = await almacen.match('/__sian/apertura'.toJS).toDart;
    if (respuesta == null || respuesta.isUndefinedOrNull) {
      return null;
    }
    final String texto = (await (respuesta as web.Response).text().toDart).toDart;
    await almacen.delete('/__sian/apertura'.toJS).toDart;

    final Object? dato = jsonDecode(texto);
    if (dato is! Map) {
      return null;
    }
    final Object? en = dato['en'];
    if (en is! num) {
      return null;
    }
    final Duration edad = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(en.toInt()),
    );
    if (edad > plazoDeApertura || edad < const Duration(minutes: -1)) {
      return null;
    }
    return <String, String>{
      for (final String clave in const <String>['abrir', 'aviso', 'hilo'])
        clave: '${dato[clave] ?? ''}',
    };
  } on Object {
    return null;
  }
}

