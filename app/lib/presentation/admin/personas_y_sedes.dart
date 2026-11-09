/// SIAN — Personas y sedes (2.0.1 · RF-SED-02, RF-SED-06).
///
/// La administración general reparte a la gente entre sedes: en cuáles está
/// cada persona y con qué rol en cada una, y a quién se le da la
/// administración general. Lo de dentro de cada sede —sus facultades, sus
/// grupos— lo sigue manteniendo la coordinación de esa sede.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_catalogos.dart';
import '../../infrastructure/firebase/repositorio_administracion.dart';
import '../../infrastructure/firebase/repositorio_catalogos.dart';
import '../shared/buscador.dart';
import '../shared/textos.dart';
import 'seccion_usuarios.dart';

/// Toda la gente, de todas las sedes: solo la administración general la ve.
final StreamProvider<List<UsuarioVista>> usuariosDeTodasLasSedesProvider =
    StreamProvider<List<UsuarioVista>>(
      (Ref ref) => ref.watch(repositorioAdminProvider).observarUsuarios(),
    );

const Map<String, String> _roles = <String, String>{
  'CATEDRATICO': 'Catedrático',
  'ADMINISTRADORA': 'Administradora',
  'AUDITOR': 'Auditor',
  'COORDINADOR': 'Coordinador',
};

class PersonasYSedes extends ConsumerStatefulWidget {
  const PersonasYSedes({required this.miUid, super.key});

  /// Quien está usando la aplicación: sus propias sedes las cambia otra
  /// persona de la administración general.
  final String miUid;

  @override
  ConsumerState<PersonasYSedes> createState() => _PersonasYSedesState();
}

class _PersonasYSedesState extends ConsumerState<PersonasYSedes> {
  final TextEditingController _busqueda = TextEditingController();

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final List<ElementoCatalogo> sedes =
        ref.watch(sedesProvider).value ?? const <ElementoCatalogo>[];
    final Map<String, String> nombres = <String, String>{
      for (final ElementoCatalogo s in sedes) s.id: s.nombre,
    };
    final AsyncValue<List<UsuarioVista>> personas = ref.watch(
      usuariosDeTodasLasSedesProvider,
    );
    final List<UsuarioVista> todas = personas.value ?? const <UsuarioVista>[];
    final List<UsuarioVista> vistas = todas
        .where(
          (UsuarioVista u) =>
              coincide(_busqueda.text, <String>[u.nombre, u.correo]),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(Textos.personasYSedes, style: tema.textTheme.titleMedium),
        ),
        const SizedBox(height: 4),
        Text(Textos.personasYSedesExplicacion, style: tema.textTheme.bodySmall),
        const SizedBox(height: 8),
        Buscador(
          controlador: _busqueda,
          etiqueta: Textos.buscarPersona,
          resultados: _busqueda.text.trim().isEmpty ? null : vistas.length,
        ),
        if (personas.isLoading && todas.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        for (final UsuarioVista u in vistas)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(u.nombre.isEmpty ? u.correo : u.nombre),
              subtitle: Text(
                <String>[
                  u.correo,
                  for (final MapEntry<String, String> e
                      in u.sedesConRol.entries)
                    '${nombres[e.key] ?? e.key} · ${_roles[e.value] ?? e.value}',
                  if (u.adminGeneral) Textos.administracionGeneral,
                ].join('\n'),
              ),
              isThreeLine: true,
              trailing: Tooltip(
                message: Textos.cambiarSedesDe(
                  u.nombre.isEmpty ? u.correo : u.nombre,
                ),
                child: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (BuildContext _) => DialogoSedes(
                      persona: u,
                      sedes: sedes,
                      esUnoMismo: u.uid == widget.miUid,
                    ),
                  ),
                  child: const Text(Textos.botonSedes),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// En qué sedes está una persona, con qué rol, y si tiene la administración
/// general. Se guarda todo junto: primero altas y cambios, después bajas.
class DialogoSedes extends ConsumerStatefulWidget {
  const DialogoSedes({
    required this.persona,
    required this.sedes,
    required this.esUnoMismo,
    super.key,
  });

  final UsuarioVista persona;
  final List<ElementoCatalogo> sedes;
  final bool esUnoMismo;

  @override
  ConsumerState<DialogoSedes> createState() => _DialogoSedesState();
}

class _DialogoSedesState extends ConsumerState<DialogoSedes> {
  late final Map<String, String> _deseado = <String, String>{
    ...widget.persona.sedesConRol,
  };
  late bool _adminGeneral = widget.persona.adminGeneral;
  bool _guardando = false;
  String? _error;

  bool get _coordinaEnAlguna => _deseado.values.contains('COORDINADOR');

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
      for (final CambioDeSede c in cambiosDeSedes(
        widget.persona.sedesConRol,
        _deseado,
      )) {
        switch (c) {
          case AsignarSede(:final String sedeId, :final String rol):
            await repo.asignarSede(uid: uid, sedeId: sedeId, rol: rol);
          case QuitarSede(:final String sedeId):
            await repo.quitarSede(uid: uid, sedeId: sedeId);
        }
      }
      if (_adminGeneral != widget.persona.adminGeneral) {
        await repo.cambiarAdminGeneral(uid: uid, valor: _adminGeneral);
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
    final bool bloqueado = widget.esUnoMismo || _guardando;
    return AlertDialog(
      title: Text(Textos.sedesDe(nombre)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (widget.esUnoMismo)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(Textos.sedesPropias),
                ),
              for (final ElementoCatalogo s in widget.sedes)
                if (s.activa || _deseado.containsKey(s.id))
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
                                    _deseado[s.id] = 'CATEDRATICO';
                                  } else {
                                    _deseado.remove(s.id);
                                  }
                                }),
                        ),
                      ),
                      if (_deseado.containsKey(s.id))
                        DropdownButton<String>(
                          value: _deseado[s.id],
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
                                  () => _deseado[s.id] = v ?? 'CATEDRATICO',
                                ),
                        ),
                    ],
                  ),
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(Textos.administracionGeneral),
                subtitle: const Text(Textos.administracionGeneralAyuda),
                value: _adminGeneral,
                onChanged: bloqueado || (!_adminGeneral && !_coordinaEnAlguna)
                    ? null
                    : (bool v) => setState(() => _adminGeneral = v),
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
        if (!widget.esUnoMismo)
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: Text(
              _guardando ? Textos.grupoGuardando : Textos.grupoGuardar,
            ),
          ),
      ],
    );
  }
}
