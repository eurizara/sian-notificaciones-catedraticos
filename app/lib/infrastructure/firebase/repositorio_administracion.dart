/// SIAN — Operaciones de administración.
///
/// Las **lecturas** van directas a Firestore, protegidas por las reglas. Las
/// **escrituras** pasan todas por Cloud Functions, sin excepción: crear una
/// invitación, cambiar un rol o desactivar una cuenta son actos con
/// consecuencias y con asiento en bitácora, y ninguno puede quedar a criterio
/// del cliente (RN-01, RNF-17).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Invitación tal como se muestra en el panel.
class InvitacionVista {
  const InvitacionVista({
    required this.correo,
    required this.rolAsignado,
    required this.nombre,
    required this.consumida,
    this.creadaEn,
  });

  final String correo;
  final String rolAsignado;
  final String nombre;
  final bool consumida;
  final DateTime? creadaEn;
}

/// Usuario tal como se muestra en el panel.
class UsuarioVista {
  const UsuarioVista({
    required this.uid,
    required this.correo,
    required this.nombre,
    required this.rol,
    required this.activo,
    required this.puedeEmitirUrgentes,
    required this.puedeCrearRecurrentes,
  });

  final String uid;
  final String correo;
  final String nombre;
  final String rol;
  final bool activo;
  final bool puedeEmitirUrgentes;
  final bool puedeCrearRecurrentes;
}

/// Asiento de bitácora tal como se muestra (RF-BIT-05).
class AsientoVista {
  const AsientoVista({
    required this.tipo,
    required this.actorCorreo,
    required this.actorRol,
    required this.entidad,
    required this.entidadId,
    required this.resumen,
    this.ocurridoEn,
  });

  final String tipo;
  final String actorCorreo;
  final String actorRol;
  final String entidad;
  final String entidadId;
  final String resumen;
  final DateTime? ocurridoEn;

  /// Los rechazos de acceso se destacan: son el evento que más interesa
  /// auditar (criterio de aceptación de RF-AUT-03).
  bool get esRechazo => tipo == 'SESION_RECHAZADA';
}

/// Resultado de una carga masiva, con el detalle de lo rechazado.
class ResultadoCarga {
  const ResultadoCarga({required this.creadas, required this.rechazadas});

  final int creadas;

  /// Pares «número de línea → motivo».
  final List<({int numero, String error})> rechazadas;
}

class RepositorioAdministracion {
  RepositorioAdministracion({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestoreDado = firestore,
       _functionsDado = functions;

  final FirebaseFirestore? _firestoreDado;
  final FirebaseFunctions? _functionsDado;

  // Resolución perezosa a propósito: construir el repositorio no debe tocar
  // Firebase. Así una prueba de widget puede sustituirlo por un doble sin que
  // el simple hecho de instanciarlo reviente por falta de inicialización.
  late final FirebaseFirestore _db = _firestoreDado ?? FirebaseFirestore.instance;
  late final FirebaseFunctions _fn = _functionsDado ?? FirebaseFunctions.instance;

  // --- Lecturas ------------------------------------------------------------

  Stream<List<InvitacionVista>> observarInvitaciones() {
    return _db.collection('invitaciones').snapshots().map((
      QuerySnapshot<Map<String, dynamic>> s,
    ) {
      final List<InvitacionVista> lista = s.docs.map((
        QueryDocumentSnapshot<Map<String, dynamic>> d,
      ) {
        final Map<String, dynamic> x = d.data();
        return InvitacionVista(
          correo: d.id,
          rolAsignado: (x['rolAsignado'] as String?) ?? '',
          nombre: (x['nombre'] as String?) ?? '',
          consumida: x['consumida'] == true,
          creadaEn: (x['creadaEn'] as Timestamp?)?.toDate(),
        );
      }).toList();

      // Sin invitar arriba: es sobre lo que hay que actuar.
      lista.sort((InvitacionVista a, InvitacionVista b) {
        if (a.consumida != b.consumida) {
          return a.consumida ? 1 : -1;
        }
        return a.correo.compareTo(b.correo);
      });
      return lista;
    });
  }

  Stream<List<UsuarioVista>> observarUsuarios() {
    return _db.collection('usuarios').snapshots().map((
      QuerySnapshot<Map<String, dynamic>> s,
    ) {
      final List<UsuarioVista> lista = s.docs.map((
        QueryDocumentSnapshot<Map<String, dynamic>> d,
      ) {
        final Map<String, dynamic> x = d.data();
        return UsuarioVista(
          uid: d.id,
          correo: (x['correo'] as String?) ?? '',
          nombre: (x['nombre'] as String?) ?? '',
          rol: (x['rol'] as String?) ?? '',
          activo: x['activo'] == true,
          puedeEmitirUrgentes: x['puedeEmitirUrgentes'] == true,
          puedeCrearRecurrentes: x['puedeCrearRecurrentes'] == true,
        );
      }).toList();

      lista.sort((UsuarioVista a, UsuarioVista b) => a.correo.compareTo(b.correo));
      return lista;
    });
  }

  /// Bitácora, de lo más reciente a lo más antiguo (RF-BIT-05).
  Stream<List<AsientoVista>> observarBitacora({String? tipo, int limite = 100}) {
    Query<Map<String, dynamic>> consulta = _db.collection('bitacora');
    if (tipo != null && tipo.isNotEmpty) {
      consulta = consulta.where('tipo', isEqualTo: tipo);
    }
    consulta = consulta.orderBy('ocurridoEn', descending: true).limit(limite);

    return consulta.snapshots().map(
      (QuerySnapshot<Map<String, dynamic>> s) => s.docs.map((
        QueryDocumentSnapshot<Map<String, dynamic>> d,
      ) {
        final Map<String, dynamic> x = d.data();
        return AsientoVista(
          tipo: (x['tipo'] as String?) ?? '',
          actorCorreo: (x['actorCorreo'] as String?) ?? '',
          actorRol: (x['actorRol'] as String?) ?? '',
          entidad: (x['entidad'] as String?) ?? '',
          entidadId: (x['entidadId'] as String?) ?? '',
          resumen: (x['resumen'] as String?) ?? '',
          ocurridoEn: (x['ocurridoEn'] as Timestamp?)?.toDate(),
        );
      }).toList(),
    );
  }

  // --- Escrituras, todas vía Cloud Functions -------------------------------

  Future<ResultadoCarga> crearInvitacion({
    required String correo,
    required String rol,
    String nombre = '',
  }) async {
    final HttpsCallableResult<Object?> r = await _fn
        .httpsCallable('crearInvitaciones')
        .call<Object?>(<String, Object?>{
          'correo': correo,
          'rol': rol,
          'nombre': nombre,
        });
    return _interpretarCarga(r.data);
  }

  Future<ResultadoCarga> cargarCsv(String csv) async {
    final HttpsCallableResult<Object?> r = await _fn
        .httpsCallable('crearInvitaciones')
        .call<Object?>(<String, Object?>{'csv': csv});
    return _interpretarCarga(r.data);
  }

  ResultadoCarga _interpretarCarga(Object? datos) {
    final Map<Object?, Object?> m = (datos as Map<Object?, Object?>?) ?? <Object?, Object?>{};
    final List<Object?> rechazadas = (m['rechazadas'] as List<Object?>?) ?? <Object?>[];

    return ResultadoCarga(
      creadas: (m['creadas'] as num?)?.toInt() ?? 0,
      rechazadas: rechazadas.map((Object? e) {
        final Map<Object?, Object?> x = (e as Map<Object?, Object?>?) ?? <Object?, Object?>{};
        return (
          numero: (x['numero'] as num?)?.toInt() ?? 0,
          error: (x['error'] as String?) ?? '',
        );
      }).toList(),
    );
  }

  Future<void> revocarInvitacion(String correo) async {
    await _fn.httpsCallable('revocarInvitacion').call<Object?>(<String, Object?>{
      'correo': correo,
    });
  }

  Future<void> cambiarRol({required String uid, required String rol}) async {
    await _fn.httpsCallable('cambiarRol').call<Object?>(<String, Object?>{
      'uid': uid,
      'rol': rol,
    });
  }

  Future<void> cambiarEstado({required String uid, required bool activo}) async {
    await _fn.httpsCallable('cambiarEstadoUsuario').call<Object?>(<String, Object?>{
      'uid': uid,
      'activo': activo,
    });
  }

  Future<void> cambiarAutorizaciones({
    required String uid,
    bool? puedeEmitirUrgentes,
    bool? puedeCrearRecurrentes,
  }) async {
    await _fn.httpsCallable('cambiarAutorizacionesFinas').call<Object?>(<String, Object?>{
      'uid': uid,
      'puedeEmitirUrgentes': ?puedeEmitirUrgentes,
      'puedeCrearRecurrentes': ?puedeCrearRecurrentes,
    });
  }
}
