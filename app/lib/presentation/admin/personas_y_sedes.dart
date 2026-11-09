/// SIAN — Las sedes de una persona (2.0.1 · RF-SED-02, RF-SED-06).
///
/// La administración general decide en qué sedes está cada persona y con qué
/// rol en cada una. Desde la 2.0.4 se abre desde Usuarios, donde se maneja
/// todo lo de una persona: rol, facultades, sedes y administración general.
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
  late final Map<String, String> _deseado = <String, String>{
    ...widget.persona.sedesConRol,
  };
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
