/// SIAN — Respuestas a un aviso (DT-27, mejora M-5).
///
/// Las lecturas van directas a Firestore, que ya decide quién puede ver cada
/// conversación: solo quien respondió y quien emitió el aviso. Escribir pasa
/// siempre por una Cloud Function, que comprueba que quien responde recibió el
/// aviso — desde el navegador no se escribe nada.
library;

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Quién escribió un turno.
enum LadoHilo {
  catedratico('CATEDRATICO'),
  emisor('EMISOR');

  const LadoHilo(this.clave);
  final String clave;

  static LadoHilo desde(Object? valor) =>
      valor == 'EMISOR' ? LadoHilo.emisor : LadoHilo.catedratico;
}

/// Una intervención dentro de una conversación.
class Turno {
  const Turno({
    required this.id,
    required this.lado,
    required this.autorNombre,
    required this.texto,
    this.creadoEn,
  });

  final String id;
  final LadoHilo lado;
  final String autorNombre;
  final String texto;

  /// Nula un instante: la pone el servidor, y hasta que llega la confirmación
  /// el turno recién escrito se ve sin hora.
  final DateTime? creadoEn;
}

/// Una conversación entre un catedrático y quien emitió un aviso.
class Hilo {
  const Hilo({
    required this.mensajeId,
    required this.uid,
    required this.nombre,
    required this.emisorUid,
    required this.tituloAviso,
    this.emisorNombre = '',
    this.turnos = 0,
    this.sinLeerEmisor = 0,
    this.sinLeerCatedratico = 0,
    this.ultimaVista = '',
    this.ultimoLado = LadoHilo.catedratico,
    this.actualizadoEn,
  });

  final String mensajeId;

  /// El catedrático. Es también el identificador del hilo.
  final String uid;
  final String nombre;

  final String emisorUid;
  final String emisorNombre;

  /// Copiado al crear el hilo: el emisor tiene que saber de qué le hablan sin
  /// abrir el aviso.
  final String tituloAviso;

  final int turnos;
  final int sinLeerEmisor;
  final int sinLeerCatedratico;
  final String ultimaVista;
  final LadoHilo ultimoLado;
  final DateTime? actualizadoEn;
}

/// Las conversaciones de un aviso, juntas. Es como las ve el emisor.
class AvisoConRespuestas {
  const AvisoConRespuestas({
    required this.mensajeId,
    required this.tituloAviso,
    required this.hilos,
  });

  final String mensajeId;
  final String tituloAviso;

  /// Primero las que tienen algo sin leer; dentro, la más reciente arriba.
  final List<Hilo> hilos;

  int get sinLeer => hilos.fold(0, (int t, Hilo h) => t + h.sinLeerEmisor);

  DateTime? get ultimaActividad => hilos
      .map((Hilo h) => h.actualizadoEn)
      .whereType<DateTime>()
      .fold<DateTime?>(
        null,
        (DateTime? a, DateTime b) => a == null || b.isAfter(a) ? b : a,
      );
}

/// Agrupa por aviso lo que devuelve la consulta de hilos del emisor.
///
/// Fuera del repositorio y sin Firestore para poder probar el orden, que es la
/// decisión que importa: lo que tiene respuestas sin leer va primero, porque
/// es sobre lo que hay que actuar.
List<AvisoConRespuestas> agruparPorAviso(List<Hilo> hilos) {
  final Map<String, List<Hilo>> porAviso = <String, List<Hilo>>{};
  for (final Hilo h in hilos) {
    porAviso.putIfAbsent(h.mensajeId, () => <Hilo>[]).add(h);
  }

  int masReciente(DateTime? a, DateTime? b) =>
      (b ?? DateTime(0)).compareTo(a ?? DateTime(0));

  final List<AvisoConRespuestas> avisos = porAviso.entries.map((
    MapEntry<String, List<Hilo>> e,
  ) {
    final List<Hilo> ordenados = List<Hilo>.of(e.value)
      ..sort((Hilo a, Hilo b) {
        final int porLeer = (b.sinLeerEmisor > 0 ? 1 : 0).compareTo(
          a.sinLeerEmisor > 0 ? 1 : 0,
        );
        return porLeer != 0
            ? porLeer
            : masReciente(a.actualizadoEn, b.actualizadoEn);
      });
    return AvisoConRespuestas(
      mensajeId: e.key,
      tituloAviso: ordenados.first.tituloAviso,
      hilos: ordenados,
    );
  }).toList();

  avisos.sort((AvisoConRespuestas a, AvisoConRespuestas b) {
    final int porLeer = (b.sinLeer > 0 ? 1 : 0).compareTo(
      a.sinLeer > 0 ? 1 : 0,
    );
    return porLeer != 0
        ? porLeer
        : masReciente(a.ultimaActividad, b.ultimaActividad);
  });
  return avisos;
}

class RepositorioRespuestas {
  RepositorioRespuestas({
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

  static final Random _azar = Random.secure();
  static const String _alfabeto =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  /// Identificador para un turno nuevo, generado aquí.
  ///
  /// Es lo que hace inofensivo el doble toque (DT-24): si el mismo turno llega
  /// dos veces, el servidor encuentra el primero ya guardado y no lo repite ni
  /// vuelve a notificar. Se genera en el aparato, sin ir a Firestore, por la
  /// misma razón que el identificador de un aviso: pedirlo por red ya falló.
  String nuevoIdDeTurno() => List<String>.generate(
    20,
    (_) => _alfabeto[_azar.nextInt(_alfabeto.length)],
  ).join();

  DocumentReference<Map<String, dynamic>> _hilo(String mensajeId, String uid) =>
      _db.collection('mensajes').doc(mensajeId).collection('hilos').doc(uid);

  /// El hilo de un catedrático sobre un aviso, o nulo si todavía no escribió.
  Stream<Hilo?> observarHilo(String mensajeId, String uid) =>
      _hilo(mensajeId, uid).snapshots().map((
        DocumentSnapshot<Map<String, dynamic>> d,
      ) {
        final Map<String, dynamic>? x = d.data();
        return x == null ? null : _aHilo(d.id, x);
      });

  /// Los turnos de un hilo, del más antiguo al más reciente: una conversación
  /// se lee de arriba abajo.
  Stream<List<Turno>> observarTurnos(String mensajeId, String uid) =>
      _hilo(mensajeId, uid)
          .collection('turnos')
          .orderBy('creadoEn')
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> s) =>
                s.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> d) {
                  final Map<String, dynamic> x = d.data();
                  return Turno(
                    id: d.id,
                    lado: LadoHilo.desde(x['lado']),
                    autorNombre: (x['autorNombre'] as String?) ?? '',
                    texto: (x['texto'] as String?) ?? '',
                    creadoEn: (x['creadoEn'] as Timestamp?)?.toDate(),
                  );
                }).toList(),
          );

  /// Las conversaciones de todos los avisos de un emisor.
  ///
  /// La consulta filtra por el emisor **por obligación**: Firestore no
  /// recorta una consulta según las reglas, la rechaza entera si no puede
  /// demostrar que todo lo devuelto es legible. Sin el filtro, esto sería
  /// `permission-denied`.
  Stream<List<Hilo>> observarHilosDelEmisor(String emisorUid) => _db
      .collectionGroup('hilos')
      .where('emisorUid', isEqualTo: emisorUid)
      .orderBy('actualizadoEn', descending: true)
      .limit(200)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> s) => s.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                  _aHilo(d.id, d.data()),
            )
            .toList(),
      );

  Future<void> responder({
    required String mensajeId,
    required String texto,
    required String turnoId,
    String? hiloUid,
  }) async {
    await _fn.httpsCallable('responderAviso').call<Object?>(<String, Object?>{
      'mensajeId': mensajeId,
      'texto': texto,
      'turnoId': turnoId,
      'hiloUid': ?hiloUid,
    });
  }

  Future<void> marcarLeido({required String mensajeId, String? hiloUid}) async {
    await _fn.httpsCallable('marcarHiloLeido').call<Object?>(<String, Object?>{
      'mensajeId': mensajeId,
      'hiloUid': ?hiloUid,
    });
  }

  Hilo _aHilo(String id, Map<String, dynamic> x) {
    final Map<Object?, Object?> ultimo = x['ultimo'] is Map
        ? (x['ultimo'] as Map).cast<Object?, Object?>()
        : <Object?, Object?>{};
    return Hilo(
      mensajeId: (x['mensajeId'] as String?) ?? '',
      uid: (x['uid'] as String?) ?? id,
      nombre: (x['nombre'] as String?) ?? '',
      emisorUid: (x['emisorUid'] as String?) ?? '',
      emisorNombre: (x['emisorNombre'] as String?) ?? '',
      tituloAviso: (x['tituloAviso'] as String?) ?? '',
      turnos: (x['turnos'] as num?)?.toInt() ?? 0,
      sinLeerEmisor: (x['sinLeerEmisor'] as num?)?.toInt() ?? 0,
      sinLeerCatedratico: (x['sinLeerCatedratico'] as num?)?.toInt() ?? 0,
      ultimaVista: (ultimo['vista'] as String?) ?? '',
      ultimoLado: LadoHilo.desde(ultimo['lado']),
      actualizadoEn: (x['actualizadoEn'] as Timestamp?)?.toDate(),
    );
  }
}
