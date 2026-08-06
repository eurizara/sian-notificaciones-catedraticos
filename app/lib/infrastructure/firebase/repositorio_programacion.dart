/// SIAN — Programación, despacho diferido y confirmación (RF-PRG-*, RF-CNF-*).
///
/// Las lecturas van directas a Firestore; todo lo que decide **cuándo sale un
/// aviso** o **quién declaró haberlo leído** pasa por Cloud Functions. La
/// segunda parte no es una preferencia de arquitectura: una confirmación que
/// pudiera fabricarse desde la consola del navegador no probaría nada.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'repositorio_adjuntos.dart';

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
    required this.modoDestinatarios,
    required this.formato,
    this.proximaOcurrencia,
    this.enviadoEn,
    this.nombresGrupos = const <String>[],
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

  /// `TODOS`, `GRUPOS` o `INDIVIDUAL`. Sin esto, la lista de programados no
  /// decía a quién iba dirigido nada: un aviso a un grupo de tres y otro a
  /// toda la institución se veían idénticos hasta que salían.
  final String modoDestinatarios;

  /// Nombres de los grupos destinatarios, ya resueltos.
  final List<String> nombresGrupos;

  /// `TEXTO`, `VOZ`, `IMAGEN` — lo que lleva el mensaje.
  final List<String> formato;

  bool get llevaVoz => formato.contains('VOZ');
  bool get llevaImagen => formato.contains('IMAGEN');
  bool get llevaAdjuntos => llevaVoz || llevaImagen;

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

/// Un destinatario y su estado, para el detalle del reporte (RF-CNF-06).
class DestinatarioEntrega {
  const DestinatarioEntrega({
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.estado,
    this.confirmadoEn,
  });

  final String uid;
  final String nombre;
  final String correo;
  final String estado;
  final DateTime? confirmadoEn;

  bool get confirmo => estado == 'CONFIRMADO';
  bool get leLlego =>
      estado == 'ENTREGADO' || estado == 'ABIERTO' || estado == 'CONFIRMADO';

  /// No le llegó. Es distinto de «no confirmó»: aquí no hubo descuido, hubo
  /// un problema técnico, y se resuelve de otra manera.
  bool get fallo => estado == 'FALLIDO' || estado == 'DESCARTADO';
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
    String? mensajeId,
    AdjuntoSubido? voz,
    AdjuntoSubido? imagen,
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
          // Sin esto, los adjuntos se subían a Storage contra un
          // identificador reservado y el mensaje se creaba con OTRO: los
          // archivos quedaban huérfanos y el catedrático recibía solo texto.
          'mensajeId': ?mensajeId,
          if (voz != null || imagen != null)
            'adjuntos': <String, Object?>{
              if (voz != null) 'audio': voz.aMapa(),
              if (imagen != null) 'imagen': imagen.aMapa(),
            },
        });

    final Map<Object?, Object?> d =
        (r.data as Map<Object?, Object?>?) ?? <Object?, Object?>{};
    return (d['mensajeId'] as String?) ?? '';
  }

  /// Lo que está programado y todavía no ha salido, más lo ya enviado.
  ///
  /// Se traen también los nombres de los grupos: mostrar identificadores
  /// aleatorios donde debería decir «Ingeniería» no ayuda a nadie a comprobar
  /// que el aviso iba a quien creía.
  ///
  /// [soloDe] restringe la consulta a un autor. No es un filtro de comodidad:
  /// las reglas solo dejan a un administrador académico leer los mensajes que
  /// él creó, y **Firestore no evalúa las reglas fila por fila en una
  /// consulta de lista**. Pedir todos y quedarse con los suyos no devuelve
  /// «los suyos»: devuelve `permission-denied`. La consulta tiene que declarar
  /// por sí misma que es segura.
  Stream<List<MensajeProgramado>> observarProgramados({String? soloDe}) {
    Query<Map<String, dynamic>> consulta = _db.collection('mensajes');

    if (soloDe != null) {
      consulta = consulta.where('creadoPor', isEqualTo: soloDe);
    }

    return consulta
        .orderBy('creadoEn', descending: true)
        .limit(100)
        .snapshots()
        .asyncMap((QuerySnapshot<Map<String, dynamic>> s) async {
          final QuerySnapshot<Map<String, dynamic>> grupos = await _db
              .collection('grupos')
              .get();
          final Map<String, String> nombresPorId = <String, String>{
            for (final QueryDocumentSnapshot<Map<String, dynamic>> g
                in grupos.docs)
              g.id: (g.data()['nombre'] as String?) ?? g.id,
          };
          return _mapear(s, nombresPorId);
        });
  }

  /// Convierte los documentos en la vista, resolviendo nombres de grupo.
  List<MensajeProgramado> _mapear(
    QuerySnapshot<Map<String, dynamic>> s,
    Map<String, String> nombresPorId,
  ) {
    return s.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> d) {
      final Map<String, dynamic> x = d.data();

      Map<Object?, Object?> mapa(String clave) => x[clave] is Map
          ? (x[clave] as Map).cast<Object?, Object?>()
          : <Object?, Object?>{};

      final Map<Object?, Object?> resumen = mapa('resumenEntrega');
      final Map<Object?, Object?> prog = mapa('programacion');
      final Map<Object?, Object?> dest = mapa('destinatarios');

      List<String> lista(Object? v) =>
          (v as List<dynamic>?)?.map((dynamic e) => '$e').toList() ??
          <String>[];

      return MensajeProgramado(
        id: d.id,
        titulo: (x['titulo'] as String?) ?? '',
        tipo: (x['tipo'] as String?) ?? 'INFORMATIVO',
        estado: (x['estado'] as String?) ?? '',
        modo: (prog['modo'] as String?) ?? 'INMEDIATO',
        creadoPor: (x['creadoPor'] as String?) ?? '',
        requiereConfirmacion: x['requiereConfirmacion'] == true,
        modoDestinatarios: (dest['modo'] as String?) ?? 'TODOS',
        // Nombres, no identificadores: mostrar cadenas aleatorias donde
        // debería decir «Ingeniería» no ayuda a comprobar nada.
        nombresGrupos: lista(
          dest['gruposIds'],
        ).map((String g) => nombresPorId[g] ?? g).toList(),
        formato: lista(x['formato']),
        proximaOcurrencia: (x['proximaOcurrencia'] as Timestamp?)?.toDate(),
        enviadoEn: (x['enviadoEn'] as Timestamp?)?.toDate(),
        totalDestinatarios: (x['totalDestinatarios'] as num?)?.toInt() ?? 0,
        entregados: (resumen['entregados'] as num?)?.toInt() ?? 0,
        confirmados: (resumen['confirmados'] as num?)?.toInt() ?? 0,
      );
    }).toList();
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

  /// Quién recibió y quién confirmó (RF-CNF-06).
  ///
  /// Pasa por el servidor porque una administradora no puede leer la lista de
  /// usuarios —las reglas solo se la abren al coordinador y al auditor—, y
  /// tampoco la necesita: para saber quién no confirmó su aviso basta con los
  /// destinatarios de ese aviso.
  Future<List<DestinatarioEntrega>> detalleEntregas(String mensajeId) async {
    final HttpsCallableResult<Object?> r = await _fn
        .httpsCallable('detalleEntregas')
        .call<Object?>(<String, Object?>{'mensajeId': mensajeId});

    final Map<Object?, Object?> d =
        (r.data as Map<Object?, Object?>?) ?? <Object?, Object?>{};
    final List<Object?> lista =
        (d['destinatarios'] as List<Object?>?) ?? <Object?>[];

    return lista.map((Object? o) {
      final Map<Object?, Object?> m = (o as Map<Object?, Object?>?) ?? {};
      final String? confirmado = m['confirmadoEn'] as String?;
      return DestinatarioEntrega(
        uid: (m['uid'] as String?) ?? '',
        nombre: (m['nombre'] as String?) ?? '',
        correo: (m['correo'] as String?) ?? '',
        estado: (m['estado'] as String?) ?? '',
        confirmadoEn: confirmado == null ? null : DateTime.tryParse(confirmado),
      );
    }).toList();
  }

  /// Marca como abierto (RF-CNF-02). No sustituye a confirmar.
  Future<void> marcarAbierto(String mensajeId) async {
    await _fn.httpsCallable('marcarAbierto').call<Object?>(<String, Object?>{
      'mensajeId': mensajeId,
    });
  }
}
