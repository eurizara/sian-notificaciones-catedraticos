/// SIAN — Tema claro, oscuro o el del dispositivo (DT-21, mejora M-4).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Por omisión, lo que diga el dispositivo
/// ────────────────────────────────────────────────────────────────────────────
///
/// Quien tiene el teléfono en oscuro ya lo decidió una vez, para todo. Pedirle
/// que lo vuelva a decidir para SIAN es trabajo de más; y abrir de noche un
/// aviso en blanco deslumbrante, cuando todo lo demás del teléfono es oscuro,
/// es la clase de detalle que hace que una aplicación se sienta ajena.
///
/// La elección manual existe para quien quiere otra cosa aquí —leer en claro a
/// pleno sol aunque el teléfono esté en oscuro—, no para obligar a elegir.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Se guarda en el navegador, no en la cuenta
/// ────────────────────────────────────────────────────────────────────────────
///
/// La apariencia es del dispositivo: la misma persona puede querer oscuro en el
/// teléfono y claro en la computadora de la sede. Guardarla en Firestore
/// además la haría viajar a cada arranque, para algo que no le importa a nadie
/// más que a esa pantalla.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/plataforma/almacen_local.dart';
import 'textos.dart';

enum PreferenciaTema {
  sistema(ThemeMode.system, Icons.brightness_auto_outlined, Textos.temaSistema),
  claro(ThemeMode.light, Icons.light_mode_outlined, Textos.temaClaro),
  oscuro(ThemeMode.dark, Icons.dark_mode_outlined, Textos.temaOscuro);

  const PreferenciaTema(this.modo, this.icono, this.etiqueta);

  final ThemeMode modo;
  final IconData icono;
  final String etiqueta;

  /// Lo guardado, o el valor por omisión si no hay nada o no se entiende. Un
  /// valor desconocido —de una versión futura, o escrito a mano— no rompe el
  /// arranque: vuelve a lo del dispositivo.
  static PreferenciaTema desde(String? guardado) =>
      PreferenciaTema.values.firstWhere(
        (PreferenciaTema p) => p.name == guardado,
        orElse: () => sistema,
      );
}

class Apariencia extends Notifier<PreferenciaTema> {
  static const String clave = 'sian.apariencia';

  @override
  PreferenciaTema build() => PreferenciaTema.desde(leerLocal(clave));

  void elegir(PreferenciaTema preferencia) {
    state = preferencia;
    guardarLocal(clave, preferencia.name);
  }
}

final NotifierProvider<Apariencia, PreferenciaTema> aparienciaProvider =
    NotifierProvider<Apariencia, PreferenciaTema>(Apariencia.new);

/// El botón de la barra superior que abre las tres opciones.
///
/// Un menú y no un botón que alterna: alternar entre tres estados obliga a
/// pulsar sin saber qué viene después, y «lo del dispositivo» no tiene un
/// icono que se entienda solo. El menú enseña las tres y marca la elegida.
class SelectorApariencia extends ConsumerWidget {
  const SelectorApariencia({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PreferenciaTema actual = ref.watch(aparienciaProvider);
    return PopupMenuButton<PreferenciaTema>(
      icon: Icon(actual.icono),
      tooltip: Textos.botonApariencia(actual.etiqueta),
      initialValue: actual,
      onSelected: ref.read(aparienciaProvider.notifier).elegir,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<PreferenciaTema>>[
        for (final PreferenciaTema p in PreferenciaTema.values)
          CheckedPopupMenuItem<PreferenciaTema>(
            value: p,
            checked: p == actual,
            child: Text(p.etiqueta),
          ),
      ],
    );
  }
}
