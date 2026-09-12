/// SIAN — Quién no está alcanzable, y por qué (DT-22).
///
/// ────────────────────────────────────────────────────────────────────────────
/// La sonda sin destinatario no sirve de nada: alguien tiene que enterarse.
/// ────────────────────────────────────────────────────────────────────────────
///
/// La función programada retira lo que ya no sirve, pero **detecta, no revive**:
/// un token muerto necesita que la persona abra la aplicación. Esto es la otra
/// mitad, la que le dice a coordinación a quién buscar antes de necesitarlo.
library;

import 'package:cloud_functions/cloud_functions.dart';

/// En qué estado está el canal de una persona.
///
/// El orden de declaración es el orden de gravedad, y coincide con el que usa el
/// servidor: primero quien no puede recibir nada.
enum EstadoCanal {
  sinDispositivo,
  ultimoEnvioFallo,
  tokenMuerto,
  permisoDenegado,
  soloEnPestana,
  sinActividadReciente,
  reenganchadoSinComprobar,
  alDia;

  static EstadoCanal desdeServidor(String valor) => switch (valor) {
    'sin-dispositivo' => EstadoCanal.sinDispositivo,
    'ultimo-envio-fallo' => EstadoCanal.ultimoEnvioFallo,
    'token-muerto' => EstadoCanal.tokenMuerto,
    'permiso-denegado' => EstadoCanal.permisoDenegado,
    'solo-en-pestana' => EstadoCanal.soloEnPestana,
    'sin-actividad-reciente' => EstadoCanal.sinActividadReciente,
    'reenganchado-sin-comprobar' => EstadoCanal.reenganchadoSinComprobar,
    _ => EstadoCanal.alDia,
  };
}

/// Una persona que necesita que alguien la busque.
class PersonaSinCanal {
  const PersonaSinCanal({
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.estado,
    this.plataformas = const <String>[],
    this.ultimaActividad,
    this.versionApp = '',
  });

  final String uid;
  final String nombre;
  final String correo;
  final EstadoCanal estado;
  final List<String> plataformas;
  final DateTime? ultimaActividad;

  /// Con qué versión de la aplicación está corriendo su aparato. Vacía si no
  /// consta: son los registros anteriores a que se empezara a guardar.
  final String versionApp;

  static PersonaSinCanal desdeMapa(Map<Object?, Object?> m) => PersonaSinCanal(
    uid: (m['uid'] as String?) ?? '',
    nombre: (m['nombre'] as String?) ?? '',
    correo: (m['correo'] as String?) ?? '',
    estado: EstadoCanal.desdeServidor((m['estado'] as String?) ?? ''),
    plataformas: <String>[
      for (final Object? p in (m['plataformas'] as List<Object?>? ?? <Object?>[]))
        if (p is String) p,
    ],
    ultimaActividad: DateTime.tryParse((m['ultimaActividad'] as String?) ?? ''),
    versionApp: (m['versionApp'] as String?) ?? '',
  );
}

/// El resultado completo: a quién buscar, y sobre cuántos.
class RevisionDeCanal {
  const RevisionDeCanal({
    required this.total,
    required this.catedraticos,
    required this.personas,
  });

  /// Cuántos necesitan atención.
  final int total;

  /// Sobre cuántos catedráticos activos.
  ///
  /// Va aparte porque «5 de 22» dice mucho más que «5», y sin el segundo número
  /// no se sabe si es una anécdota o un problema.
  final int catedraticos;

  final List<PersonaSinCanal> personas;

  bool get todoEnOrden => total == 0;
}

class RepositorioCanal {
  RepositorioCanal({FirebaseFunctions? funciones}) : _dadas = funciones;

  final FirebaseFunctions? _dadas;
  late final FirebaseFunctions _fn =
      _dadas ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<RevisionDeCanal> revisar() async {
    final HttpsCallableResult<Object?> r = await _fn
        .httpsCallable('dispositivosQueNecesitanAtencion')
        .call<Object?>();

    final Map<Object?, Object?> datos =
        (r.data as Map<Object?, Object?>?) ?? <Object?, Object?>{};

    return RevisionDeCanal(
      total: (datos['total'] as num?)?.toInt() ?? 0,
      catedraticos: (datos['catedraticos'] as num?)?.toInt() ?? 0,
      personas: <PersonaSinCanal>[
        for (final Object? fila in (datos['filas'] as List<Object?>? ?? <Object?>[]))
          if (fila is Map<Object?, Object?>) PersonaSinCanal.desdeMapa(fila),
      ],
    );
  }
}
