/// Proveedores de los catálogos (2.0): sedes y facultades.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infrastructure/firebase/repositorio_catalogos.dart';

/// Las sedes. Las pruebas lo sustituyen por una fuente en memoria.
final Provider<FuenteCatalogo> fuenteSedesProvider = Provider<FuenteCatalogo>(
  (Ref ref) => FuenteSedes(),
);

/// Las facultades de una sede.
final fuenteFacultadesProvider = Provider.family<FuenteCatalogo, String>(
  (Ref ref, String sedeId) => FuenteFacultades(sedeId),
);

/// El nombre visible de una sede («Boca del Monte»), o nulo si no se pudo leer.
final nombreDeSedeProvider = FutureProvider.family<String?, String>((
  Ref ref,
  String sedeId,
) async {
  try {
    final DocumentSnapshot<Map<String, dynamic>> d = await FirebaseFirestore
        .instance
        .doc('sedes/$sedeId')
        .get();
    return d.data()?['nombre'] as String?;
  } on Object {
    return null;
  }
});
