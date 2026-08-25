/// SIAN — Historial de mensajes recibidos por un catedrático (RF-ENT-12).
///
/// La consulta es la que declara el documento 05, sección 4: grupo de
/// colecciones sobre `entregas`, filtrando por `uid` y ordenando por
/// `entregadoEn` descendente. Por eso el campo `uid` se duplica dentro del
/// documento aunque ya sea su identificador: una consulta de grupo de
/// colecciones no puede filtrar por identificador de documento.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositorios.dart';

class RepositorioBandejaFirebase implements RepositorioBandeja {
  RepositorioBandejaFirebase({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Límite de la bandeja. A la escala del documento 05 nadie tiene más
  /// mensajes que esto sin paginar.
  static const int _limite = 50;

  /// Contenido de los mensajes ya leídos, por identificador.
  ///
  /// ──────────────────────────────────────────────────────────────────────────
  /// EL CONTENIDO DE UN MENSAJE NO CAMBIA. LA ENTREGA SÍ.
  /// ──────────────────────────────────────────────────────────────────────────
  ///
  /// Lo que se mueve es la entrega —entregado, abierto, confirmado—, y eso ya
  /// llega en el propio flujo. El título, el cuerpo, el tipo y los adjuntos se
  /// escriben una vez y no se vuelven a tocar: un aviso enviado no se edita.
  ///
  /// Sin esta memoria, **cada emisión del flujo volvía a pedir por red los
  /// cincuenta mensajes enteros**. Y el flujo emite mucho: al abrir la bandeja,
  /// al llegar un aviso, y otra vez cada vez que alguien despliega uno y su
  /// entrega pasa a «abierto». El efecto en la mano era que la bandeja tardaba
  /// unos segundos en mostrar lo que tenía, y durante esa espera enseñaba una
  /// lista incompleta —que es peor que no enseñar nada, porque afirma algo
  /// falso: «está al día».
  ///
  /// Con la memoria, la primera carga paga las lecturas y las siguientes solo
  /// piden lo que no habían visto: normalmente el mensaje que acaba de llegar.
  final Map<String, Map<String, dynamic>> _contenidoConocido =
      <String, Map<String, dynamic>>{};

  @override
  Stream<List<MensajeRecibido>> observarHistorial(String uid) {
    return _firestore
        .collectionGroup('entregas')
        .where('uid', isEqualTo: uid)
        .orderBy('entregadoEn', descending: true)
        .limit(_limite)
        .snapshots()
        .asyncMap(_combinarConMensajes);
  }

  /// Combina las entregas con el contenido de sus mensajes.
  ///
  /// La entrega guarda `mensajeId` desnormalizado, pero no el título ni el
  /// cuerpo, así que hace falta una segunda lectura.
  ///
  /// ──────────────────────────────────────────────────────────────────────────
  /// UNA LECTURA POR MENSAJE, Y NO UNA CONSULTA POR LOTES.
  /// ──────────────────────────────────────────────────────────────────────────
  ///
  /// Antes se pedían de treinta en treinta con `whereIn` sobre el
  /// identificador: dos consultas en vez de cincuenta y una. Más barato, y
  /// **prohibido para un catedrático**.
  ///
  /// Firestore no filtra las consultas: o puede demostrar de antemano que todo
  /// lo que devolverían cumple la regla, o rechaza la consulta entera. La regla
  /// de `mensajes` dice «puedes leerlo si tu identificador está en su lista de
  /// destinatarios», y eso solo se sabe mirando cada documento. Una consulta
  /// por identificador no lo garantiza, así que se rechazaba con
  /// `permission-denied`.
  ///
  /// El fallo estuvo escondido porque el coordinador y el auditor pueden leer
  /// `mensajes` sin condiciones: para ellos la regla es cierta sin mirar
  /// ningún documento, la consulta se aprueba, y la bandeja funcionaba. Solo
  /// aparecía al entrar con una cuenta de catedrático de verdad — es decir,
  /// con la única cuenta para la que se construyó esta pantalla.
  ///
  /// Una lectura suelta sí se evalúa documento por documento, y ahí la regla
  /// se cumple. Son como mucho cincuenta lecturas por apertura de bandeja, que
  /// a la escala de la sede no es nada comparado con no poder abrirla.
  Future<List<MensajeRecibido>> _combinarConMensajes(
    QuerySnapshot<Map<String, dynamic>> entregas,
  ) async {
    if (entregas.docs.isEmpty) {
      return const <MensajeRecibido>[];
    }

    final List<String> ids = entregas.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> d) {
          return (d.data()['mensajeId'] as String?) ?? '';
        })
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList();

    final List<String> porLeer = ids
        .where((String id) => !_contenidoConocido.containsKey(id))
        .toList();

    if (porLeer.isNotEmpty) {
      final List<DocumentSnapshot<Map<String, dynamic>>> documentos =
          await Future.wait(
            porLeer.map(
              (String id) => _firestore.collection('mensajes').doc(id).get(),
            ),
          );

      for (final DocumentSnapshot<Map<String, dynamic>> doc in documentos) {
        final Map<String, dynamic>? datos = doc.data();
        if (datos != null) {
          _contenidoConocido[doc.id] = datos;
        }
      }
    }

    final Map<String, Map<String, dynamic>> mensajes = _contenidoConocido;

    final List<MensajeRecibido> recibidos = <MensajeRecibido>[];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> entrega
        in entregas.docs) {
      final Map<String, dynamic> datos = entrega.data();
      final String mensajeId = (datos['mensajeId'] as String?) ?? '';
      final Map<String, dynamic>? mensaje = mensajes[mensajeId];

      // Sin el mensaje no hay nada que mostrar. Puede pasar si el emisor no
      // es visible para este usuario, aunque las reglas lo permiten cuando
      // está en `destinatariosUids` (documento 05, sección 5).
      if (mensaje == null) {
        continue;
      }

      final List<AdjuntoRecibido> adjuntos = _adjuntosDe(mensaje);

      recibidos.add(
        MensajeRecibido(
          mensajeId: mensajeId,
          titulo: (mensaje['titulo'] as String?) ?? '',
          cuerpo: (mensaje['cuerpo'] as String?) ?? '',
          tipo: (mensaje['tipo'] as String?) ?? 'INFORMATIVO',
          estado: (datos['estado'] as String?) ?? 'PENDIENTE',
          requiereConfirmacion: mensaje['requiereConfirmacion'] == true,
          emisor: (mensaje['creadoPorNombre'] as String?) ?? '',
          entregadoEn: (datos['entregadoEn'] as Timestamp?)?.toDate(),
          abiertoEn: (datos['abiertoEn'] as Timestamp?)?.toDate(),
          confirmadoEn: (datos['confirmadoEn'] as Timestamp?)?.toDate(),
          adjuntos: adjuntos,
        ),
      );
    }

    return recibidos;
  }
}

/// Lee un mapa anidado sin presuponer el tipo de sus claves.
///
/// ────────────────────────────────────────────────────────────────────────────
/// `as Map<String, dynamic>` sobre un mapa anidado NO es seguro en web.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Firestore entrega el documento como `Map<String, dynamic>`, pero lo que hay
/// dentro pasa por la conversión desde JavaScript y puede llegar como
/// `Map<Object?, Object?>`. Según la versión del complemento, ese `as` o bien
/// lanza —y entonces se cae la bandeja entera, no solo el adjunto— o bien
/// devuelve algo que luego no encuentra la clave.
///
/// Leerlo así cuesta lo mismo y funciona en los dos casos. Es el tipo de
/// suposición que solo falla en producción, sobre un dispositivo ajeno.
Map<Object?, Object?>? _comoMapa(Object? valor) =>
    valor is Map ? valor.cast<Object?, Object?>() : null;

/// Los adjuntos del mensaje, en orden.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Entiende la forma nueva y la antigua. Las dos, a propósito.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Hasta ahora un mensaje llevaba como mucho `{audio, imagen}`. Los mensajes ya
/// enviados no se reescriben (RN-03), así que dejar de entender esa forma
/// borraría los adjuntos de todo lo entregado hasta hoy: seguirían en Storage,
/// pero nadie sabría que existen.
///
/// En la forma antigua la voz se mostraba primero, y se conserva ese orden: es
/// el único que esos mensajes llegaron a tener.
List<AdjuntoRecibido> _adjuntosDe(Map<String, dynamic> mensaje) {
  final Map<Object?, Object?>? adjuntos = _comoMapa(mensaje['adjuntos']);
  if (adjuntos == null) {
    return const <AdjuntoRecibido>[];
  }

  final Object? lista = adjuntos['lista'];
  if (lista is List && lista.isNotEmpty) {
    final List<AdjuntoRecibido> salida = <AdjuntoRecibido>[];
    for (final Object? bruto in lista) {
      final AdjuntoRecibido? uno = _adjuntoDe(_comoMapa(bruto), null);
      if (uno != null) {
        salida.add(uno);
      }
    }
    return salida;
  }

  return <AdjuntoRecibido>[
    ?_adjuntoDe(_comoMapa(adjuntos['audio']), 'AUDIO'),
    ?_adjuntoDe(_comoMapa(adjuntos['imagen']), 'IMAGEN'),
  ];
}

/// Un adjunto suelto. [tipoFijo] es para la forma antigua, donde el tipo lo
/// decía la clave del mapa y no venía dentro.
AdjuntoRecibido? _adjuntoDe(Map<Object?, Object?>? uno, String? tipoFijo) {
  if (uno == null) {
    return null;
  }
  final Object? ruta = uno['ruta'];
  if (ruta is! String || ruta.isEmpty) {
    return null;
  }

  final Object? tipo = tipoFijo ?? uno['tipo'];
  final Object? duracion = uno['duracionSeg'];

  return AdjuntoRecibido(
    tipo: tipo is String && tipo.isNotEmpty ? tipo : 'IMAGEN',
    ruta: ruta,
    duracionSeg: duracion is num ? duracion.toInt() : null,
  );
}
