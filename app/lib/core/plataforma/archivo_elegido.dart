/// Archivo elegido por la persona, sin dependencias de plataforma.
library;

import 'dart:typed_data';

class ArchivoElegido {
  const ArchivoElegido({
    required this.bytes,
    required this.tipoMime,
    required this.nombre,
  });

  final Uint8List bytes;
  final String tipoMime;
  final String nombre;
}
