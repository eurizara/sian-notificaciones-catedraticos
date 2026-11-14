/// SIAN — En qué sede está el catedrático, y qué tiene en las otras (2.0.8).
///
/// Quien da clases en dos sedes —o en dos facultades— tiene que ver, sin
/// buscarlo, dónde está: en un teléfono la barra no tiene sitio para decirlo.
/// La bandeja muestra los avisos de la sede de trabajo; los de las otras no
/// pueden quedar escondidos, y menos una urgente: se dice cuántos hay sin leer
/// en cada una y se cambia de un toque.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_catalogos.dart';
import '../../application/proveedores_sede.dart';
import '../../domain/repositorios.dart';
import '../../domain/sesion.dart';
import '../../infrastructure/firebase/repositorio_catalogos.dart';
import '../shared/textos.dart';
import 'filtro_bandeja.dart';

/// Lo pendiente de una sede que no es la de trabajo.
typedef PendienteEnSede = ({String sede, int sinLeer, int urgentes});

/// Lo pendiente en las otras sedes, en el orden de las sedes de la persona.
/// Puro, para probarlo sin montar nada.
List<PendienteEnSede> pendientesEnOtrasSedes(
  Iterable<String> sedes,
  String actual,
  List<MensajeRecibido> todos,
) {
  return <PendienteEnSede>[
    for (final String s in sedes)
      if (s != actual)
        (
          sede: s,
          sinLeer: todos
              .where(
                (MensajeRecibido m) =>
                    m.sedeId == s && entraEn(FiltroBandeja.sinLeer, m),
              )
              .length,
          urgentes: todos
              .where((MensajeRecibido m) => m.sedeId == s && m.exigeAtencion)
              .length,
        ),
  ].where((PendienteEnSede p) => p.sinLeer > 0 || p.urgentes > 0).toList();
}

class SedeEnBandeja extends ConsumerWidget {
  const SedeEnBandeja({
    required this.usuario,
    required this.sede,
    required this.todos,
    super.key,
  });

  final UsuarioSesion usuario;
  final String sede;

  /// Los avisos de todas sus sedes.
  final List<MensajeRecibido> todos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData tema = Theme.of(context);
    final bool variasSedes = usuario.sedes.length > 1;
    String nombreSede(String id) =>
        ref.watch(nombreDeSedeProvider(id)).value ?? id;
    final List<String> mias =
        ref
            .watch(misFacultadesProvider((uid: usuario.uid, sede: sede)))
            .value ??
        const <String>[];
    final List<ElementoCatalogo> ofrecidas =
        ref.watch(facultadesDeLaSedeProvider(sede)).value ??
        const <ElementoCatalogo>[];
    final List<String> nombresFacultades = <String>[
      for (final String f in mias)
        ofrecidas
                .where((ElementoCatalogo e) => e.id == f)
                .map((ElementoCatalogo e) => e.nombre)
                .firstOrNull ??
            f,
    ];
    // Con una sede y una facultad (o ninguna) no hay nada que aclarar.
    if (!variasSedes && nombresFacultades.length < 2) {
      return const SizedBox.shrink();
    }
    final List<PendienteEnSede> otras = variasSedes
        ? pendientesEnOtrasSedes(usuario.sedes.keys, sede, todos)
        : const <PendienteEnSede>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.location_on_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        Textos.estaEnSede(nombreSede(sede)),
                        style: tema.textTheme.titleSmall,
                      ),
                      if (nombresFacultades.isNotEmpty)
                        Text(
                          Textos.susFacultades(nombresFacultades),
                          style: tema.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (variasSedes)
                  PopupMenuButton<String>(
                    tooltip: Textos.cambiarDeSede,
                    initialValue: sede,
                    onSelected: (String id) =>
                        ref.read(sedeDeTrabajoProvider.notifier).elegir(id),
                    itemBuilder: (BuildContext _) => <PopupMenuEntry<String>>[
                      for (final String id in usuario.sedes.keys)
                        CheckedPopupMenuItem<String>(
                          value: id,
                          checked: id == sede,
                          child: Text(nombreSede(id)),
                        ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: Text(
                        Textos.cambiarDeSede,
                        style: tema.textTheme.labelLarge?.copyWith(
                          color: tema.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Lo de las otras sedes no se esconde: se dice y se va de un toque.
            for (final PendienteEnSede p in otras)
              Semantics(
                liveRegion: true,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        ref.read(sedeDeTrabajoProvider.notifier).elegir(p.sede),
                    icon: Icon(
                      p.urgentes > 0
                          ? Icons.warning_amber_rounded
                          : Icons.mark_email_unread_outlined,
                      color: p.urgentes > 0 ? tema.colorScheme.error : null,
                    ),
                    label: Text(
                      Textos.pendienteEnOtraSede(
                        nombreSede(p.sede),
                        sinLeer: p.sinLeer,
                        urgentes: p.urgentes,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
