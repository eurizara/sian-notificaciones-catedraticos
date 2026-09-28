/// SIAN — Plantillas de avisos (RF-MSG-14).
///
/// Textos de avisos frecuentes —recordatorios, simulacros, suspensiones—,
/// compartidos entre quienes emiten. Una plantilla **no es un aviso**: no llega
/// a nadie hasta que alguien la carga en el formulario, la revisa y la envía,
/// y ese envío pasa por la misma validación del servidor que cualquier otro.
/// Por eso se leen y escriben directamente en Firestore, con las reglas
/// poniendo los mismos límites que a un aviso (`firestore.rules`,
/// `plantillas`).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show immutable;

@immutable
class Plantilla {
  const Plantilla({
    required this.nombre,
    required this.titulo,
    required this.cuerpo,
    this.id,
    this.urgente = false,
    this.requiereConfirmacion = false,
    this.predefinida = false,
  });

  /// Nulo en una plantilla nueva o en una predefinida.
  final String? id;

  /// Cómo se reconoce en la lista («Simulacro de evacuación»).
  final String nombre;
  final String titulo;
  final String cuerpo;
  final bool urgente;
  final bool requiereConfirmacion;

  /// Viene con SIAN: no se borra ni se edita, pero se puede usar y guardar
  /// como propia con otro texto.
  final bool predefinida;
}

abstract interface class RepositorioPlantillas {
  /// Las propias, en orden alfabético.
  Stream<List<Plantilla>> observar();

  /// Crea si `id` es nulo; si no, reemplaza esa.
  Future<void> guardar(Plantilla plantilla);

  Future<void> borrar(String id);
}

class RepositorioPlantillasFirebase implements RepositorioPlantillas {
  RepositorioPlantillasFirebase({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestoreDado = firestore,
       _authDado = auth;

  final FirebaseFirestore? _firestoreDado;
  final FirebaseAuth? _authDado;

  late final FirebaseFirestore _db =
      _firestoreDado ?? FirebaseFirestore.instance;
  late final FirebaseAuth _auth = _authDado ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _coleccion =>
      _db.collection('plantillas');

  @override
  Stream<List<Plantilla>> observar() =>
      _coleccion.snapshots().map((QuerySnapshot<Map<String, dynamic>> q) {
        final List<Plantilla> lista = <Plantilla>[
          for (final QueryDocumentSnapshot<Map<String, dynamic>> d in q.docs)
            Plantilla(
              id: d.id,
              nombre: d.data()['nombre'] as String? ?? '',
              titulo: d.data()['titulo'] as String? ?? '',
              cuerpo: d.data()['cuerpo'] as String? ?? '',
              urgente: d.data()['urgente'] as bool? ?? false,
              requiereConfirmacion:
                  d.data()['requiereConfirmacion'] as bool? ?? false,
            ),
        ];
        lista.sort(
          (Plantilla a, Plantilla b) =>
              a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
        );
        return lista;
      });

  @override
  Future<void> guardar(Plantilla p) async {
    final DocumentReference<Map<String, dynamic>> ref = p.id == null
        ? _coleccion.doc()
        : _coleccion.doc(p.id);
    final Map<String, Object?> datos = <String, Object?>{
      'nombre': p.nombre.trim(),
      'titulo': p.titulo,
      'cuerpo': p.cuerpo,
      'urgente': p.urgente,
      'requiereConfirmacion': p.requiereConfirmacion,
      'actualizadaEn': FieldValue.serverTimestamp(),
    };
    if (p.id == null) {
      // La autoría la ponen las reglas a prueba: solo a nombre propio.
      datos['creadaPor'] = _auth.currentUser?.uid;
      await ref.set(datos);
    } else {
      await ref.update(datos);
    }
  }

  @override
  Future<void> borrar(String id) => _coleccion.doc(id).delete();
}
