/// SIAN — Tocar una notificación lleva a lo que la originó (RF-ENT-07, C-6).
///
/// ────────────────────────────────────────────────────────────────────────────
/// El fallo que corrige (DT-35, 24/09/2026)
/// ────────────────────────────────────────────────────────────────────────────
///
/// Tocar cualquier notificación dejaba la aplicación en la bandeja, en «Sin
/// leer». Con un aviso nuevo no se notaba: salía arriba. Con una **respuesta** a
/// un aviso ya leído no había forma de llegar a ella desde la notificación.
///
/// Ahora el worker dice a dónde lleva cada notificación. La aplicación lo
/// recibe por uno de dos caminos (ver `core/plataforma/apertura_web.dart`) y lo
/// guarda aquí como **pendiente** hasta que la pantalla que sabe atenderlo lo
/// atiende:
///
///   · la bandeja, para un **aviso**: lo muestra y lo despliega, **esté en el
///     filtro que esté**. Es el criterio que fijó el responsable;
///   · el panel, para una **conversación**: abre esa conversación.
///
/// Queda pendiente, y no se pierde, si llega antes de que haya sesión: se
/// atiende después de entrar.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/plataforma/apertura.dart';

enum TipoApertura {
  /// Un aviso. Para el catedrático también es «su conversación», que está
  /// dentro del aviso.
  aviso,

  /// La conversación con una persona sobre un aviso: la que ve quien lo envió.
  hilo,
}

@immutable
class DestinoApertura {
  const DestinoApertura.aviso(this.avisoId)
    : tipo = TipoApertura.aviso,
      hiloUid = null;

  const DestinoApertura.hilo(this.avisoId, String this.hiloUid)
    : tipo = TipoApertura.hilo;

  final TipoApertura tipo;
  final String avisoId;
  final String? hiloUid;

  static final RegExp _identificador = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  /// Lee el destino de la dirección o del aviso del worker.
  ///
  /// Mismo formato en los dos: `abrir`, `aviso` y, para una conversación,
  /// `hilo`. Lo que no tiene forma de identificador se descarta: estos valores
  /// terminan en consultas a Firestore.
  static DestinoApertura? desde(Map<String, String> datos) {
    final String aviso = datos['aviso'] ?? '';
    if (!_identificador.hasMatch(aviso)) {
      return null;
    }
    switch (datos['abrir']) {
      case 'aviso':
        return DestinoApertura.aviso(aviso);
      case 'hilo':
        final String hilo = datos['hilo'] ?? '';
        // Sin conversación válida, el aviso sigue siendo un buen destino.
        return _identificador.hasMatch(hilo)
            ? DestinoApertura.hilo(aviso, hilo)
            : DestinoApertura.aviso(aviso);
      default:
        return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DestinoApertura &&
      other.tipo == tipo &&
      other.avisoId == avisoId &&
      other.hiloUid == hiloUid;

  @override
  int get hashCode => Object.hash(tipo, avisoId, hiloUid);

  @override
  String toString() => 'DestinoApertura($tipo, $avisoId, $hiloUid)';
}

/// El destino que falta atender, o nulo.
class AperturaPendiente extends Notifier<DestinoApertura?> {
  @override
  DestinoApertura? build() {
    // La dirección con la que arrancó: el worker abrió una ventana nueva.
    final DestinoApertura? inicial = DestinoApertura.desde(
      parametrosDeApertura(),
    );
    if (inicial != null) {
      // Se borra de la dirección: recargar no debe volver a abrirlo.
      limpiarParametrosDeApertura();
    }
    return inicial;
  }

  void fijar(DestinoApertura destino) => state = destino;

  /// Lo llama la pantalla que lo atendió, o que decidió que no puede.
  void consumir() => state = null;
}

final NotifierProvider<AperturaPendiente, DestinoApertura?>
aperturaPendienteProvider =
    NotifierProvider<AperturaPendiente, DestinoApertura?>(
      AperturaPendiente.new,
    );

/// Escucha al worker mientras la aplicación está abierta.
///
/// Va en la raíz, una sola vez: el aviso puede llegar en cualquier pantalla, y
/// la que sabe atenderlo lo recoge del proveedor.
class EscuchaDeAperturas extends ConsumerStatefulWidget {
  const EscuchaDeAperturas({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<EscuchaDeAperturas> createState() => _EscuchaDeAperturasState();
}

class _EscuchaDeAperturasState extends ConsumerState<EscuchaDeAperturas> {
  @override
  void initState() {
    super.initState();
    // Se lee ya, para que el destino con que arrancó quede fijado aunque la
    // sesión tarde en cargar.
    ref.read(aperturaPendienteProvider);
    escucharAperturas((Map<String, String> datos) {
      final DestinoApertura? destino = DestinoApertura.desde(datos);
      if (destino != null && mounted) {
        ref.read(aperturaPendienteProvider.notifier).fijar(destino);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
