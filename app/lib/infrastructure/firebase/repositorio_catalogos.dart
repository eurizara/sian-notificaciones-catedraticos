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

/// Una lista que se puede leer (y elegir de ella), aunque no se mantenga desde
/// aquí: las facultades que ofrece una sede salen del catálogo (2.0.6).
abstract class ListaCatalogo {
  Stream<List<ElementoCatalogo>> observar();
}

/// Lo que la pantalla de mantenimiento necesita de un catálogo, sea cual sea.
abstract class FuenteCatalogo implements ListaCatalogo {
  @override
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

/// Las facultades que ofrece una sede (2.0.6): se eligen del catálogo único
/// con [RepositorioOfertaFacultades], no se escriben aquí.
class FuenteFacultades implements ListaCatalogo {
  FuenteFacultades(this.sedeId, {FirebaseFirestore? firestore})
    : _firestoreDado = firestore;

  final String sedeId;
  final FirebaseFirestore? _firestoreDado;
  late final FirebaseFirestore _db =
      _firestoreDado ?? FirebaseFirestore.instance;

  @override
  Stream<List<ElementoCatalogo>> observar() => _db
      .collection('sedes')
      .doc(sedeId)
      .collection('facultades')
      .snapshots()
      .map(_leer);
}

/// El catálogo único de facultades de la UMG (2.0.6). Lo mantiene el
/// superadministrador; cada sede elige de aquí las que ofrece.
class FuenteCatalogoFacultades implements FuenteCatalogo {
  FuenteCatalogoFacultades({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestoreDado = firestore,
       _functionsDado = functions;

  final FirebaseFirestore? _firestoreDado;
  final FirebaseFunctions? _functionsDado;
  late final FirebaseFirestore _db =
      _firestoreDado ?? FirebaseFirestore.instance;
  late final FirebaseFunctions _fn =
      _functionsDado ?? FirebaseFunctions.instance;

  @override
  Stream<List<ElementoCatalogo>> observar() =>
      _db.collection('facultades').snapshots().map(_leer);

  @override
  Future<void> guardar({required String nombre, String? id, bool? activa}) {
    return _fn.httpsCallable('guardarFacultad').call<Object?>(<String, Object?>{
      'id': ?id,
      'nombre': nombre,
      'activa': ?activa,
    });
  }
}

/// Qué facultades del catálogo ofrece una sede (2.0.6). El superadministrador
/// en cualquier sede; la coordinación, en la suya. El servidor no deja retirar
/// una que alguien de la sede tiene asignada, y dice cuántos la tienen.
class RepositorioOfertaFacultades {
  RepositorioOfertaFacultades({FirebaseFunctions? functions})
    : _functionsDado = functions;

  final FirebaseFunctions? _functionsDado;
  late final FirebaseFunctions _fn =
      _functionsDado ?? FirebaseFunctions.instance;

  Future<void> ofrecer({
    required String sedeId,
    required String facultadId,
    required bool ofrecer,
  }) => _fn.httpsCallable('ofrecerFacultad').call<Object?>(<String, Object?>{
    'sedeId': sedeId,
    'facultadId': facultadId,
    'ofrecer': ofrecer,
  });
}

/// Repartir a la gente entre sedes (2.0.1 · RF-SED-02, RF-SED-06). Solo la
/// administración general; el servidor lo vuelve a comprobar.
class RepositorioPersonasYSedes {
  RepositorioPersonasYSedes({FirebaseFunctions? functions})
    : _functionsDado = functions;

  final FirebaseFunctions? _functionsDado;
  late final FirebaseFunctions _fn =
      _functionsDado ?? FirebaseFunctions.instance;

  /// Con [facultades] (2.0.6), también las suyas en esa sede, solo entre las
  /// que la sede ofrece. Sin ellas, el servidor conserva las que tenía.
  Future<void> asignarSede({
    required String uid,
    required String sedeId,
    required String rol,
    List<String>? facultades,
  }) => _fn.httpsCallable('asignarSede').call<Object?>(<String, Object?>{
    'uid': uid,
    'sedeId': sedeId,
    'rol': rol,
    'facultades': ?facultades,
  });

  Future<void> quitarSede({required String uid, required String sedeId}) => _fn
      .httpsCallable('quitarSede')
      .call<Object?>(<String, Object?>{'uid': uid, 'sedeId': sedeId});

  Future<void> cambiarAdminGeneral({
    required String uid,
    required bool valor,
  }) => _fn
      .httpsCallable('cambiarAdminGeneral')
      .call<Object?>(conSede(<String, Object?>{'uid': uid, 'valor': valor}));
}

/// Lo que una persona tiene (o se quiere que tenga) en una sede: su rol y sus
/// facultades allí (2.0.6).
class MembresiaDeseada {
  const MembresiaDeseada(this.rol, [this.facultades = const <String>{}]);

  final String rol;
  final Set<String> facultades;

  MembresiaDeseada conRol(String nuevo) => MembresiaDeseada(nuevo, facultades);

  MembresiaDeseada conFacultad(String id, {required bool tiene}) =>
      MembresiaDeseada(
        rol,
        tiene
            ? <String>{...facultades, id}
            : (<String>{...facultades}..remove(id)),
      );

  @override
  bool operator ==(Object other) =>
      other is MembresiaDeseada &&
      other.rol == rol &&
      other.facultades.length == facultades.length &&
      other.facultades.containsAll(facultades);
  @override
  int get hashCode => Object.hash(rol, Object.hashAllUnordered(facultades));
}

/// Un cambio de sedes de una persona, ya decidido.
sealed class CambioDeSede {
  const CambioDeSede(this.sedeId);
  final String sedeId;
}

class AsignarSede extends CambioDeSede {
  const AsignarSede(
    super.sedeId,
    this.rol, [
    this.facultades = const <String>[],
  ]);
  final String rol;

  /// Ordenadas, para que el pedido sea siempre el mismo.
  final List<String> facultades;

  @override
  bool operator ==(Object other) =>
      other is AsignarSede &&
      other.sedeId == sedeId &&
      other.rol == rol &&
      other.facultades.join(',') == facultades.join(',');
  @override
  int get hashCode => Object.hash(sedeId, rol, facultades.join(','));

  @override
  String toString() => 'AsignarSede($sedeId, $rol, $facultades)';
}

class QuitarSede extends CambioDeSede {
  const QuitarSede(super.sedeId);

  @override
  bool operator ==(Object other) =>
      other is QuitarSede && other.sedeId == sedeId;
  @override
  int get hashCode => sedeId.hashCode;

  @override
  String toString() => 'QuitarSede($sedeId)';
}

/// Qué hay que pedirle al servidor para pasar de [actual] a [deseado]
/// (sede → rol y facultades). Primero las altas y cambios, después las bajas:
/// así nunca se pasa por un momento sin ninguna sede.
List<CambioDeSede> cambiosDeSedes(
  Map<String, MembresiaDeseada> actual,
  Map<String, MembresiaDeseada> deseado,
) {
  return <CambioDeSede>[
    for (final MapEntry<String, MembresiaDeseada> e in deseado.entries)
      if (actual[e.key] != e.value)
        AsignarSede(e.key, e.value.rol, e.value.facultades.toList()..sort()),
    for (final String s in actual.keys)
      if (!deseado.containsKey(s)) QuitarSede(s),
  ];
}
