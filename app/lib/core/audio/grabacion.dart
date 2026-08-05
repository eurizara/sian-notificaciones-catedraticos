/// SIAN — Nota de voz recién grabada, antes de subirse (RF-MSG-03, RF-MSG-07).
///
/// Sin dependencias de plataforma a propósito: es lo que cruza la frontera
/// entre el navegador y el resto de la aplicación, y el dominio no tiene por
/// qué saber que existe `MediaRecorder`.
library;

import 'dart:typed_data';

/// Límites de RF-MSG-07. Duplicados del dominio de TypeScript, que es la
/// fuente de verdad: aquí solo sirven para avisar antes de subir 2 MB en balde.
abstract final class LimitesVoz {
  static const int maxSegundos = 60;
  static const int maxBytes = 2 * 1024 * 1024;
}

class Grabacion {
  const Grabacion({
    required this.bytes,
    required this.tipoMime,
    required this.duracionSeg,
  });

  final Uint8List bytes;
  final String tipoMime;
  final int duracionSeg;

  bool get excedeDuracion => duracionSeg > LimitesVoz.maxSegundos;
  bool get excedePeso => bytes.length > LimitesVoz.maxBytes;
  bool get esValida => !excedeDuracion && !excedePeso && bytes.isNotEmpty;
}

/// Motivo por el que no se pudo grabar. Cada uno se resuelve distinto, así que
/// no se pueden mezclar en un «no se pudo».
enum FalloGrabacion { sinSoporte, permisoDenegado, sinMicrofono, error }

/// Grabadora de notas de voz.
///
/// La implementación real vive tras importación condicional: `dart:js_interop`
/// no existe en la máquina virtual donde corren las pruebas.
abstract interface class Grabadora {
  /// ¿Este navegador puede grabar?
  bool get soportada;

  bool get grabando;

  /// Segundos transcurridos. Se cuenta aquí y no se deduce del archivo: leer
  /// la duración de un blob de audio en el navegador es poco fiable, y el
  /// límite de 60 segundos tiene que avisarse **mientras** se graba.
  int get segundos;

  /// Empieza a grabar. Pide el permiso del micrófono si hace falta.
  Future<FalloGrabacion?> iniciar();

  /// Detiene y devuelve lo grabado. `null` si no había nada.
  Future<Grabacion?> detener();

  /// Descarta lo grabado y suelta el micrófono.
  Future<void> cancelar();

  /// Libera recursos.
  void liberar();
}
