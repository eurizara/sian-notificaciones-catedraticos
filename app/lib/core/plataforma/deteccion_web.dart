/// Detección del entorno dentro del navegador.
///
/// Se accede a las propiedades por interoperabilidad tipada y no con `eval`:
/// una PWA debería poder servirse bajo una política de seguridad de contenido
/// estricta, y `eval` la rompería.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../navegador.dart';

EntornoNavegador detectarEntorno() {
  final String ua = web.window.navigator.userAgent;
  final String uaMin = ua.toLowerCase();

  final bool esIos =
      uaMin.contains('iphone') ||
      uaMin.contains('ipad') ||
      uaMin.contains('ipod') ||
      // iPadOS 13+ se presenta como Macintosh con pantalla táctil.
      (uaMin.contains('macintosh') && web.window.navigator.maxTouchPoints > 1);

  final PlataformaWeb plataforma = esIos
      ? PlataformaWeb.ios
      : uaMin.contains('android')
      ? PlataformaWeb.android
      : PlataformaWeb.escritorio;

  return EntornoNavegador(
    plataforma: plataforma,
    instalada: _estaInstalada(),
    navegador: _nombreDeNavegador(uaMin),
    soportaNotificaciones: _tieneNotificaciones(),
    versionIos: esIos ? _versionIos(ua) : null,
  );
}

/// Instalada en la pantalla de inicio.
///
/// `display-mode: standalone` es el criterio estándar; Safari en iOS expone
/// además `navigator.standalone`, que es el que de verdad responde en las
/// versiones antiguas.
bool _estaInstalada() {
  final bool porDisplayMode = web.window
      .matchMedia('(display-mode: standalone)')
      .matches;
  return porDisplayMode || _safariStandalone();
}

String _nombreDeNavegador(String uaMin) {
  // El orden importa: casi todos se declaran «Safari» y «Chrome» además de
  // lo suyo, así que se comprueba de lo más específico a lo más genérico.
  if (uaMin.contains('vivaldi')) return 'Vivaldi';
  if (uaMin.contains('edg/')) return 'Edge';
  if (uaMin.contains('opr/') || uaMin.contains('opera')) return 'Opera';
  if (uaMin.contains('brave')) return 'Brave';
  if (uaMin.contains('firefox') || uaMin.contains('fxios')) return 'Firefox';
  if (uaMin.contains('crios') || uaMin.contains('chrome')) return 'Chrome';
  if (uaMin.contains('safari')) return 'Safari';
  return 'Navegador desconocido';
}

int? _versionIos(String ua) {
  final RegExpMatch? m = RegExp(r'OS (\d+)[_\.]').firstMatch(ua);
  if (m == null) {
    return null;
  }
  return int.tryParse(m.group(1) ?? '');
}

/// `window.Notification` existe.
///
/// Se comprueba en vez de asumirse: Safari en iOS solo la expone a partir de
/// la 16.4, y únicamente con la PWA instalada en la pantalla de inicio.
///
/// Se accede por interoperabilidad tipada y no con `eval`: una PWA debería
/// poder servirse bajo una política de seguridad de contenido estricta, y
/// `eval` la rompería.
bool _tieneNotificaciones() => globalContext.has('Notification');

/// `navigator.standalone` — propiedad exclusiva de Safari en iOS, y la que de
/// verdad responde en las versiones antiguas.
bool _safariStandalone() {
final JSObject? nav = globalContext.getProperty<JSObject?>('navigator'.toJS);
if (nav == null || !nav.has('standalone')) {
  return false;
}
return nav.getProperty<JSAny?>('standalone'.toJS)?.dartify() == true;
}
