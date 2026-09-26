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
    this.id = '',
    this.navegador = '',
    this.ultimaActividad,
  });

  /// El documento del dispositivo: lo que hace falta para retirarlo.
  final String id;

  /// `WEB_ANDROID`, `WEB_IOS` o `WEB_ESCRITORIO`.
  final String plataforma;

  /// «Safari», «Chrome», «Firefox»… En un mismo teléfono, dos navegadores son
  /// dos canales distintos.
  final String navegador;

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
                id: (a['id'] as String?) ?? '',
                plataforma: (a['plataforma'] as String?) ?? '',
                navegador: ((a['navegador'] as String?) ?? '').trim(),
                versionApp: ((a['versionApp'] as String?) ?? '').trim(),
                ultimaActividad: DateTime.tryParse(
                  (a['ultimaActividad'] as String?) ?? '',
                ),
              ),
        ],
      );
}

/// Cómo quedan las versiones de los destinatarios frente a la publicada.
class ClasificacionDeVersiones {
  const ClasificacionDeVersiones({
    required this.atrasados,
    required this.registrosReemplazados,
  });

  /// Cuántos registros viejos hay de aparatos que ya se actualizaron.
  int get reemplazados => registrosReemplazados.length;

  /// Cuáles, con de quién son: para poder retirarlos desde Alcance.
  final List<({VersionesDePersona persona, AparatoConVersion aparato})>
  registrosReemplazados;

  /// Quiénes tienen algún aparato de verdad sin la versión publicada, con solo
  /// esos aparatos. Es a quien hay que pedirle actualizar.
  final List<VersionesDePersona> atrasados;

}

/// Separa los aparatos atrasados de los registros que ya fueron reemplazados.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Por qué no basta con comparar la versión (16/09/2026)
/// ────────────────────────────────────────────────────────────────────────────
///
/// Reinstalar la aplicación deja el registro de la instalación anterior. En
/// producción, 5 de las 15 personas que ya estaban en 1.5.11 salían como
/// atrasadas por registros de finales de agosto de su **mismo** teléfono: el
/// coordinador veía «iPhone · Versión desconocida» tres veces para alguien con
/// el iPhone al día. No se retiran solos hasta los 60 días sin actividad.
///
/// Un aparato atrasado cuenta como **reemplazado** si la misma persona tiene
/// otro en la versión publicada, de la **misma plataforma y el mismo
/// navegador**, con actividad más reciente. El navegador importa: Firefox y
/// Chrome en un mismo Android son dos canales, y el de Firefox sí puede estar
/// atrasado. Es una suposición razonable, no una certeza —un iPad y un iPhone
/// con Safari no se distinguen—, así que solo cambia cómo se muestra: no se
/// borra nada.
ClasificacionDeVersiones clasificarVersiones(
  List<VersionesDePersona> personas,
  String publicada,
) {
  final List<VersionesDePersona> atrasados = <VersionesDePersona>[];
  final List<({VersionesDePersona persona, AparatoConVersion aparato})>
  reemplazados = <({VersionesDePersona persona, AparatoConVersion aparato})>[];

  for (final VersionesDePersona p in personas) {
    final List<AparatoConVersion> alDia = <AparatoConVersion>[
      for (final AparatoConVersion a in p.aparatos)
        if (a.versionApp == publicada) a,
    ];
    final List<AparatoConVersion> deVerdad = <AparatoConVersion>[];

    for (final AparatoConVersion a in p.aparatos) {
      if (a.versionApp == publicada) {
        continue;
      }
      final bool loReemplazo = alDia.any(
        (AparatoConVersion b) =>
            b.plataforma == a.plataforma &&
            b.navegador.toLowerCase() == a.navegador.toLowerCase() &&
            b.ultimaActividad != null &&
            (a.ultimaActividad == null ||
                b.ultimaActividad!.isAfter(a.ultimaActividad!)),
      );
      if (loReemplazo) {
        reemplazados.add((persona: p, aparato: a));
      } else {
        deVerdad.add(a);
      }
    }

    if (deVerdad.isNotEmpty) {
      atrasados.add(
        VersionesDePersona(
          uid: p.uid,
          nombre: p.nombre,
          correo: p.correo,
          aparatos: deVerdad,
        ),
      );
    }
  }

  return ClasificacionDeVersiones(
    atrasados: atrasados,
    registrosReemplazados: reemplazados,
  );
}

/// Un tipo de fallo reportado por los aparatos en las últimas 24 h (DT-34).
class TipoDeFallosResumido {
  const TipoDeFallosResumido({
    required this.que,
    required this.aparatos,
    required this.veces,
    required this.plataformas,
    required this.versiones,
    required this.ultimoDetalle,
  });

  factory TipoDeFallosResumido.desdeMapa(Map<Object?, Object?> m) =>
      TipoDeFallosResumido(
        que: m['que'] as String? ?? '',
        aparatos: (m['aparatos'] as num?)?.toInt() ?? 0,
        veces: (m['veces'] as num?)?.toInt() ?? 0,
        plataformas: <String>[
          for (final Object? p in m['plataformas'] as List<Object?>? ?? <Object?>[])
            if (p is String) p,
        ],
        versiones: <String>[
          for (final Object? v in m['versiones'] as List<Object?>? ?? <Object?>[])
            if (v is String) v,
        ],
        ultimoDetalle: m['ultimoDetalle'] as String? ?? '',
      );

  /// La clave del tipo, como la manda el aparato (`registro-dispositivo`…).
  final String que;
  final int aparatos;
  final int veces;
  final List<String> plataformas;
  final List<String> versiones;

  /// El detalle técnico del más reciente, ya limpio de datos personales.
  final String ultimoDetalle;
}

/// Lo que los aparatos reportaron que les falló en las últimas 24 h (DT-34).
///
/// Sin nombres: el reporte no sabe de quién es el aparato.
class FallosDeAparatos {
  const FallosDeAparatos({
    required this.aparatos,
    required this.reportes,
    required this.porTipo,
  });

  /// Una función anterior a 1.6.10 no lo manda: se lee como «ninguno».
  factory FallosDeAparatos.desdeMapa(Object? m) {
    if (m is! Map<Object?, Object?>) {
      return ninguno;
    }
    return FallosDeAparatos(
      aparatos: (m['aparatos'] as num?)?.toInt() ?? 0,
      reportes: (m['reportes'] as num?)?.toInt() ?? 0,
      porTipo: <TipoDeFallosResumido>[
        for (final Object? t in m['porTipo'] as List<Object?>? ?? <Object?>[])
          if (t is Map<Object?, Object?>) TipoDeFallosResumido.desdeMapa(t),
      ],
    );
  }

  static const FallosDeAparatos ninguno = FallosDeAparatos(
    aparatos: 0,
    reportes: 0,
    porTipo: <TipoDeFallosResumido>[],
  );

  final int aparatos;
  final int reportes;
  final List<TipoDeFallosResumido> porTipo;
}

class RevisionDeCanal {
  const RevisionDeCanal({
    required this.total,
    required this.catedraticos,
    required this.personas,
    this.versiones = const <VersionesDePersona>[],
    this.fallos = FallosDeAparatos.ninguno,
  });

  /// Lo que reportaron los aparatos en las últimas 24 h (DT-34).
  final FallosDeAparatos fallos;

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

  /// Retira un registro de aparato (1.6). Solo coordinación; queda en la
  /// bitácora. Si el aparato sigue en uso, se registra solo al abrir SIAN.
  Future<void> retirar({required String uid, required String dispositivoId}) =>
      _fn.httpsCallable('retirarDispositivo').call<Object?>(<String, Object?>{
        'uid': uid,
        'dispositivoId': dispositivoId,
      });

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
      fallos: FallosDeAparatos.desdeMapa(datos['fallos']),
    );
  }
}
