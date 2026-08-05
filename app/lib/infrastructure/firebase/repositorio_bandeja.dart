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

  /// Tope de Firestore para el operador `whereIn`.
  static const int _tamanoLote = 30;

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
  /// cuerpo, así que hace falta una segunda lectura. Se hace **por lotes** con
  /// `whereIn` en lugar de una lectura por fila: con 50 mensajes, son 2
  /// consultas en vez de 51.
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

    final Map<String, Map<String, dynamic>> mensajes =
        <String, Map<String, dynamic>>{};

    for (int i = 0; i < ids.length; i += _tamanoLote) {
      final List<String> lote = ids.sublist(
        i,
        (i + _tamanoLote).clamp(0, ids.length),
      );
      final QuerySnapshot<Map<String, dynamic>> resultado = await _firestore
          .collection('mensajes')
          .where(FieldPath.documentId, whereIn: lote)
          .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in resultado.docs) {
        mensajes[doc.id] = doc.data();
      }
    }

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

      recibidos.add(
        MensajeRecibido(
          mensajeId: mensajeId,
          titulo: (mensaje['titulo'] as String?) ?? '',
          cuerpo: (mensaje['cuerpo'] as String?) ?? '',
          tipo: (mensaje['tipo'] as String?) ?? 'INFORMATIVO',
          estado: (datos['estado'] as String?) ?? 'PENDIENTE',
          requiereConfirmacion: mensaje['requiereConfirmacion'] == true,
          entregadoEn: (datos['entregadoEn'] as Timestamp?)?.toDate(),
          abiertoEn: (datos['abiertoEn'] as Timestamp?)?.toDate(),
          confirmadoEn: (datos['confirmadoEn'] as Timestamp?)?.toDate(),
          rutaVoz: _rutaDe(mensaje, 'audio'),
          duracionVozSeg: _duracionDe(mensaje),
          rutaImagen: _rutaDe(mensaje, 'imagen'),
        ),
      );
    }

    return recibidos;
  }
}

/// Ruta de un adjunto dentro del mapa `adjuntos` del mensaje.
String? _rutaDe(Map<String, dynamic> mensaje, String clave) {
  final Map<String, dynamic>? adjuntos =
      mensaje['adjuntos'] as Map<String, dynamic>?;
  final Map<String, dynamic>? uno = adjuntos?[clave] as Map<String, dynamic>?;
  final String? ruta = uno?['ruta'] as String?;
  return (ruta == null || ruta.isEmpty) ? null : ruta;
}

int? _duracionDe(Map<String, dynamic> mensaje) {
  final Map<String, dynamic>? adjuntos =
      mensaje['adjuntos'] as Map<String, dynamic>?;
  final Map<String, dynamic>? audio =
      adjuntos?['audio'] as Map<String, dynamic>?;
  return (audio?['duracionSeg'] as num?)?.toInt();
}
