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

/// Las facultades que ofrece una sede (2.0.6: elegidas del catálogo único).
final fuenteFacultadesProvider = Provider.family<ListaCatalogo, String>(
  (Ref ref, String sedeId) => FuenteFacultades(sedeId),
);

/// El catálogo único de facultades (2.0.6). Lo mantiene el superadministrador.
final Provider<FuenteCatalogo> fuenteCatalogoFacultadesProvider =
    Provider<FuenteCatalogo>((Ref ref) => FuenteCatalogoFacultades());

/// El catálogo único, para elegir de él. Si no se puede leer, queda vacío.
final StreamProvider<List<ElementoCatalogo>> catalogoFacultadesProvider =
    StreamProvider<List<ElementoCatalogo>>((Ref ref) {
      try {
        return ref
            .watch(fuenteCatalogoFacultadesProvider)
            .observar()
            .handleError((Object _) {});
      } on Object {
        return Stream<List<ElementoCatalogo>>.value(const <ElementoCatalogo>[]);
      }
    });

final Provider<RepositorioOfertaFacultades>
repositorioOfertaFacultadesProvider = Provider<RepositorioOfertaFacultades>(
  (Ref ref) => RepositorioOfertaFacultades(),
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

/// Todas las facultades de una sede, activas e inactivas: para el resumen del
/// bloque de Catálogos. Si no se pueden leer, la lista queda vacía.
final facultadesDeLaSedeProvider =
    StreamProvider.family<List<ElementoCatalogo>, String>((
      Ref ref,
      String sede,
    ) {
      try {
        return ref
            .watch(fuenteFacultadesProvider(sede))
            .observar()
            .handleError((Object _) {});
      } on Object {
        return Stream<List<ElementoCatalogo>>.value(const <ElementoCatalogo>[]);
      }
    });

/// Mis facultades en una sede (2.0.8), de mi propio perfil (las reglas dejan
/// leerlo a su dueño). Para decirle al catedrático dónde está. Si no se puede
/// leer, vacío: no se inventa nada.
final misFacultadesProvider =
    StreamProvider.family<List<String>, ({String uid, String sede})>((
      Ref ref,
      ({String uid, String sede}) clave,
    ) {
      try {
        return FirebaseFirestore.instance
            .doc('usuarios/${clave.uid}')
            .snapshots()
            .map((DocumentSnapshot<Map<String, dynamic>> d) {
              final Object? membresias = d.data()?['membresias'];
              final Object? m = membresias is Map
                  ? membresias[clave.sede]
                  : null;
              final Object? f = m is Map ? m['facultades'] : null;
              return f is List
                  ? f.map((Object? x) => '$x').toList()
                  : const <String>[];
            })
            .handleError((Object _) {});
      } on Object {
        return Stream<List<String>>.value(const <String>[]);
      }
    });
