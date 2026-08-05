/// SIAN — Composición y envío de mensajes (RF-MSG-01, RF-PRG-01).
///
/// Todo el envío pasa por Cloud Functions. El cliente propone: no crea el
/// mensaje, no resuelve los destinatarios y no toca las entregas. RN-03 dice
/// que un mensaje enviado no se edita ni se borra, y eso no puede quedar a
/// criterio de quien tenga abierta la consola del navegador.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'repositorio_adjuntos.dart';

/// Grupo tal como se elige al redactar.
class GrupoVista {
  const GrupoVista({
    required this.id,
    required this.nombre,
    required this.totalMiembros,
  });

  final String id;
  final String nombre;
  final int totalMiembros;
}

/// A quién va dirigido un mensaje (documento 05, sección 2.4).
class Destinatarios {
  const Destinatarios.todos()
    : modo = 'TODOS',
      gruposIds = const <String>[],
      usuariosIds = const <String>[];

  const Destinatarios.grupos(this.gruposIds)
    : modo = 'GRUPOS',
      usuariosIds = const <String>[];

  const Destinatarios.individual(this.usuariosIds)
    : modo = 'INDIVIDUAL',
      gruposIds = const <String>[];

  final String modo;
  final List<String> gruposIds;
  final List<String> usuariosIds;

  Map<String, Object?> aMapa() => <String, Object?>{
    'modo': modo,
    'gruposIds': gruposIds,
    'usuariosIds': usuariosIds,
  };
}

/// Conteo previo al envío (RF-USR-07).
class ConteoDestinatarios {
  const ConteoDestinatarios({
    required this.total,
    required this.excluidos,
    required this.motivos,
  });

  final int total;
  final int excluidos;

  /// Motivo → cuántos. «43 de 45» sin decir por qué no ayuda a nadie.
  final Map<String, int> motivos;
}

/// Resultado de un envío ya consumado.
class ResultadoEnvio {
  const ResultadoEnvio({
    required this.mensajeId,
    required this.estado,
    required this.total,
    required this.entregados,
    required this.fallidos,
  });

  final String mensajeId;
  final String estado;
  final int total;
  final int entregados;
  final int fallidos;

  bool get huboFallos => fallidos > 0;
}

class RepositorioEnvio {
  RepositorioEnvio({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestoreDado = firestore,
      _functionsDado = functions;

  final FirebaseFirestore? _firestoreDado;
  final FirebaseFunctions? _functionsDado;

  // Resolución perezosa: construir el repositorio no debe tocar Firebase.
  late final FirebaseFirestore _db = _firestoreDado ?? FirebaseFirestore.instance;
  late final FirebaseFunctions _fn = _functionsDado ?? FirebaseFunctions.instance;

  /// Grupos disponibles para elegir como destinatarios.
  Stream<List<GrupoVista>> observarGrupos() {
    return _db
        .collection('grupos')
        .where('activo', isEqualTo: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> s) {
          final List<GrupoVista> lista = s.docs.map((
            QueryDocumentSnapshot<Map<String, dynamic>> d,
          ) {
            final Map<String, dynamic> x = d.data();
            return GrupoVista(
              id: d.id,
              nombre: (x['nombre'] as String?) ?? d.id,
              totalMiembros: (x['totalMiembros'] as num?)?.toInt() ?? 0,
            );
          }).toList();
          lista.sort((GrupoVista a, GrupoVista b) => a.nombre.compareTo(b.nombre));
          return lista;
        });
  }

  /// Cuántos recibirían este mensaje, sin enviar nada (RF-USR-07).
  ///
  /// Se pregunta al servidor y no se calcula aquí: el conteo tiene que salir
  /// de la **misma** función que luego resuelve el envío. Uno calculado en el
  /// cliente que difiriera del real sería peor que no contar, porque daría
  /// confianza falsa justo antes de un acto irreversible.
  Future<ConteoDestinatarios> contar(Destinatarios destinatarios) async {
    final HttpsCallableResult<Object?> r = await _fn
        .httpsCallable('contarDestinatarios')
        .call<Object?>(<String, Object?>{'destinatarios': destinatarios.aMapa()});

    final Map<Object?, Object?> d =
        (r.data as Map<Object?, Object?>?) ?? <Object?, Object?>{};
    final Map<Object?, Object?> motivos =
        (d['motivos'] as Map<Object?, Object?>?) ?? <Object?, Object?>{};

    return ConteoDestinatarios(
      total: (d['total'] as num?)?.toInt() ?? 0,
      excluidos: (d['excluidos'] as num?)?.toInt() ?? 0,
      motivos: motivos.map(
        (Object? k, Object? v) =>
            MapEntry<String, int>('$k', (v as num?)?.toInt() ?? 0),
      ),
    );
  }

  /// Envía ya (RF-PRG-01).
  ///
  /// `confirmacionUrgente` viaja al servidor a propósito: el diálogo de la
  /// interfaz no basta como garantía de RN-06, porque quien llame a la
  /// Function directamente se lo saltaría.
  Future<ResultadoEnvio> enviarInmediato({
    required String titulo,
    required String cuerpo,
    required bool urgente,
    required bool requiereConfirmacion,
    required Destinatarios destinatarios,
    bool confirmacionUrgente = false,
    String? mensajeId,
    AdjuntoSubido? voz,
    AdjuntoSubido? imagen,
  }) async {
    final HttpsCallableResult<Object?> r = await _fn
        .httpsCallable('enviarInmediato')
        .call<Object?>(<String, Object?>{
          'titulo': titulo,
          'cuerpo': cuerpo,
          'tipo': urgente ? 'URGENTE' : 'INFORMATIVO',
          'requiereConfirmacion': requiereConfirmacion,
          'destinatarios': destinatarios.aMapa(),
          'confirmacionUrgente': confirmacionUrgente,
          'mensajeId': ?mensajeId,
          if (voz != null || imagen != null)
            'adjuntos': <String, Object?>{
              if (voz != null) 'audio': voz.aMapa(),
              if (imagen != null) 'imagen': imagen.aMapa(),
            },
        });

    final Map<Object?, Object?> d =
        (r.data as Map<Object?, Object?>?) ?? <Object?, Object?>{};

    return ResultadoEnvio(
      mensajeId: (d['mensajeId'] as String?) ?? '',
      estado: (d['estado'] as String?) ?? '',
      total: (d['total'] as num?)?.toInt() ?? 0,
      entregados: (d['entregados'] as num?)?.toInt() ?? 0,
      fallidos: (d['fallidos'] as num?)?.toInt() ?? 0,
    );
  }
}
