/// SIAN — Los fallos del aparato llegan al servidor (DT-34).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Lo que falla en el aparato solo llegaba a su consola, que nadie ve.
/// ────────────────────────────────────────────────────────────────────────────
///
/// El 12/09/2026 el registro de dispositivos se colgó en todos los aparatos y
/// el servidor no registró un solo error: se supo porque un aviso de prueba no
/// llegó. Desde aquí, cada uno de esos fallos manda un reporte mínimo a la
/// función `reportarFallo`, y coordinación ve el total en Alcance.
///
/// Lo que se manda: qué falló (de una lista cerrada), la versión, la
/// plataforma y un identificador de aparato **al azar**, que no está ligado a
/// ninguna persona. El detalle técnico se limpia **aquí**, antes de salir.
///
/// Nunca lanza, nunca espera y nunca insiste: el mismo tipo de fallo, como
/// mucho una vez cada 10 minutos. Un reporte que no se pudo mandar se pierde,
/// y está bien: lo importante es que la aplicación siga funcionando.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'navegador.dart';
import 'plataforma/almacen_local.dart';
import 'plataforma/envio_reporte.dart';
import 'version.dart';

/// Qué puede fallar. Tiene que coincidir con `TIPOS_DE_FALLO` de las
/// funciones: una prueba compara las dos listas.
enum TipoDeFallo {
  arranque('arranque'),
  registroDispositivo('registro-dispositivo'),
  suscripcionPropia('suscripcion-propia'),
  worker('worker'),
  notificacion('notificacion'),
  appCheck('app-check'),
  noControlado('no-controlado');

  const TipoDeFallo(this.clave);

  final String clave;
}

const int _largoDeDetalle = 200;

/// El detalle técnico, sin nada que identifique a alguien.
///
/// Las mismas reglas que `limpiarDetalle` de las funciones, que lo vuelve a
/// aplicar: un correo, un número largo, una clave o la ruta de una dirección
/// no salen del aparato.
String limpiarDetalle(Object? error) {
  if (error == null) {
    return '';
  }
  final String limpio = '$error'
      .replaceAllMapped(
        RegExp(r'\bhttps?://([^/\s?#]+)\S*', caseSensitive: false),
        (Match m) => 'https://${m[1]}/…',
      )
      .replaceAll(RegExp(r'[\w.+-]+@[\w-]+(?:\.[\w-]+)+'), '[correo]')
      .replaceAll(RegExp(r'[A-Za-z0-9_-]{24,}'), '[clave]')
      .replaceAllMapped(
        RegExp(r'\+?\d[\d\s-]{4,}\d'),
        (Match m) => m[0]!.replaceAll(RegExp(r'\D'), '').length >= 6
            ? '[número]'
            : m[0]!,
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return limpio.length <= _largoDeDetalle
      ? limpio
      : '${limpio.substring(0, _largoDeDetalle - 1)}…';
}

/// La función `reportarFallo` del ambiente, o la del emulador.
String direccionDeReporte({
  required String proyecto,
  required bool usaEmulador,
}) => usaEmulador
    ? 'http://localhost:5001/$proyecto/us-central1/reportarFallo'
    : 'https://us-central1-$proyecto.cloudfunctions.net/reportarFallo';

abstract final class ReporteDeFallos {
  static const Duration intervalo = Duration(minutes: 10);
  static const String _claveAparato = 'sian.aparato';

  static String? _direccion;
  static final Map<TipoDeFallo, DateTime> _ultimos = <TipoDeFallo, DateTime>{};

  /// Se llama al arrancar, antes que Firebase: si Firebase no arranca, ese
  /// es justo el fallo que más interesa saber.
  static void configurar({
    required String proyecto,
    required bool usaEmulador,
  }) {
    _direccion = direccionDeReporte(
      proyecto: proyecto,
      usaEmulador: usaEmulador,
    );
  }

  /// Anota el fallo y lo manda, sin esperar ni lanzar.
  static void reportar(TipoDeFallo tipo, [Object? error, DateTime? ahora]) {
    try {
      final String? direccion = _direccion;
      if (direccion == null) {
        return;
      }
      final DateTime cuando = ahora ?? DateTime.now();
      final DateTime? anterior = _ultimos[tipo];
      if (anterior != null && cuando.difference(anterior) < intervalo) {
        return;
      }
      _ultimos[tipo] = cuando;

      final String cuerpo = jsonEncode(<String, String>{
        'que': tipo.clave,
        'version': versionSian,
        'plataforma': EntornoNavegador.detectar().plataformaPersistida,
        'aparato': _aparato(),
        'detalle': limpiarDetalle(error),
      });
      unawaited(enviarReporte(direccion, cuerpo));
    } on Object {
      // Reportar un fallo no puede convertirse en otro.
    }
  }

  /// Un identificador al azar, guardado en este navegador. No sale de ninguna
  /// cuenta ni se puede ligar a una: solo sirve para contar aparatos.
  static String _aparato() {
    final String? guardado = leerLocal(_claveAparato);
    if (guardado != null &&
        RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(guardado)) {
      return guardado;
    }
    const String letras =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final Random azar = Random.secure();
    final String nuevo = String.fromCharCodes(
      Iterable<int>.generate(
        22,
        (_) => letras.codeUnitAt(azar.nextInt(letras.length)),
      ),
    );
    guardarLocal(_claveAparato, nuevo);
    return nuevo;
  }

  @visibleForTesting
  static void reiniciar({bool conservarConfiguracion = false}) {
    if (!conservarConfiguracion) {
      _direccion = null;
    }
    _ultimos.clear();
  }
}
