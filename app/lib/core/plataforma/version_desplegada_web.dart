/// SIAN — Lee `/version.json`, que el despliegue sella en cada publicación.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Sin caché, o diría siempre lo que ya tenemos.
/// ────────────────────────────────────────────────────────────────────────────
///
/// La pregunta es «¿hay algo más nuevo que esto?», así que la respuesta no
/// puede venir del almacén del navegador ni del service worker: sería la misma
/// versión que está corriendo, contestando que está al día. De ahí
/// `cache: 'no-store'` y el parámetro que cambia en cada consulta.
///
/// Si falla —sin red, servidor caído— devuelve nulo, y la aplicación se calla:
/// no saber si hay una versión nueva no es lo mismo que saber que la hay.
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<String?> consultarVersionPublicada() async {
  try {
    final web.Response respuesta = await web.window
        .fetch(
          '/version.json?t=${DateTime.now().millisecondsSinceEpoch}'.toJS,
          web.RequestInit(cache: 'no-store'),
        )
        .toDart;
    if (!respuesta.ok) {
      return null;
    }
    final JSAny? cuerpo = await respuesta.json().toDart;
    final Object? mapa = cuerpo.dartify();
    if (mapa is Map && mapa['version'] is String) {
      return mapa['version'] as String;
    }
    return null;
  } on Object {
    return null;
  }
}
