/// Implementación para navegador, sobre `MediaRecorder`.
///
/// ────────────────────────────────────────────────────────────────────────────
/// El micrófono se suelta SIEMPRE, incluso si algo falla a mitad.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Un `MediaStream` que queda abierto deja el indicador de grabación encendido
/// en el teléfono. En una aplicación institucional que un catedrático crea que
/// le están escuchando es un problema serio, y no se arregla explicándolo
/// después.
///
/// El formato lo elige el navegador. Safari entrega `audio/mp4` y Chrome
/// `audio/webm`, y no hay uno que ambos produzcan: se guarda el que salga y se
/// reproduce con el mismo `<audio>`, que sí entiende los dos.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../plataforma/consola.dart';
import 'grabacion.dart';

Grabadora crearGrabadora() => _GrabadoraWeb();

/// Formatos que se intentan, en orden de preferencia.
///
/// Se prueba antes de grabar: pedir uno que el navegador no admita produce un
/// archivo vacío sin ningún error, que es la peor forma de fallar.
const List<String> _formatos = <String>[
  'audio/webm;codecs=opus',
  'audio/webm',
  'audio/mp4',
  'audio/ogg;codecs=opus',
];

class _GrabadoraWeb implements Grabadora {
  web.MediaRecorder? _grabadora;
  web.MediaStream? _flujo;
  final List<web.Blob> _trozos = <web.Blob>[];
  final Stopwatch _reloj = Stopwatch();
  String _tipoMime = 'audio/webm';
  Completer<Grabacion?>? _pendiente;

  @override
  bool get soportada =>
      globalContext
          .getProperty<JSObject?>('navigator'.toJS)
          ?.has('mediaDevices') ??
      false;

  @override
  bool get grabando => _grabadora != null;

  @override
  int get segundos => _reloj.elapsed.inSeconds;

  String? _formatoAdmitido() {
    for (final String f in _formatos) {
      if (web.MediaRecorder.isTypeSupported(f)) {
        return f;
      }
    }
    return null;
  }

  @override
  Future<FalloGrabacion?> iniciar() async {
    if (!soportada) {
      return FalloGrabacion.sinSoporte;
    }

    try {
      _flujo = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
          .toDart;
    } on Object catch (e) {
      final String detalle = '$e';
      consolaError('SIAN.voz permiso | $detalle');
      // Se distinguen los dos motivos: uno se arregla en los ajustes del
      // navegador y el otro conectando un micrófono.
      return detalle.contains('NotFound') || detalle.contains('DevicesNotFound')
          ? FalloGrabacion.sinMicrofono
          : FalloGrabacion.permisoDenegado;
    }

    final String? formato = _formatoAdmitido();
    if (formato == null) {
      await _soltarMicrofono();
      return FalloGrabacion.sinSoporte;
    }
    _tipoMime = formato.split(';').first;

    try {
      final web.MediaRecorder r = web.MediaRecorder(
        _flujo!,
        web.MediaRecorderOptions(mimeType: formato),
      );

      _trozos.clear();
      r.ondataavailable = (web.BlobEvent evento) {
        if (evento.data.size > 0) {
          _trozos.add(evento.data);
        }
      }.toJS;

      r.onstop = ((web.Event _) {
        unawaited(_armar());
      }).toJS;

      _grabadora = r;
      _reloj
        ..reset()
        ..start();
      r.start();
      return null;
    } on Object catch (e) {
      consolaError('SIAN.voz inicio | $e');
      await _soltarMicrofono();
      return FalloGrabacion.error;
    }
  }

  @override
  Future<Grabacion?> detener() async {
    final web.MediaRecorder? r = _grabadora;
    if (r == null) {
      return null;
    }

    _reloj.stop();
    final Completer<Grabacion?> completer = Completer<Grabacion?>();
    _pendiente = completer;

    try {
      r.stop();
    } on Object catch (e) {
      consolaError('SIAN.voz detener | $e');
      await _soltarMicrofono();
      return null;
    }

    return completer.future;
  }

  /// Junta los trozos en una sola grabación y suelta el micrófono.
  Future<void> _armar() async {
    final Completer<Grabacion?>? completer = _pendiente;
    _pendiente = null;
    _grabadora = null;

    try {
      if (_trozos.isEmpty) {
        completer?.complete(null);
        return;
      }

      final web.Blob blob = web.Blob(
        _trozos.map((web.Blob b) => b as JSAny).toList().toJS,
        web.BlobPropertyBag(type: _tipoMime),
      );

      final JSArrayBuffer buffer = await blob.arrayBuffer().toDart;
      final Uint8List bytes = buffer.toDart.asUint8List();

      completer?.complete(
        Grabacion(
          bytes: bytes,
          tipoMime: _tipoMime,
          // Al menos un segundo: un toque rápido produciría «0 s», que parece
          // un fallo aunque haya audio.
          duracionSeg: _reloj.elapsed.inSeconds.clamp(1, 3600),
        ),
      );
    } on Object catch (e) {
      consolaError('SIAN.voz armar | $e');
      completer?.complete(null);
    } finally {
      _trozos.clear();
      await _soltarMicrofono();
    }
  }

  @override
  Future<void> cancelar() async {
    final web.MediaRecorder? r = _grabadora;
    _grabadora = null;
    _pendiente = null;
    _reloj.stop();

    if (r != null) {
      try {
        r.stop();
      } on Object catch (_) {
        // Da igual por qué no se detuvo: lo que no puede quedarse es el
        // micrófono abierto.
      }
    }
    _trozos.clear();
    await _soltarMicrofono();
  }

  /// Apaga todas las pistas del flujo.
  ///
  /// Es lo que apaga el indicador de grabación del sistema. Sin esto, el
  /// teléfono sigue diciendo que la aplicación está escuchando.
  Future<void> _soltarMicrofono() async {
    final web.MediaStream? flujo = _flujo;
    _flujo = null;
    if (flujo == null) {
      return;
    }
    for (final web.MediaStreamTrack pista in flujo.getTracks().toDart) {
      pista.stop();
    }
  }

  @override
  void liberar() {
    unawaited(cancelar());
  }
}
