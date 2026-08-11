/// SIAN — Subida de adjuntos a Cloud Storage (RF-MSG-03, 04, 07, 08).
///
/// ────────────────────────────────────────────────────────────────────────────
/// El identificador del mensaje se decide ANTES de subir nada.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Los adjuntos viven en `mensajes/{mensajeId}/…` y las reglas de Storage
/// dependen de esa ruta. Pero el mensaje lo crea la Cloud Function, después.
/// Se resuelve al revés: el cliente reserva el identificador, sube contra él, y
/// se lo pasa a la Function, que lo usa con `create` —falla si ya existe— para
/// que nadie pueda pisar un mensaje ajeno pasando su identificador.
///
/// Las validaciones se hacen aquí **y** en el dominio del servidor **y** en las
/// reglas de Storage. No es desconfianza del código propio: es que cada capa
/// protege de un ataque distinto, y la del cliente solo existe para no gastar
/// dos megas de datos móviles en una subida que iba a ser rechazada.
library;

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Límites de RF-MSG-08.
abstract final class LimitesImagen {
  static const int maxBytes = 5 * 1024 * 1024;
  static const List<String> mimes = <String>[
    'image/jpeg',
    'image/png',
    'image/webp',
  ];
}

/// Adjunto ya subido, tal como viaja a la Function.
class AdjuntoSubido {
  const AdjuntoSubido({
    required this.tipo,
    required this.ruta,
    required this.bytes,
    required this.tipoMime,
    this.duracionSeg,
  });

  /// `AUDIO` o `IMAGEN`.
  final String tipo;
  final String ruta;
  final int bytes;
  final String tipoMime;

  /// Solo para audio.
  final int? duracionSeg;

  Map<String, Object?> aMapa() => <String, Object?>{
    'tipo': tipo,
    'ruta': ruta,
    'bytes': bytes,
    'tipoMime': tipoMime,
    if (duracionSeg != null) 'duracionSeg': duracionSeg,
  };
}

class RepositorioAdjuntos {
  RepositorioAdjuntos({FirebaseStorage? storage, FirebaseFirestore? firestore})
    : _storageDado = storage,
      _firestoreDado = firestore;

  final FirebaseStorage? _storageDado;
  final FirebaseFirestore? _firestoreDado;

  late final FirebaseStorage _storage =
      _storageDado ?? FirebaseStorage.instance;
  late final FirebaseFirestore _db =
      _firestoreDado ?? FirebaseFirestore.instance;

  /// Reserva el identificador del mensaje antes de subir.
  ///
  /// Lo genera Firestore y no el cliente a mano: son identificadores con
  /// suficiente aleatoriedad como para que la ruta de un adjunto no sea
  /// adivinable, que es la mitigación parcial de DT-04.
  String reservarIdMensaje() => _db.collection('mensajes').doc().id;

  /// Sube la nota de voz.
  ///
  /// [orden] va en el nombre del archivo porque un mensaje puede llevar varios:
  /// con un nombre fijo, el segundo pisaría al primero — y las reglas prohíben
  /// sobrescribir (RN-09), así que la subida fallaría sin más explicación.
  Future<AdjuntoSubido> subirVoz({
    required String mensajeId,
    required Uint8List bytes,
    required String tipoMime,
    required int duracionSeg,
    int orden = 1,
  }) async {
    final String extension = tipoMime.contains('mp4') ? 'm4a' : 'webm';
    final Reference ref = _storage.ref(
      'mensajes/$mensajeId/$orden-voz.$extension',
    );

    await ref.putData(bytes, SettableMetadata(contentType: tipoMime));

    return AdjuntoSubido(
      tipo: 'AUDIO',
      ruta: ref.fullPath,
      bytes: bytes.length,
      tipoMime: tipoMime,
      duracionSeg: duracionSeg,
    );
  }

  /// Sube la imagen.
  Future<AdjuntoSubido> subirImagen({
    required String mensajeId,
    required Uint8List bytes,
    required String tipoMime,
    required String nombreOriginal,
    int orden = 1,
  }) async {
    final String extension = switch (tipoMime) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final Reference ref = _storage.ref(
      'mensajes/$mensajeId/$orden-imagen.$extension',
    );

    await ref.putData(bytes, SettableMetadata(contentType: tipoMime));

    return AdjuntoSubido(
      tipo: 'IMAGEN',
      ruta: ref.fullPath,
      bytes: bytes.length,
      tipoMime: tipoMime,
    );
  }

  /// URL temporal para reproducir o mostrar un adjunto.
  Future<String> urlDe(String ruta) => _storage.ref(ruta).getDownloadURL();
}

/// ¿Esta imagen se puede adjuntar? Devuelve el motivo si no.
///
/// Se comprueba antes de subir para no gastar los datos móviles de nadie en
/// una subida que las reglas de Storage van a rechazar igualmente.
String? motivoRechazoImagen({required int bytes, required String tipoMime}) {
  if (bytes <= 0) {
    return 'VACIA';
  }
  if (bytes > LimitesImagen.maxBytes) {
    return 'MUY_PESADA';
  }
  if (!LimitesImagen.mimes.contains(tipoMime)) {
    return 'FORMATO';
  }
  return null;
}
