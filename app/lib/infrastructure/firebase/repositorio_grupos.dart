/// SIAN — Grupos de destinatarios (RF-USR-03, RF-USR-04).
///
/// Un repositorio propio y no un apartado del de administración: los grupos
/// los **escribe** la coordinación pero los **lee** también la pantalla de
/// redacción, y repartir eso entre dos repositorios obligaba a duplicar la
/// misma consulta en sitios que luego se desincronizan.
///
/// Las lecturas van directas a Firestore, protegidas por las reglas. Las
/// escrituras pasan todas por Cloud Functions: crear o modificar un grupo
/// cambia a quién le llega una alerta de emergencia, y eso deja asiento en
/// bitácora (RN-01, RF-BIT-01).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Límites del dominio, duplicados aquí solo para avisar antes de llamar.
/// La fuente de verdad es el dominio de TypeScript.
abstract final class LimitesGrupo {
  static const int maxNombre = 60;
  static const int maxMiembros = 200;

  /// A partir de aquí conviene avisar (DT-08). No bloquea: llegar a 200 y
  /// descubrir el límite el día que hace falta agregar a alguien es peor que
  /// saberlo con 50 de margen.
  static const int umbralAviso = 150;
}

/// Grupo tal como se muestra y se edita.
class GrupoDetalle {
  const GrupoDetalle({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.miembros,
    required this.activo,
  });

  final String id;
  final String nombre;
  final String descripcion;
  final List<String> miembros;
  final bool activo;

  int get totalMiembros => miembros.length;
  bool get rozaElLimite => totalMiembros >= LimitesGrupo.umbralAviso;
}

class RepositorioGrupos {
  RepositorioGrupos({
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

  /// Todos los grupos, activos e inactivos.
  ///
  /// Los inactivos se listan a propósito: un grupo desactivado sigue
  /// existiendo para el historial, y esconderlo haría creer que se borró.
  Stream<List<GrupoDetalle>> observarGrupos() {
    return _db.collection('grupos').snapshots().map((
      QuerySnapshot<Map<String, dynamic>> s,
    ) {
      final List<GrupoDetalle> lista = s.docs.map((
        QueryDocumentSnapshot<Map<String, dynamic>> d,
      ) {
        final Map<String, dynamic> x = d.data();
        return GrupoDetalle(
          id: d.id,
          nombre: (x['nombre'] as String?) ?? d.id,
          descripcion: (x['descripcion'] as String?) ?? '',
          miembros:
              (x['miembros'] as List<dynamic>?)
                  ?.map((dynamic m) => '$m')
                  .toList() ??
              <String>[],
          activo: x['activo'] != false,
        );
      }).toList();

      // Activos primero, y dentro de cada bloque por nombre: sobre los
      // activos es sobre los que se actúa.
      lista.sort((GrupoDetalle a, GrupoDetalle b) {
        if (a.activo != b.activo) {
          return a.activo ? -1 : 1;
        }
        return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
      });
      return lista;
    });
  }

  /// Crea o modifica. Sin `grupoId` crea uno nuevo (RF-USR-03).
  Future<String> guardar({
    required String nombre,
    required String descripcion,
    required List<String> miembros,
    String? grupoId,
  }) async {
    final HttpsCallableResult<Object?> r = await _fn
        .httpsCallable('guardarGrupo')
        .call<Object?>(<String, Object?>{
          'grupoId': ?grupoId,
          'nombre': nombre,
          'descripcion': descripcion,
          'miembros': miembros,
        });

    final Map<Object?, Object?> d =
        (r.data as Map<Object?, Object?>?) ?? <Object?, Object?>{};
    return (d['grupoId'] as String?) ?? '';
  }

  /// Activa o desactiva (RF-USR-04).
  ///
  /// No se borra: un grupo borrado dejaría los mensajes históricos apuntando
  /// a algo inexistente, y el reporte de un simulacro pasado tiene que poder
  /// decir a qué grupo se envió.
  Future<void> cambiarEstado({
    required String grupoId,
    required bool activo,
  }) async {
    await _fn.httpsCallable('cambiarEstadoGrupo').call<Object?>(
      <String, Object?>{'grupoId': grupoId, 'activo': activo},
    );
  }
}
