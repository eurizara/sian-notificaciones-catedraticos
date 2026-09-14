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
/// Un aparato de una persona, con la versión que reportó al registrarse.
class AparatoConVersion {
  const AparatoConVersion({
    required this.plataforma,
    required this.versionApp,
    this.ultimaActividad,
  });

  /// `WEB_ANDROID`, `WEB_IOS` o `WEB_ESCRITORIO`.
  final String plataforma;

  /// Vacía si el aparato no ha abierto SIAN desde que el servidor la guarda
  /// (1.5.8): no se sabe qué corre, y por eso cuenta como no actualizado.
  final String versionApp;
  final DateTime? ultimaActividad;
}

/// Qué versión tiene cada aparato de una persona (pantalla de Alcance).
class VersionesDePersona {
  const VersionesDePersona({
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.aparatos,
  });

  final String uid;
  final String nombre;
  final String correo;
  final List<AparatoConVersion> aparatos;

  static VersionesDePersona desdeMapa(Map<Object?, Object?> m) =>
      VersionesDePersona(
        uid: (m['uid'] as String?) ?? '',
        nombre: (m['nombre'] as String?) ?? '',
        correo: (m['correo'] as String?) ?? '',
        aparatos: <AparatoConVersion>[
          for (final Object? a
              in (m['aparatos'] as List<Object?>? ?? <Object?>[]))
            if (a is Map<Object?, Object?>)
              AparatoConVersion(
                plataforma: (a['plataforma'] as String?) ?? '',
                versionApp: ((a['versionApp'] as String?) ?? '').trim(),
                ultimaActividad: DateTime.tryParse(
                  (a['ultimaActividad'] as String?) ?? '',
                ),
              ),
        ],
      );
}

/// Quiénes tienen algún aparato sin la versión publicada, con solo esos
/// aparatos.
///
/// Va por aparato: alguien puede tener el teléfono al día y la computadora
/// atrasada, y lo que hay que pedirle es abrir SIAN en la computadora. Una
/// versión vacía cuenta como no actualizada: ese aparato no ha abierto SIAN
/// desde que se guarda la versión, así que no puede estar al día.
List<VersionesDePersona> sinLaVersionPublicada(
  List<VersionesDePersona> personas,
  String publicada,
) => <VersionesDePersona>[
  for (final VersionesDePersona p in personas)
    if (p.aparatos.any((AparatoConVersion a) => a.versionApp != publicada))
      VersionesDePersona(
        uid: p.uid,
        nombre: p.nombre,
        correo: p.correo,
        aparatos: <AparatoConVersion>[
          for (final AparatoConVersion a in p.aparatos)
            if (a.versionApp != publicada) a,
        ],
      ),
];

class RevisionDeCanal {
  const RevisionDeCanal({
    required this.total,
    required this.catedraticos,
    required this.personas,
    this.versiones = const <VersionesDePersona>[],
  });

  /// Cada destinatario con aparatos, y la versión de cada aparato.
  final List<VersionesDePersona> versiones;

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
      versiones: <VersionesDePersona>[
        for (final Object? v
            in (datos['versiones'] as List<Object?>? ?? <Object?>[]))
          if (v is Map<Object?, Object?>) VersionesDePersona.desdeMapa(v),
      ],
    );
  }
}
