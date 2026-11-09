/// SIAN — Pantalla común de mantenimiento de un catálogo (2.0 · RF-CAT-01).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Todos los catálogos se mantienen igual.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Sedes, facultades y los que vengan (tipos de entrada y salida de la caja
/// chica, en la 2.1) usan este mismo componente: buscador, lista con el estado
/// escrito —no solo un color—, agregar, cambiar el nombre y desactivar o
/// reactivar con confirmación. Lo que se aprende en uno sirve en todos
/// (heurística de consistencia), y lo que se corrige en uno se corrige en todos.
///
/// No hay «borrar»: lo que se usó una vez queda en lo registrado, así que se
/// desactiva (RF-CAT-02).
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../infrastructure/firebase/repositorio_catalogos.dart';
import 'buscador.dart';
import 'tema.dart';
import 'textos.dart';

class MantenimientoCatalogo extends StatefulWidget {
  const MantenimientoCatalogo({
    required this.fuente,
    required this.titulo,
    required this.elemento,
    this.explicacion,
    this.mostrarTitulo = true,
    super.key,
  });

  /// Sin título cuando va dentro de un bloque desplegable, que ya lo lleva.
  final bool mostrarTitulo;

  final FuenteCatalogo fuente;

  /// «Facultades de Boca del Monte», «Sedes».
  final String titulo;

  /// El nombre de un elemento, en singular y minúscula: «facultad», «sede».
  final String elemento;

  /// Una línea que dice para qué sirve el catálogo.
  final String? explicacion;

  @override
  State<MantenimientoCatalogo> createState() => _MantenimientoCatalogoState();
}

class _MantenimientoCatalogoState extends State<MantenimientoCatalogo> {
  final TextEditingController _busqueda = TextEditingController();
  late Stream<List<ElementoCatalogo>> _elementos = widget.fuente.observar();

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant MantenimientoCatalogo anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.fuente != widget.fuente) {
      _elementos = widget.fuente.observar();
    }
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    return StreamBuilder<List<ElementoCatalogo>>(
      stream: _elementos,
      builder: (BuildContext context, AsyncSnapshot<List<ElementoCatalogo>> s) {
        final List<ElementoCatalogo> todos =
            s.data ?? const <ElementoCatalogo>[];
        final String termino = _busqueda.text;
        final List<ElementoCatalogo> vistos = todos
            .where(
              (ElementoCatalogo e) => coincide(termino, <String>[e.nombre]),
            )
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: widget.mostrarTitulo
                      ? Semantics(
                          header: true,
                          child: Text(
                            widget.titulo,
                            style: tema.textTheme.titleMedium,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _editar(context),
                  icon: const Icon(Icons.add),
                  label: Text(Textos.catalogoAgregar(widget.elemento)),
                ),
              ],
            ),
            if (widget.explicacion != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(widget.explicacion!, style: tema.textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            if (todos.length > 5)
              Buscador(
                controlador: _busqueda,
                etiqueta: Textos.catalogoBuscar(widget.elemento),
                resultados: termino.trim().isEmpty ? null : vistos.length,
              ),
            if (s.hasError)
              Text(
                Textos.catalogoNoSePudoLeer,
                style: TextStyle(color: tema.colorScheme.error),
              )
            else if (!s.hasData)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (todos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(Textos.catalogoVacio(widget.elemento)),
              )
            else
              for (final ElementoCatalogo e in vistos)
                _Fila(
                  elemento: e,
                  alEditar: () => _editar(context, e),
                  alCambiarEstado: () => _cambiarEstado(context, e),
                ),
          ],
        );
      },
    );
  }

  Future<void> _editar(BuildContext context, [ElementoCatalogo? e]) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext _) => _DialogoNombre(
        fuente: widget.fuente,
        elemento: widget.elemento,
        existente: e,
      ),
    );
  }

  Future<void> _cambiarEstado(BuildContext context, ElementoCatalogo e) async {
    final bool desactivar = e.activa;
    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogo) => AlertDialog(
        title: Text(
          desactivar
              ? Textos.catalogoDesactivarTitulo(e.nombre)
              : Textos.catalogoReactivarTitulo(e.nombre),
        ),
        content: Text(
          desactivar
              ? Textos.catalogoDesactivarExplicacion(widget.elemento)
              : Textos.catalogoReactivarExplicacion(widget.elemento),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text(Textos.botonCancelar),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: Text(
              desactivar ? Textos.grupoDesactivar : Textos.grupoReactivar,
            ),
          ),
        ],
      ),
    );
    if (confirmado != true || !context.mounted) {
      return;
    }
    final ScaffoldMessengerState avisos = ScaffoldMessenger.of(context);
    try {
      await widget.fuente.guardar(
        id: e.id,
        nombre: e.nombre,
        activa: !desactivar,
      );
    } on FirebaseFunctionsException catch (error) {
      avisos.showSnackBar(
        SnackBar(content: Text(error.message ?? Textos.catalogoNoSeGuardo)),
      );
    }
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.elemento,
    required this.alEditar,
    required this.alCambiarEstado,
  });

  final ElementoCatalogo elemento;
  final VoidCallback alEditar;
  final VoidCallback alCambiarEstado;

  @override
  Widget build(BuildContext context) {
    final PaletaSian paleta = PaletaSian.de(context);
    final ColorScheme colores = Theme.of(context).colorScheme;
    // El estado va escrito y con su icono: nunca solo con el color (WCAG 1.4.1).
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          elemento.activa
              ? Icons.check_circle_outline
              : Icons.pause_circle_outline,
          color: elemento.activa ? paleta.confirmado : colores.onSurfaceVariant,
          semanticLabel: elemento.activa
              ? Textos.catalogoActiva
              : Textos.catalogoInactiva,
        ),
        title: Text(elemento.nombre),
        subtitle: Text(
          elemento.activa ? Textos.catalogoActiva : Textos.catalogoInactiva,
        ),
        trailing: Wrap(
          spacing: 4,
          children: <Widget>[
            IconButton(
              tooltip: Textos.catalogoCambiarNombre(elemento.nombre),
              icon: const Icon(Icons.edit_outlined),
              onPressed: alEditar,
            ),
            TextButton(
              onPressed: alCambiarEstado,
              child: Text(
                elemento.activa
                    ? Textos.grupoDesactivar
                    : Textos.grupoReactivar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El nombre, al dar de alta o al cambiarlo. Con su propio estado: el
/// controlador del texto vive lo que vive el diálogo, ni más ni menos.
class _DialogoNombre extends StatefulWidget {
  const _DialogoNombre({
    required this.fuente,
    required this.elemento,
    this.existente,
  });

  final FuenteCatalogo fuente;
  final String elemento;
  final ElementoCatalogo? existente;

  @override
  State<_DialogoNombre> createState() => _DialogoNombreState();
}

class _DialogoNombreState extends State<_DialogoNombre> {
  late final TextEditingController _nombre = TextEditingController(
    text: widget.existente?.nombre ?? '',
  );
  String? _error;
  bool _guardando = false;

  static const int _maximo = 80;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final String nombre = _nombre.text.trim();
    if (nombre.length < 2) {
      setState(() => _error = Textos.catalogoNombreCorto);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.fuente.guardar(id: widget.existente?.id, nombre: nombre);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FirebaseFunctionsException catch (e) {
      // El servidor dice qué corregir: «Ya existe “Derecho” en este catálogo».
      setState(() {
        _guardando = false;
        _error = e.message ?? Textos.catalogoNoSeGuardo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool nuevo = widget.existente == null;
    return AlertDialog(
      title: Text(
        nuevo
            ? Textos.catalogoAgregar(widget.elemento)
            : Textos.catalogoCambiarNombre(widget.existente!.nombre),
      ),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _nombre,
          autofocus: true,
          maxLength: _maximo,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _guardando ? null : _guardar(),
          decoration: InputDecoration(
            labelText: Textos.catalogoNombre,
            helperText: nuevo ? Textos.catalogoNombreAyuda : null,
            errorText: _error,
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
