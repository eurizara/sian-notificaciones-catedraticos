/// SIAN — Grupos de destinatarios (RF-USR-03, RF-USR-04, DT-08).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Un grupo decide a quién le llega una alerta de emergencia.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Por eso la pantalla enseña el **número de miembros en todo momento** y no lo
/// esconde tras un clic: equivocarse de grupo al redactar es enviar un aviso a
/// veinte personas creyendo que van cuarenta y cinco, y eso no se descubre
/// hasta que alguien pregunta por qué no le avisaron.
///
/// Desactivar no es borrar. Un grupo borrado dejaría los mensajes históricos
/// apuntando a algo inexistente, y el reporte de un simulacro pasado tiene que
/// poder decir a qué grupo se envió.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_grupos.dart';
import '../../infrastructure/firebase/repositorio_grupos.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';
import '../../application/proveedores_catalogos.dart';
import '../../infrastructure/firebase/repositorio_catalogos.dart';

class SeccionGrupos extends ConsumerStatefulWidget {
  const SeccionGrupos({super.key});

  @override
  ConsumerState<SeccionGrupos> createState() => _SeccionGruposState();
}

class _SeccionGruposState extends ConsumerState<SeccionGrupos> {
  /// La facultad por la que se filtra la lista (2.0, RF-FAC-03). Nulo: todas.
  String? _facultad;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<GrupoDetalle>> grupos = ref.watch(gruposProvider);
    final bool porFacultad = ref.watch(hayFacultadesParaElegirProvider);
    final List<ElementoCatalogo> facultades =
        ref.watch(facultadesActivasProvider).value ??
        const <ElementoCatalogo>[];

    return Scaffold(
      body: grupos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => _Error(detalle: '$e'),
        data: (List<GrupoDetalle> lista) => lista.isEmpty
            ? const _SinGrupos()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  // RF-FAC-04: con menos de dos facultades no hay filtro.
                  if (porFacultad)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 8,
                        children: <Widget>[
                          ChoiceChip(
                            label: const Text(Textos.filtroTodasLasFacultades),
                            selected: _facultad == null,
                            onSelected: (_) => setState(() => _facultad = null),
                          ),
                          for (final ElementoCatalogo f in facultades)
                            ChoiceChip(
                              label: Text(f.nombre),
                              selected: _facultad == f.id,
                              onSelected: (_) =>
                                  setState(() => _facultad = f.id),
                            ),
                        ],
                      ),
                    ),
                  for (final GrupoDetalle g in lista)
                    if (!porFacultad ||
                        _facultad == null ||
                        g.facultadId == _facultad)
                      _FilaGrupo(grupo: g),
                  const SizedBox(height: 80),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrirEditorGrupo(context),
        icon: const Icon(Icons.group_add),
        label: const Text(Textos.grupoNuevo),
      ),
    );
  }
}

/// Abre el editor. Expuesta para poder probarla sin pasar por el botón.
Future<void> abrirEditorGrupo(BuildContext context, {GrupoDetalle? grupo}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext _) => EditorGrupo(grupo: grupo),
  );
}

class _FilaGrupo extends ConsumerWidget {
  const _FilaGrupo({required this.grupo});

  final GrupoDetalle grupo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData tema = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: grupo.activo
              ? PaletaSian.de(context).fondoPrimario
              : tema.colorScheme.outline,
          foregroundColor: PaletaSian.sobreFondo,
          // El número va en el sitio más visible de la fila: es el dato que
          // evita enviar a veinte creyendo que van cuarenta y cinco.
          child: Text('${grupo.totalMiembros}'),
        ),
        title: Text(
          grupo.nombre,
          style: TextStyle(
            decoration: grupo.activo ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (grupo.descripcion.isNotEmpty) Text(grupo.descripcion),
            Text(
              grupo.activo
                  ? Textos.grupoMiembros(grupo.totalMiembros)
                  : Textos.grupoInactivo(grupo.totalMiembros),
            ),
            // Aviso temprano de DT-08: saberlo con 50 de margen es mejor que
            // descubrirlo el día que hace falta agregar a alguien.
            if (grupo.rozaElLimite)
              Text(
                Textos.grupoRozaElLimite(LimitesGrupo.maxMiembros),
                style: tema.textTheme.bodySmall?.copyWith(
                  color: PaletaSian.de(context).doradoTexto,
                ),
              ),
          ],
        ),
        isThreeLine: grupo.descripcion.isNotEmpty || grupo.rozaElLimite,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              onPressed: () => abrirEditorGrupo(context, grupo: grupo),
              icon: const Icon(Icons.edit_outlined),
              tooltip: Textos.grupoEditar,
            ),
            IconButton(
              onPressed: () => _alternarEstado(context, ref),
              icon: Icon(
                grupo.activo ? Icons.block : Icons.restore,
                color: grupo.activo ? PaletaSian.de(context).urgente : null,
              ),
              tooltip: grupo.activo
                  ? Textos.grupoDesactivar
                  : Textos.grupoReactivar,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _alternarEstado(BuildContext context, WidgetRef ref) async {
    final bool activar = !grupo.activo;

    if (!activar) {
      final bool? seguro = await showDialog<bool>(
        context: context,
        builder: (BuildContext c) => AlertDialog(
          title: const Text(Textos.grupoDesactivarTitulo),
          content: Text(Textos.grupoDesactivarAviso(grupo.nombre)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text(Textos.botonCancelar),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: PaletaSian.de(context).fondoUrgente,
                foregroundColor: PaletaSian.sobreFondo,
              ),
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text(Textos.grupoDesactivar),
            ),
          ],
        ),
      );
      if (seguro != true) {
        return;
      }
    }

    if (!context.mounted) {
      return;
    }

    try {
      await ref
          .read(repositorioGruposProvider)
          .cambiarEstado(grupoId: grupo.id, activo: activar);
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? Textos.grupoErrorGuardar)),
        );
      }
    }
  }
}

/// Alta y edición, con la lista de personas para marcar.
class EditorGrupo extends ConsumerStatefulWidget {
  const EditorGrupo({this.grupo, super.key});

  final GrupoDetalle? grupo;

  @override
  ConsumerState<EditorGrupo> createState() => _EditorGrupoState();
}

class _EditorGrupoState extends ConsumerState<EditorGrupo> {
  late final TextEditingController _nombre = TextEditingController(
    text: widget.grupo?.nombre ?? '',
  );
  late final TextEditingController _descripcion = TextEditingController(
    text: widget.grupo?.descripcion ?? '',
  );
  late final Set<String> _elegidos = <String>{...?widget.grupo?.miembros};

  /// La facultad del grupo (2.0, RF-FAC-03). Solo se pregunta con dos o más.
  late String? _facultad = widget.grupo?.facultadId;

  final TextEditingController _busqueda = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(() => setState(() {}));
    _nombre.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty) {
      setState(() => _error = Textos.grupoValidacionNombre);
      return;
    }
    if (_elegidos.isEmpty) {
      // Un grupo vacío no es un error de sintaxis, es una trampa: al redactar
      // mostraría «llegará a 0 personas» y el envío se rechazaría.
      setState(() => _error = Textos.grupoValidacionSinMiembros);
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await ref
          .read(repositorioGruposProvider)
          .guardar(
            grupoId: widget.grupo?.id,
            nombre: _nombre.text,
            descripcion: _descripcion.text,
            miembros: _elegidos.toList(),
            facultadId: _facultad,
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _error = e.message ?? Textos.grupoErrorGuardar);
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() => _error = Textos.grupoErrorGuardar);
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  /// Solo se pueden agrupar quienes reciben avisos y están activos.
  ///
  /// Meter en un grupo a una cuenta desactivada, o a la coordinación, no daría
  /// error: el servidor los excluye al enviar. Pero entonces el conteo no
  /// cuadraría con lo que la lista prometía, y habría que descubrirlo leyendo
  /// los motivos de exclusión. Mejor no ofrecerlos.
  List<Elegible> _elegibles(List<Elegible> todos) {
    final String q = _busqueda.text.trim().toLowerCase();
    final List<Elegible> caben = _quienesCaben(todos);
    if (q.isEmpty) {
      return caben;
    }
    return caben
        .where(
          (Elegible u) =>
              u.nombre.toLowerCase().contains(q) ||
              u.correo.toLowerCase().contains(q),
        )
        .toList();
  }

  /// La gente de la sede que cabe en el grupo (2.0.7): si el grupo es de una
  /// facultad, solo quien la tiene en esta sede.
  List<Elegible> _quienesCaben(List<Elegible> todos) => _facultad == null
      ? todos
      : todos.where((Elegible u) => u.facultades.contains(_facultad)).toList();

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final AsyncValue<List<Elegible>> usuarios = ref.watch(elegiblesProvider);
    // Miembros que ya no caben: dejaron la sede, perdieron la facultad, o se
    // cambió la facultad del grupo. Se dice y se ofrece quitarlos de un toque;
    // el servidor no deja guardar con ellos (2.0.7).
    final Set<String> caben = <String>{
      for (final Elegible u in _quienesCaben(
        usuarios.value ?? const <Elegible>[],
      ))
        u.uid,
    };
    final List<String> fuera = usuarios.hasValue
        ? _elegidos.where((String uid) => !caben.contains(uid)).toList()
        : const <String>[];

    return AlertDialog(
      title: Text(
        widget.grupo == null ? Textos.grupoNuevo : Textos.grupoEditar,
      ),
      // Alto acotado a la pantalla y lista flexible dentro: en un portátil
      // pequeño o con el teclado abierto, un diálogo de alto fijo se sale por
      // abajo y deja el botón de guardar fuera de alcance.
      content: SizedBox(
        width: 520,
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _nombre,
              inputFormatters: <TextInputFormatter>[
                LengthLimitingTextInputFormatter(LimitesGrupo.maxNombre),
              ],
              decoration: InputDecoration(
                labelText: Textos.grupoNombre,
                border: const OutlineInputBorder(),
                counterText: Textos.contador(
                  _nombre.text.characters.length,
                  LimitesGrupo.maxNombre,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descripcion,
              decoration: const InputDecoration(
                labelText: Textos.grupoDescripcion,
                border: OutlineInputBorder(),
              ),
            ),
            // RF-FAC-04: con menos de dos facultades no se pregunta.
            if (ref.watch(hayFacultadesParaElegirProvider)) ...<Widget>[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _facultad,
                decoration: const InputDecoration(
                  labelText: Textos.grupoFacultad,
                  border: OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                    child: Text(Textos.grupoSinFacultad),
                  ),
                  for (final ElementoCatalogo f
                      in ref.watch(facultadesActivasProvider).value ??
                          const <ElementoCatalogo>[])
                    DropdownMenuItem<String?>(
                      value: f.id,
                      child: Text(f.nombre),
                    ),
                ],
                onChanged: (String? v) => setState(() => _facultad = v),
              ),
              if (_facultad != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    Textos.grupoSoloDeLaFacultad,
                    style: tema.textTheme.bodySmall,
                  ),
                ),
            ],
            const SizedBox(height: 16),

            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    Textos.grupoElegidos(_elegidos.length),
                    style: tema.textTheme.titleSmall,
                  ),
                ),
                if (_elegidos.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(_elegidos.clear),
                    child: const Text(Textos.grupoQuitarTodos),
                  ),
              ],
            ),
            if (fuera.isNotEmpty) ...<Widget>[
              Semantics(
                liveRegion: true,
                child: Card(
                  color: tema.colorScheme.errorContainer,
                  child: ListTile(
                    leading: Icon(
                      Icons.warning_amber_outlined,
                      color: tema.colorScheme.onErrorContainer,
                    ),
                    title: Text(
                      Textos.grupoMiembrosFuera(
                        fuera.length,
                        conFacultad: _facultad != null,
                      ),
                      style: TextStyle(
                        color: tema.colorScheme.onErrorContainer,
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () =>
                          setState(() => _elegidos.removeAll(fuera)),
                      child: const Text(Textos.grupoQuitarlos),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),

            TextField(
              controller: _busqueda,
              decoration: const InputDecoration(
                labelText: Textos.grupoBuscar,
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: usuarios.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, StackTrace _) => Text('$e'),
                data: (List<Elegible> todos) {
                  final List<Elegible> lista = _elegibles(todos);
                  if (lista.isEmpty) {
                    return const Center(child: Text(Textos.grupoSinElegibles));
                  }
                  return ListView.builder(
                    itemCount: lista.length,
                    itemBuilder: (BuildContext _, int i) {
                      final Elegible u = lista[i];
                      return CheckboxListTile(
                        dense: true,
                        value: _elegidos.contains(u.uid),
                        onChanged: (bool? v) => setState(() {
                          if (v == true) {
                            _elegidos.add(u.uid);
                          } else {
                            _elegidos.remove(u.uid);
                          }
                        }),
                        title: Text(u.nombre),
                        subtitle: Text(u.correo),
                      );
                    },
                  );
                },
              ),
            ),

            if (_elegidos.length >= LimitesGrupo.umbralAviso) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                Textos.grupoRozaElLimite(LimitesGrupo.maxMiembros),
                style: tema.textTheme.bodySmall?.copyWith(
                  color: PaletaSian.de(context).doradoTexto,
                ),
              ),
            ],

            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: PaletaSian.de(context).urgente,
                ),
              ),
            ],
          ],
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

class _SinGrupos extends StatelessWidget {
  const _SinGrupos();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.groups_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            const Text(Textos.grupoNinguno, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.detalle});

  final String detalle;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 48, color: tema.colorScheme.error),
            const SizedBox(height: 12),
            Text(detalle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
