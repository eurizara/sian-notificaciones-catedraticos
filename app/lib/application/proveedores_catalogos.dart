/// Proveedores de los catálogos (2.0): sedes y facultades.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infrastructure/firebase/repositorio_catalogos.dart';
import 'proveedores_sede.dart';

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

/// Las facultades activas de la sede de trabajo, para elegir (2.0, RF-FAC-02).
///
/// Con menos de dos no se ofrece elegir facultad en ninguna parte (RF-FAC-04):
/// con una sola, «la facultad» es lo mismo que «todos».
final StreamProvider<List<ElementoCatalogo>> facultadesActivasProvider =
    StreamProvider<List<ElementoCatalogo>>((Ref ref) {
      final String sede = ref.watch(sedeDeTrabajoProvider);
      // Si no se pueden leer, no se ofrece elegir facultad: el formulario de
      // envío sigue funcionando con «todos», grupos y personas. Un error aquí
      // no puede tumbar la pantalla desde la que se avisa de una emergencia.
      try {
        return ref
            .watch(fuenteFacultadesProvider(sede))
            .observar()
            .map(
              (List<ElementoCatalogo> todas) =>
                  todas.where((ElementoCatalogo f) => f.activa).toList(),
            )
            .handleError((Object _) {});
      } on Object {
        return Stream<List<ElementoCatalogo>>.value(const <ElementoCatalogo>[]);
      }
    });

/// ¿Hay facultades entre las que elegir? (RF-FAC-04)
final Provider<bool> hayFacultadesParaElegirProvider = Provider<bool>(
  (Ref ref) => (ref.watch(facultadesActivasProvider).value?.length ?? 0) >= 2,
);

/// Las sedes del catálogo, para la administración general.
final StreamProvider<List<ElementoCatalogo>> sedesProvider =
    StreamProvider<List<ElementoCatalogo>>(
      (Ref ref) => ref.watch(fuenteSedesProvider).observar(),
    );

final Provider<RepositorioPersonasYSedes> repositorioPersonasYSedesProvider =
    Provider<RepositorioPersonasYSedes>(
      (Ref ref) => RepositorioPersonasYSedes(),
    );

