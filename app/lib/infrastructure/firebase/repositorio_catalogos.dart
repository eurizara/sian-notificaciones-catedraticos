/// SIAN — Catálogos: sedes y facultades (2.0 · RF-CAT-01, RF-SED-06, RF-FAC-01).
///
/// Se leen de Firestore (las reglas dejan leer a quien pertenece a la sede y a
/// la administración general) y se escriben **solo** por función, que valida
/// nombres repetidos y deja asiento en la bitácora.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../core/sede_de_trabajo.dart';

/// Un elemento de cualquier catálogo. Todos se ven y se mantienen igual.
class ElementoCatalogo {
  const ElementoCatalogo({
    required this.id,
    required this.nombre,
    required this.activa,
  });

  final String id;
  final String nombre;
  final bool activa;
}

/// Lo que la pantalla de mantenimiento necesita de un catálogo, sea cual sea.
abstract class FuenteCatalogo {
  Stream<List<ElementoCatalogo>> observar();

  /// Alta (sin [id]) o edición. Lanza [FirebaseFunctionsException] con un
  /// mensaje para la persona si el nombre no vale.
  Future<void> guardar({required String nombre, String? id, bool? activa});
}

/// Activos primero y, dentro de cada bloque, por nombre.
List<ElementoCatalogo> ordenarCatalogo(Iterable<ElementoCatalogo> elementos) {
  return elementos.toList()..sort((ElementoCatalogo a, ElementoCatalogo b) {
    if (a.activa != b.activa) {
      return a.activa ? -1 : 1;
    }
    return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
  });
}

List<ElementoCatalogo> _leer(QuerySnapshot<Map<String, dynamic>> s) {
  return ordenarCatalogo(
    s.docs.map(
      (QueryDocumentSnapshot<Map<String, dynamic>> d) => ElementoCatalogo(
        id: d.id,
        nombre: (d.data()['nombre'] as String?) ?? d.id,
        activa: d.data()['activa'] != false,
      ),
    ),
  );
}

/// Las sedes. Solo la administración general las lista todas.
class FuenteSedes implements FuenteCatalogo {
  FuenteSedes({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestoreDado = firestore,
      _functionsDado = functions;

  final FirebaseFirestore? _firestoreDado;
  final FirebaseFunctions? _functionsDado;
  late final FirebaseFirestore _db =
      _firestoreDado ?? FirebaseFirestore.instance;
  late final FirebaseFunctions _fn =
      _functionsDado ?? FirebaseFunctions.instance;

  @override
  Stream<List<ElementoCatalogo>> observar() =>
      _db.collection('sedes').snapshots().map(_leer);

  @override
  Future<void> guardar({required String nombre, String? id, bool? activa}) {
    return _fn.httpsCallable('guardarSede').call<Object?>(<String, Object?>{
      'id': ?id,
      'nombre': nombre,
      'activa': ?activa,
    });
  }
}

/// Las facultades de una sede. Las mantiene su coordinación.
class FuenteFacultades implements FuenteCatalogo {
  FuenteFacultades(
    this.sedeId, {
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestoreDado = firestore,
       _functionsDado = functions;

  final String sedeId;
  final FirebaseFirestore? _firestoreDado;
  final FirebaseFunctions? _functionsDado;
  late final FirebaseFirestore _db =
      _firestoreDado ?? FirebaseFirestore.instance;
  late final FirebaseFunctions _fn =
      _functionsDado ?? FirebaseFunctions.instance;

  @override
  Stream<List<ElementoCatalogo>> observar() => _db
      .collection('sedes')
      .doc(sedeId)
      .collection('facultades')
      .snapshots()
      .map(_leer);

  @override
  Future<void> guardar({required String nombre, String? id, bool? activa}) {
    return _fn.httpsCallable('guardarFacultad').call<Object?>(<String, Object?>{
      'sedeId': sedeId,
      'id': ?id,
      'nombre': nombre,
      'activa': ?activa,
    });
  }
}

/// Repartir a la gente entre sedes (2.0.1 · RF-SED-02, RF-SED-06). Solo la
/// administración general; el servidor lo vuelve a comprobar.
class RepositorioPersonasYSedes {
  RepositorioPersonasYSedes({FirebaseFunctions? functions})
    : _functionsDado = functions;

  final FirebaseFunctions? _functionsDado;
  late final FirebaseFunctions _fn =
      _functionsDado ?? FirebaseFunctions.instance;

  Future<void> asignarSede({
    required String uid,
    required String sedeId,
    required String rol,
  }) => _fn.httpsCallable('asignarSede').call<Object?>(<String, Object?>{
    'uid': uid,
    'sedeId': sedeId,
    'rol': rol,
  });

  Future<void> quitarSede({required String uid, required String sedeId}) =>
      _fn.httpsCallable('quitarSede').call<Object?>(<String, Object?>{
        'uid': uid,
        'sedeId': sedeId,
      });

  Future<void> cambiarAdminGeneral({
    required String uid,
    required bool valor,
  }) => _fn.httpsCallable('cambiarAdminGeneral').call<Object?>(
    conSede(<String, Object?>{'uid': uid, 'valor': valor}),
  );
}

/// Un cambio de sedes de una persona, ya decidido.
sealed class CambioDeSede {
  const CambioDeSede(this.sedeId);
  final String sedeId;
}

class AsignarSede extends CambioDeSede {
  const AsignarSede(super.sedeId, this.rol);
  final String rol;

  @override
  bool operator ==(Object other) =>
      other is AsignarSede && other.sedeId == sedeId && other.rol == rol;
  @override
  int get hashCode => Object.hash(sedeId, rol);
}

class QuitarSede extends CambioDeSede {
  const QuitarSede(super.sedeId);

  @override
  bool operator ==(Object other) => other is QuitarSede && other.sedeId == sedeId;
  @override
  int get hashCode => sedeId.hashCode;
}

/// Qué hay que pedirle al servidor para pasar de [actual] a [deseado]
/// (sede → rol). Primero las altas y cambios, después las bajas: así nunca se
/// pasa por un momento sin ninguna sede.
List<CambioDeSede> cambiosDeSedes(
  Map<String, String> actual,
  Map<String, String> deseado,
) {
  return <CambioDeSede>[
    for (final MapEntry<String, String> e in deseado.entries)
      if (actual[e.key] != e.value) AsignarSede(e.key, e.value),
    for (final String s in actual.keys)
      if (!deseado.containsKey(s)) QuitarSede(s),
  ];
}

