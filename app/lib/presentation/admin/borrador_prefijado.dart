/// SIAN — Un aviso a medio preparar desde otra sección (1.6, Alcance).
///
/// Alcance sabe quién sigue sin la última versión; redactar sabe enviar. Para
/// «Enviar recordatorio a estas N personas» no hace falta copiar nombres a
/// mano: Alcance deja aquí las personas y un texto sugerido, el panel pasa a
/// Mensajes, y el formulario lo recoge **una sola vez**. El texto se puede
/// cambiar antes de enviar, y la confirmación sigue diciendo los nombres.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/firebase/repositorio_envio.dart';

@immutable
class BorradorPrefijado {
  const BorradorPrefijado({
    required this.personas,
    this.titulo = '',
    this.cuerpo = '',
  });

  final List<PersonaDestinataria> personas;
  final String titulo;
  final String cuerpo;
}

class BorradorPendiente extends Notifier<BorradorPrefijado?> {
  @override
  BorradorPrefijado? build() => null;

  void preparar(BorradorPrefijado borrador) => state = borrador;

  /// Lo toma el formulario: se entrega una vez y se olvida.
  BorradorPrefijado? tomar() {
    final BorradorPrefijado? b = state;
    state = null;
    return b;
  }
}

final NotifierProvider<BorradorPendiente, BorradorPrefijado?>
borradorPrefijadoProvider =
    NotifierProvider<BorradorPendiente, BorradorPrefijado?>(
      BorradorPendiente.new,
    );
