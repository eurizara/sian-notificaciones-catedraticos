/// SIAN — Las sedes de una persona (2.0.1 · RF-SED-02, RF-SED-06).
///
/// El superadministrador decide en qué sedes está cada persona, con qué rol y,
/// desde la 2.0.6, con qué facultades en cada una: solo entre las que esa sede
/// ofrece. Se abre desde Usuarios, donde se maneja todo lo de una persona.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_catalogos.dart';
import '../../infrastructure/firebase/repositorio_administracion.dart';
import '../../infrastructure/firebase/repositorio_catalogos.dart';
import '../shared/textos.dart';

const Map<String, String> _roles = <String, String>{
  'CATEDRATICO': 'Catedrático',
  'ADMINISTRADORA': 'Administradora',
  'AUDITOR': 'Auditor',
  'COORDINADOR': 'Coordinador',
};

/// En qué sedes está una persona y con qué rol. Se guarda todo junto: primero
/// altas y cambios, después bajas. La administración general se da en
/// Usuarios, que es donde la coordinación maneja a su gente (2.0.3).
class DialogoSedes extends ConsumerStatefulWidget {
  const DialogoSedes({required this.persona, required this.sedes, super.key});

  final UsuarioVista persona;
  final List<ElementoCatalogo> sedes;

  @override
  ConsumerState<DialogoSedes> createState() => _DialogoSedesState();
}

class _DialogoSedesState extends ConsumerState<DialogoSedes> {
  late final Map<String, MembresiaDeseada> _actual = <String, MembresiaDeseada>{
    for (final MapEntry<String, String> e in widget.persona.sedesConRol.entries)
      e.key: MembresiaDeseada(
        e.value,
        widget.persona.facultadesEn(e.key).toSet(),
      ),
  };
  late final Map<String, MembresiaDeseada> _deseado =
      <String, MembresiaDeseada>{..._actual};
  bool _guardando = false;
  String? _error;

  Future<void> _guardar() async {
    if (_deseado.isEmpty) {
      setState(() => _error = Textos.sedesAlMenosUna);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    final RepositorioPersonasYSedes repo = ref.read(
      repositorioPersonasYSedesProvider,
    );
    final String uid = widget.persona.uid;
    try {
      for (final CambioDeSede c in cambiosDeSedes(_actual, _deseado)) {
        switch (c) {
          case AsignarSede(
            :final String sedeId,
            :final String rol,
            :final List<String> facultades,
          ):
            await repo.asignarSede(
              uid: uid,
              sedeId: sedeId,
              rol: rol,
              facultades: facultades,
            );
          case QuitarSede(:final String sedeId):
            await repo.quitarSede(uid: uid, sedeId: sedeId);
        }
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(Textos.sedesGuardadas)));
      }
    } on FirebaseFunctionsException catch (e) {
      // El servidor dice qué corregir: «Es su única sede…».
      setState(() {
        _guardando = false;
        _error = e.message ?? Textos.catalogoNoSeGuardo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String nombre = widget.persona.nombre.isEmpty
        ? widget.persona.correo
        : widget.persona.nombre;
    final bool bloqueado = _guardando;
    return AlertDialog(
      title: Text(Textos.sedesDe(nombre)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final ElementoCatalogo s in widget.sedes)
                if (s.activa || _deseado.containsKey(s.id))
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(s.nombre),
                              value: _deseado.containsKey(s.id),
                              onChanged: bloqueado
                                  ? null
                                  : (bool? v) => setState(() {
                                      if (v ?? false) {
                                        _deseado[s.id] =
                                            _actual[s.id] ??
                                            const MembresiaDeseada(
                                              'CATEDRATICO',
                                            );
                                      } else {
                                        _deseado.remove(s.id);
                                      }
                                    }),
                            ),
                          ),
                          if (_deseado.containsKey(s.id))
                            DropdownButton<String>(
                              value: _deseado[s.id]?.rol,
                              // El rol en esa sede; el nombre accesible dice dónde.
                              hint: Text(Textos.rolEn(s.nombre)),
                              items: <DropdownMenuItem<String>>[
                                for (final MapEntry<String, String> r
                                    in _roles.entries)
                                  DropdownMenuItem<String>(
                                    value: r.key,
                                    child: Text(r.value),
                                  ),
                              ],
                              onChanged: bloqueado
                                  ? null
                                  : (String? v) => setState(
                                      () => _deseado[s.id] = _deseado[s.id]!
                                          .conRol(v ?? 'CATEDRATICO'),
                                    ),
                            ),
                        ],
                      ),
                      // 2.0.6: sus facultades en esa sede, solo entre
                      // las que la sede ofrece.
                      if (_deseado.containsKey(s.id))
                        _FacultadesEnSede(
                          key: ValueKey<String>('facultades-${s.id}'),
                          sede: s,
                          elegidas: _deseado[s.id]!.facultades,
                          bloqueado: bloqueado,
                          alCambiar: (String f, bool tiene) => setState(
                            () => _deseado[s.id] = _deseado[s.id]!.conFacultad(
                              f,
                              tiene: tiene,
                            ),
                          ),
                        ),
                    ],
                  ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text(Textos.botonCancelar),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? Textos.grupoGuardando : Textos.grupoGuardar),
        ),
      ],
    );
  }
}

/// Las facultades de la persona en una sede: solo las que la sede ofrece (y
/// las que ya tenía, para poder quitárselas).
class _FacultadesEnSede extends ConsumerWidget {
  const _FacultadesEnSede({
    required this.sede,
    required this.elegidas,
    required this.bloqueado,
    required this.alCambiar,
    super.key,
  });

  final ElementoCatalogo sede;
  final Set<String> elegidas;
  final bool bloqueado;
  final void Function(String facultad, bool tiene) alCambiar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<ElementoCatalogo>? ofrecidas = ref
        .watch(facultadesDeLaSedeProvider(sede.id))
        .value;
    if (ofrecidas == null) {
      return const SizedBox.shrink();
    }
    final List<ElementoCatalogo> opciones = ordenarCatalogo(
      ofrecidas.where(
        (ElementoCatalogo f) => f.activa || elegidas.contains(f.id),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            Textos.facultadesEnSede(sede.nombre),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          if (opciones.isEmpty)
            Text(Textos.sedeSinFacultades(sede.nombre))
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                for (final ElementoCatalogo f in opciones)
                  FilterChip(
                    label: Text(f.nombre),
                    tooltip: Textos.facultadesEnSede(sede.nombre),
                    selected: elegidas.contains(f.id),
                    onSelected: bloqueado
                        ? null
                        : (bool v) => alCambiar(f.id, v),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
