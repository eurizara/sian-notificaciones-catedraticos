/// SIAN — Qué facultades ofrece una sede (2.0.6).
///
/// Se eligen del catálogo único de la UMG, no se escriben: así «Ingeniería en
/// Sistemas» es la misma en todas las sedes. El superadministrador elige la
/// sede; la coordinación ve la suya. Si alguien de la sede tiene asignada una
/// facultad, el servidor no deja retirarla y dice cuántos la tienen: el
/// mensaje se muestra tal cual, porque dice qué hacer.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_catalogos.dart';
import '../../infrastructure/firebase/repositorio_catalogos.dart';
import '../shared/textos.dart';

class OfertaDeFacultades extends ConsumerStatefulWidget {
  const OfertaDeFacultades({
    required this.sedeInicial,
    required this.puedeElegirSede,
    super.key,
  });

  /// La sede de trabajo.
  final String sedeInicial;

  /// Solo el superadministrador elige otra sede.
  final bool puedeElegirSede;

  @override
  ConsumerState<OfertaDeFacultades> createState() => _OfertaDeFacultadesState();
}

class _OfertaDeFacultadesState extends ConsumerState<OfertaDeFacultades> {
  late String _sede = widget.sedeInicial;
  String? _guardando;
  String? _error;

  Future<void> _cambiar(
    ElementoCatalogo facultad,
    String nombreSede, {
    required bool ofrecer,
  }) async {
    setState(() {
      _guardando = facultad.id;
      _error = null;
    });
    try {
      await ref
          .read(repositorioOfertaFacultadesProvider)
          .ofrecer(sedeId: _sede, facultadId: facultad.id, ofrecer: ofrecer);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ofrecer
                  ? Textos.ofertaOfrecida(facultad.nombre, nombreSede)
                  : Textos.ofertaRetirada(facultad.nombre, nombreSede),
            ),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      // «La tienen 2 personas en esta sede. Quítesela primero en Usuarios…»
      if (mounted) {
        setState(() => _error = e.message ?? Textos.catalogoNoSeGuardo);
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ElementoCatalogo>? catalogo = ref
        .watch(catalogoFacultadesProvider)
        .value;
    final List<ElementoCatalogo>? ofrecidas = ref
        .watch(facultadesDeLaSedeProvider(_sede))
        .value;
    final List<ElementoCatalogo> sedes = widget.puedeElegirSede
        ? (ref.watch(sedesProvider).value ?? const <ElementoCatalogo>[])
        : const <ElementoCatalogo>[];
    final String nombreSede =
        sedes
            .where((ElementoCatalogo s) => s.id == _sede)
            .map((ElementoCatalogo s) => s.nombre)
            .firstOrNull ??
        ref.watch(nombreDeSedeProvider(_sede)).value ??
        _sede;
    final Set<String> ofrecidasIds = <String>{
      for (final ElementoCatalogo f in ofrecidas ?? const <ElementoCatalogo>[])
        if (f.activa) f.id,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.puedeElegirSede && sedes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DropdownButtonFormField<String>(
              initialValue: _sede,
              decoration: const InputDecoration(labelText: Textos.ofertaSede),
              items: <DropdownMenuItem<String>>[
                for (final ElementoCatalogo s in sedes)
                  if (s.activa || s.id == _sede)
                    DropdownMenuItem<String>(
                      value: s.id,
                      child: Text(s.nombre),
                    ),
              ],
              onChanged: _guardando != null
                  ? null
                  : (String? v) => setState(() {
                      _sede = v ?? _sede;
                      _error = null;
                    }),
            ),
          ),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(Textos.ofertaExplicacion),
        ),
        if (catalogo == null || ofrecidas == null)
          const Text('Cargando…')
        else if (catalogo.isEmpty)
          const Text(Textos.ofertaCatalogoVacio)
        else
          for (final ElementoCatalogo f in ordenarCatalogo(catalogo))
            if (f.activa || ofrecidasIds.contains(f.id))
              CheckboxListTile(
                key: ValueKey<String>('oferta-$_sede-${f.id}'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(f.nombre),
                subtitle: f.activa
                    ? null
                    : const Text(Textos.ofertaDesactivadaEnCatalogo),
                value: ofrecidasIds.contains(f.id),
                onChanged: _guardando != null
                    ? null
                    : (bool? v) => _cambiar(f, nombreSede, ofrecer: v ?? false),
              ),
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
      ],
    );
  }
}
