/// SIAN — Programación, despacho diferido y confirmación (RF-PRG-*, RF-CNF-*).
///
/// Las lecturas van directas a Firestore; todo lo que decide **cuándo sale un
/// aviso** o **quién declaró haberlo leído** pasa por Cloud Functions. La
/// segunda parte no es una preferencia de arquitectura: una confirmación que
/// pudiera fabricarse desde la consola del navegador no probaría nada.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Unidad del intervalo de una recurrencia (RF-PRG-06).
enum UnidadIntervalo {
  minutos('MINUTOS', 'minutos'),
  horas('HORAS', 'horas'),
  dias('DIAS', 'días');

  const UnidadIntervalo(this.clave, this.etiqueta);
  final String clave;
  final String etiqueta;
}

/// Patrón de repetición, tal como se compone en la interfaz.
class PatronRecurrencia {
  const PatronRecurrencia({
    required this.fechaInicio,
    required this.fechaFin,
    required this.unidad,
    required this.valor,
    required this.diasSemana,
    required this.horaDelDia,
    this.maxOcurrencias = 100,
  });

  final DateTime fechaInicio;

  /// Obligatoria (RF-PRG-14). Una recurrencia sin final es un bucle de envío
  /// esperando a que nadie se acuerde de pararlo.
  final DateTime fechaFin;

  final UnidadIntervalo unidad;
  final int valor;

  /// 1 = lunes … 7 = domingo. Vacío significa «todos los días».
  final Set<int> diasSemana;

  /// 'HH:mm' en hora institucional. Solo aplica a intervalos en días.
  final String horaDelDia;

  final int maxOcurrencias;

  Map<String, Object?> aMapa() => <String, Object?>{
    'fechaInicio': fechaInicio.toUtc().toIso8601String(),
    'fechaFin': fechaFin.toUtc().toIso8601String(),
    'unidadIntervalo': unidad.clave,
    'valorIntervalo': valor,
    'diasSemana': diasSemana.toList()..sort(),
    'horaDelDia': horaDelDia,
    'maxOcurrencias': maxOcurrencias,
  };
}

/// Una ocurrencia calculada, para la vista previa (RF-PRG-09).
class OcurrenciaPrevista {
  const OcurrenciaPrevista({required this.numero, required this.local});

  final int numero;

  /// Ya formateada en hora institucional por el servidor: convertirla aquí
  /// otra vez sería la forma más fácil de que la vista previa mienta.
  final String local;
}

/// Mensaje programado, como se ve en la lista.
class MensajeProgramado {
  const MensajeProgramado({
    required this.id,
    required this.titulo,
    required this.tipo,
    required this.estado,
    required this.modo,
    required this.creadoPor,
    required this.requiereConfirmacion,
    this.proximaOcurrencia,
    this.enviadoEn,
    this.totalDestinatarios = 0,
    this.entregados = 0,
    this.confirmados = 0,
  });

  final String id;
  final String titulo;
  final String tipo;
  final String estado;
  final String modo;
  final String creadoPor;

  /// Si el aviso pedía confirmación de lectura (RF-MSG-12).
  ///
  /// Sin esto, el reporte mezclaba dos cosas incomparables: un aviso que nadie
  /// tenía que confirmar aparecía eternamente «al 0 %, faltan 40 por
  /// confirmar», como si algo hubiera salido mal. No había salido mal: es que
  /// nunca iba a confirmarse nadie.
  final bool requiereConfirmacion;

  /// Cuándo se disparó el envío.
  ///
  /// Distinto de [proximaOcurrencia], que mira hacia adelante. Un envío
  /// inmediato no tiene próxima ocurrencia y sí tiene esta, así que usar la
  /// otra dejaba los inmediatos sin fecha ninguna en el reporte.
  ///
  /// En un recurrente guarda la ÚLTIMA salida, no la primera: es lo que hace
  /// falta saber para responder «¿cuándo se avisó?».
  final DateTime? enviadoEn;

  final DateTime? proximaOcurrencia;
  final int totalDestinatarios;
  final int entregados;
  final int confirmados;

  bool get esUrgente => tipo == 'URGENTE';
  bool get esRecurrente => modo == 'RECURRENTE';
  bool get estaSuspendido => estado == 'SUSPENDIDO';
  bool get estaCancelado => estado == 'CANCELADO';

  /// Ya salió: RN-03 impide tocarlo.
  bool get yaSalio =>
      estado == 'ENVIADO' ||
      estado == 'ENVIADO_CON_FALLOS' ||
      estado == 'AGOTADO';

  bool get sePuedeIntervenir => !yaSalio && !estaCancelado;

  /// Porcentaje de confirmación sobre el TOTAL (RF-CNF-07).
  ///
  /// El denominador es el total y no los entregados: a quien no le llegó el
  /// aviso tampoco lo confirmó, y esconderlo daría un 100 % con gente sin
  /// enterarse.
  /// Solo tiene sentido si el aviso pedía confirmación. Para el resto, la
  /// medida que importa es cuántos lo recibieron.
  int get porcentajeConfirmado => totalDestinatarios == 0
      ? 0
      : ((confirmados / totalDestinatarios) * 100).round();

  /// Porcentaje de entrega.
  ///
  /// Es la única medida de avance que tiene un aviso que no pedía
  /// confirmación: o llegó, o no llegó.
  int get porcentajeEntregado => totalDestinatarios == 0
      ? 0
      : ((entregados / totalDestinatarios) * 100).round();

  /// Cuántos quedan por confirmar.
  ///
  /// Cero si el aviso no lo pedía: nadie está pendiente de nada, y decir
  /// «faltan 40 por confirmar» de algo que nunca se pidió confirmar convierte
  /// un dato correcto en una alarma falsa.
  int get faltanPorConfirmar =>
      requiereConfirmacion ? totalDestinatarios - confirmados : 0;
}

class RepositorioProgramacion {
  RepositorioProgramacion({
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

  /// Vista previa de las próximas ocurrencias (RF-PRG-09).
  ///
  /// La calcula el servidor con el mismo código que luego despacha. Calcularla
  /// aquí con otra implementación produciría una vista previa que no se
  /// corresponde con la realidad, que es peor que no tener vista previa.
  Future<List<OcurrenciaPrevista>> vistaPrevia(PatronRecurrencia patron) async {
    final HttpsCallableResult<Object?> r = await _fn
        .httpsCallable('vistaPreviaOcurrencias')
        .call<Object?>(<String, Object?>{'recurrencia': patron.aMapa()});

    final Map<Object?, Object?> d =
        (r.data as Map<Object?, Object?>?) ?? <Object?, Object?>{};
    final List<Object?> lista =
        (d['ocurrencias'] as List<Object?>?) ?? <Object?>[];

    return lista.map((Object? o) {
      final Map<Object?, Object?> m = (o as Map<Object?, Object?>?) ?? {};
      return OcurrenciaPrevista(
        numero: (m['numero'] as num?)?.toInt() ?? 0,
        local: (m['previstaParaLocal'] as String?) ?? '',
      );
    }).toList();
  }

  /// Programa para una fecha concreta (RF-PRG-02) o de forma recurrente.
  Future<String> programar({
    required String titulo,
    required String cuerpo,
    required bool urgente,
    required bool requiereConfirmacion,
    required Map<String, Object?> destinatarios,
    DateTime? ejecutarEn,
    PatronRecurrencia? recurrencia,
    bool confirmacionUrgente = false,
  }) async {
    final HttpsCallableResult<Object?> r = await _fn
        .httpsCallable('programarMensaje')
        .call<Object?>(<String, Object?>{
          'titulo': titulo,
          'cuerpo': cuerpo,
          'tipo': urgente ? 'URGENTE' : 'INFORMATIVO',
          'requiereConfirmacion': requiereConfirmacion,
          'destinatarios': destinatarios,
          'confirmacionUrgente': confirmacionUrgente,
          'ejecutarEn': ?ejecutarEn?.toUtc().toIso8601String(),
          if (recurrencia != null) 'recurrencia': recurrencia.aMapa(),
        });

    final Map<Object?, Object?> d =
        (r.data as Map<Object?, Object?>?) ?? <Object?, Object?>{};
    return (d['mensajeId'] as String?) ?? '';
  }

  /// Lo que está programado y todavía no ha salido, más lo ya enviado.
  Stream<List<MensajeProgramado>> observarProgramados() {
    return _db
        .collection('mensajes')
        .orderBy('creadoEn', descending: true)
        .limit(50)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> s) {
          return s.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> d) {
            final Map<String, dynamic> x = d.data();
            final Map<Object?, Object?> resumen = (x['resumenEntrega'] is Map)
                ? (x['resumenEntrega'] as Map).cast<Object?, Object?>()
                : <Object?, Object?>{};
            final Map<Object?, Object?> prog = (x['programacion'] is Map)
                ? (x['programacion'] as Map).cast<Object?, Object?>()
                : <Object?, Object?>{};

            return MensajeProgramado(
              id: d.id,
              titulo: (x['titulo'] as String?) ?? '',
              tipo: (x['tipo'] as String?) ?? 'INFORMATIVO',
              estado: (x['estado'] as String?) ?? '',
              modo: (prog['modo'] as String?) ?? 'INMEDIATO',
              creadoPor: (x['creadoPor'] as String?) ?? '',
              requiereConfirmacion: x['requiereConfirmacion'] == true,
              enviadoEn: (x['enviadoEn'] as Timestamp?)?.toDate(),
              proximaOcurrencia: (x['proximaOcurrencia'] as Timestamp?)
                  ?.toDate(),
              totalDestinatarios:
                  (x['totalDestinatarios'] as num?)?.toInt() ?? 0,
              entregados: (resumen['entregados'] as num?)?.toInt() ?? 0,
              confirmados: (resumen['confirmados'] as num?)?.toInt() ?? 0,
            );
          }).toList();
        });
  }

  /// Suspender, reanudar o cancelar (RF-PRG-10, RF-PRG-11).
  Future<void> cambiar({
    required String mensajeId,
    required String accion,
  }) async {
    await _fn.httpsCallable('cambiarProgramacion').call<Object?>(
      <String, Object?>{'mensajeId': mensajeId, 'accion': accion},
    );
  }

  /// Confirma la lectura (RF-CNF-01). Irreversible.
  Future<void> confirmarLectura({
    required String mensajeId,
    required String dispositivo,
  }) async {
    await _fn.httpsCallable('confirmarLectura').call<Object?>(<String, Object?>{
      'mensajeId': mensajeId,
      'dispositivo': dispositivo,
    });
  }

  /// Marca como abierto (RF-CNF-02). No sustituye a confirmar.
  Future<void> marcarAbierto(String mensajeId) async {
    await _fn.httpsCallable('marcarAbierto').call<Object?>(<String, Object?>{
      'mensajeId': mensajeId,
    });
  }
}
