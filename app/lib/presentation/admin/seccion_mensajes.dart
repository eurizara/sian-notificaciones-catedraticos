/// SIAN — Composición y envío inmediato (RF-MSG-01, 02, 06, 12, 13; RF-PRG-01).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Enviar es irreversible. La pantalla está construida alrededor de eso.
/// ────────────────────────────────────────────────────────────────────────────
///
/// RN-03 dice que un mensaje enviado no se edita ni se borra. Así que lo que
/// aquí importa no es escribir cómodo, sino **no equivocarse**: el conteo real
/// de destinatarios antes de confirmar (RF-USR-07), la segunda confirmación
/// para una alerta urgente (RF-MSG-13), y contadores de caracteres que avisan
/// antes de que el servidor rechace.
///
/// Nada de lo que se comprueba aquí se da por bueno en el servidor. La Function
/// vuelve a validar longitudes, autorización y doble confirmación: una
/// comprobación hecha solo en la interfaz es un defecto de seguridad.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_sesion.dart';
import '../../domain/sesion.dart';
import '../../infrastructure/firebase/repositorio_adjuntos.dart';
import '../../infrastructure/firebase/repositorio_envio.dart';
import 'adjuntos_mensaje.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';

final Provider<RepositorioEnvio> repositorioEnvioProvider =
    Provider<RepositorioEnvio>((Ref ref) => RepositorioEnvio());

final Provider<RepositorioAdjuntos> repositorioAdjuntosProvider =
    Provider<RepositorioAdjuntos>((Ref ref) => RepositorioAdjuntos());

final gruposProvider = StreamProvider<List<GrupoVista>>(
  (Ref ref) => ref.watch(repositorioEnvioProvider).observarGrupos(),
);

class SeccionMensajes extends ConsumerStatefulWidget {
  const SeccionMensajes({super.key});

  @override
  ConsumerState<SeccionMensajes> createState() => _SeccionMensajesState();
}

class _SeccionMensajesState extends ConsumerState<SeccionMensajes> {
  final GlobalKey<FormState> _formulario = GlobalKey<FormState>();
  final TextEditingController _titulo = TextEditingController();
  final TextEditingController _cuerpo = TextEditingController();

  bool _urgente = false;
  bool _requiereConfirmacion = false;
  bool _aTodos = true;
  final Set<String> _gruposElegidos = <String>{};
  AdjuntosEnCurso _adjuntos = const AdjuntosEnCurso();
  bool _enviando = false;
  bool _subiendo = false;

  @override
  void initState() {
    super.initState();
    // Los contadores tienen que moverse mientras se escribe, no al validar.
    _titulo.addListener(_repintar);
    _cuerpo.addListener(_repintar);
  }

  void _repintar() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _titulo.dispose();
    _cuerpo.dispose();
    super.dispose();
  }

  Destinatarios _destinatarios() => _aTodos
      ? const Destinatarios.todos()
      : Destinatarios.grupos(_gruposElegidos.toList());

  /// Flujo completo de envío: validar, contar, confirmar y despachar.
  Future<void> _intentarEnviar() async {
    if (!(_formulario.currentState?.validate() ?? false)) {
      return;
    }
    if (!_aTodos && _gruposElegidos.isEmpty) {
      _avisar(Textos.validacionElijeGrupo, error: true);
      return;
    }

    setState(() => _enviando = true);

    try {
      // Primero el conteo. Enseñar «esto va a 47 personas» antes de pulsar es
      // la única oportunidad de detectar que el grupo elegido no era el que se
      // creía: después ya no hay vuelta atrás.
      final ConteoDestinatarios conteo = await ref
          .read(repositorioEnvioProvider)
          .contar(_destinatarios());

      if (!mounted) {
        return;
      }

      if (conteo.total == 0) {
        _avisar(Textos.envioSinDestinatarios, error: true);
        return;
      }

      final bool confirmado = await _confirmar(conteo);
      if (!confirmado || !mounted) {
        return;
      }

      // Los adjuntos se suben ANTES de llamar al envío, contra un
      // identificador reservado: las reglas de Storage dependen de la ruta
      // `mensajes/{id}/…`, y el mensaje todavía no existe.
      String? mensajeId;
      AdjuntoSubido? voz;
      AdjuntoSubido? imagen;

      if (_adjuntos.hayAlgo) {
        setState(() => _subiendo = true);
        final RepositorioAdjuntos adj = ref.read(repositorioAdjuntosProvider);
        mensajeId = adj.reservarIdMensaje();

        if (_adjuntos.voz != null) {
          voz = await adj.subirVoz(
            mensajeId: mensajeId,
            bytes: _adjuntos.voz!.bytes,
            tipoMime: _adjuntos.voz!.tipoMime,
            duracionSeg: _adjuntos.voz!.duracionSeg,
          );
        }
        if (_adjuntos.imagen != null) {
          imagen = await adj.subirImagen(
            mensajeId: mensajeId,
            bytes: _adjuntos.imagen!.bytes,
            tipoMime: _adjuntos.imagen!.tipoMime,
            nombreOriginal: _adjuntos.imagen!.nombre,
          );
        }
        if (mounted) {
          setState(() => _subiendo = false);
        }
      }

      final ResultadoEnvio r = await ref
          .read(repositorioEnvioProvider)
          .enviarInmediato(
            titulo: _titulo.text,
            cuerpo: _cuerpo.text,
            urgente: _urgente,
            requiereConfirmacion: _requiereConfirmacion,
            destinatarios: _destinatarios(),
            // Solo llega en true si la persona pasó por el segundo diálogo.
            confirmacionUrgente: _urgente,
            mensajeId: mensajeId,
            voz: voz,
            imagen: imagen,
          );

      if (!mounted) {
        return;
      }

      _avisar(
        r.huboFallos
            ? Textos.envioConFallos(r.entregados, r.total, r.fallidos)
            : Textos.envioCorrecto(r.entregados, r.total),
        error: r.huboFallos,
      );

      if (!r.huboFallos) {
        _limpiar();
      }
    } on FirebaseFunctionsException catch (e) {
      // El mensaje del servidor es el bueno: explica en lenguaje llano por qué
      // no se envió, y lo escribió el dominio.
      if (mounted) {
        _avisar(e.message ?? Textos.envioFallido, error: true);
      }
    } on Object catch (_) {
      if (mounted) {
        _avisar(Textos.envioFallido, error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _enviando = false;
          _subiendo = false;
        });
      }
    }
  }

  void _limpiar() {
    _titulo.clear();
    _cuerpo.clear();
    setState(() {
      _urgente = false;
      _requiereConfirmacion = false;
      _adjuntos = const AdjuntosEnCurso();
    });
  }

  void _avisar(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? ColoresSian.urgente : ColoresSian.confirmado,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  /// Confirmación previa, con el conteo real delante.
  ///
  /// Para una alerta urgente son **dos** pasos distintos (RF-MSG-13): el botón
  /// de enviar no cuenta como confirmación. Un pulsar de más en el sitio
  /// equivocado no puede hacer sonar el teléfono de doscientas personas.
  Future<bool> _confirmar(ConteoDestinatarios conteo) async {
    final bool primera = await _dialogo(
      titulo: Textos.confirmarEnvioTitulo,
      contenido: _ResumenConteo(conteo: conteo, urgente: _urgente),
      botonConfirmar: Textos.botonConfirmarEnvio,
      peligroso: false,
    );

    if (!primera || !_urgente || !mounted) {
      return primera;
    }

    return _dialogo(
      titulo: Textos.confirmarUrgenteTitulo,
      contenido: const Text(Textos.urgenteAdvertencia),
      botonConfirmar: Textos.botonConfirmarUrgente,
      peligroso: true,
    );
  }

  Future<bool> _dialogo({
    required String titulo,
    required Widget contenido,
    required String botonConfirmar,
    required bool peligroso,
  }) async {
    final bool? r = await showDialog<bool>(
      context: context,
      builder: (BuildContext contexto) => AlertDialog(
        title: Text(
          titulo,
          style: peligroso ? const TextStyle(color: ColoresSian.urgente) : null,
        ),
        content: contenido,
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text(Textos.botonCancelar),
          ),
          FilledButton(
            style: peligroso
                ? FilledButton.styleFrom(backgroundColor: ColoresSian.urgente)
                : null,
            onPressed: () => Navigator.of(contexto).pop(true),
            child: Text(botonConfirmar),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final Sesion sesion = ref.watch(sesionActualProvider);
    // Se consulta la MATRIZ, no la bandera suelta: el coordinador puede
    // siempre, y la bandera existe para que él decida qué administradoras
    // pueden (documento 01, sección 2.2).
    final bool puedeUrgentes =
        sesion is SesionActiva &&
        sesion.usuario.rol.puedeEmitirUrgentes(
          autorizacionFina: sesion.usuario.puedeEmitirUrgentes,
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _formulario,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  Textos.redactarTitulo,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: ColoresSian.primarioOscuro,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _titulo,
                  // Se corta en el límite en vez de dejar escribir y rechazar
                  // después: descubrir a los 90 caracteres que sobran 10 es
                  // perder trabajo ya hecho.
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(Textos.limiteTitulo),
                  ],
                  decoration: InputDecoration(
                    labelText: Textos.etiquetaTituloMensaje,
                    border: const OutlineInputBorder(),
                    counterText: Textos.contador(
                      _titulo.text.characters.length,
                      Textos.limiteTitulo,
                    ),
                  ),
                  validator: (String? v) => (v ?? '').trim().isEmpty
                      ? Textos.validacionTituloObligatorio
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _cuerpo,
                  minLines: 4,
                  maxLines: 8,
                  inputFormatters: <TextInputFormatter>[
                    LengthLimitingTextInputFormatter(Textos.limiteCuerpo),
                  ],
                  decoration: InputDecoration(
                    labelText: Textos.etiquetaCuerpoMensaje,
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                    counterText: Textos.contador(
                      _cuerpo.text.characters.length,
                      Textos.limiteCuerpo,
                    ),
                  ),
                  validator: (String? v) => (v ?? '').trim().isEmpty
                      ? Textos.validacionCuerpoObligatorio
                      : null,
                ),
                const SizedBox(height: 24),

                PanelAdjuntos(
                  adjuntos: _adjuntos,
                  alCambiar: (AdjuntosEnCurso a) =>
                      setState(() => _adjuntos = a),
                ),
                const SizedBox(height: 24),

                _Clasificacion(
                  urgente: _urgente,
                  puedeUrgentes: puedeUrgentes,
                  alCambiar: (bool v) => setState(() => _urgente = v),
                ),
                const SizedBox(height: 24),

                _Destinatarios(
                  aTodos: _aTodos,
                  elegidos: _gruposElegidos,
                  alCambiarModo: (bool todos) =>
                      setState(() => _aTodos = todos),
                  alAlternarGrupo: (String id) => setState(() {
                    if (!_gruposElegidos.remove(id)) {
                      _gruposElegidos.add(id);
                    }
                  }),
                ),
                const SizedBox(height: 16),

                SwitchListTile(
                  value: _requiereConfirmacion,
                  onChanged: (bool v) =>
                      setState(() => _requiereConfirmacion = v),
                  title: const Text(Textos.exigirConfirmacion),
                  subtitle: const Text(Textos.exigirConfirmacionDetalle),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),

                FilledButton.icon(
                  onPressed: _enviando ? null : _intentarEnviar,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(88, 52),
                    backgroundColor: _urgente ? ColoresSian.urgente : null,
                  ),
                  icon: _enviando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(switch ((_enviando, _subiendo)) {
                    (_, true) => Textos.subiendoAdjuntos,
                    (true, _) => Textos.contandoDestinatarios,
                    _ => Textos.botonEnviarAhora,
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Informativo o urgente (RF-MSG-02), con la autorización fina aplicada.
class _Clasificacion extends StatelessWidget {
  const _Clasificacion({
    required this.urgente,
    required this.puedeUrgentes,
    required this.alCambiar,
  });

  final bool urgente;
  final bool puedeUrgentes;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(Textos.etiquetaTipo, style: tema.textTheme.titleSmall),
        const SizedBox(height: 8),
        RadioGroup<bool>(
          groupValue: urgente,
          onChanged: (bool? v) => alCambiar(v ?? false),
          child: Column(
            children: <Widget>[
              const RadioListTile<bool>(
                value: false,
                title: Text(Textos.tipoInformativo),
                subtitle: Text(Textos.tipoInformativoDetalle),
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<bool>(
                value: true,
                // La interfaz respeta la autorización fina, y el servidor la vuelve
                // a exigir: deshabilitar el control no es una medida de seguridad.
                enabled: puedeUrgentes,
                title: Text(
                  Textos.tipoUrgente,
                  style: TextStyle(
                    color: puedeUrgentes ? ColoresSian.urgente : null,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  puedeUrgentes
                      ? Textos.tipoUrgenteDetalle
                      : Textos.noPuedeUrgentes,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A quién va (RF-USR-07).
class _Destinatarios extends ConsumerWidget {
  const _Destinatarios({
    required this.aTodos,
    required this.elegidos,
    required this.alCambiarModo,
    required this.alAlternarGrupo,
  });

  final bool aTodos;
  final Set<String> elegidos;
  final ValueChanged<bool> alCambiarModo;
  final ValueChanged<String> alAlternarGrupo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData tema = Theme.of(context);
    final AsyncValue<List<GrupoVista>> grupos = ref.watch(gruposProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(Textos.etiquetaDestinatarios, style: tema.textTheme.titleSmall),
        const SizedBox(height: 8),
        RadioGroup<bool>(
          groupValue: aTodos,
          onChanged: (bool? v) => alCambiarModo(v ?? true),
          child: const Column(
            children: <Widget>[
              RadioListTile<bool>(
                value: true,
                title: Text(Textos.destinatariosTodos),
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<bool>(
                value: false,
                title: Text(Textos.destinatariosGrupos),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        if (!aTodos)
          grupos.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
            error: (Object e, StackTrace _) => Text('$e'),
            data: (List<GrupoVista> lista) => lista.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(left: 16, top: 8),
                    child: Text(Textos.sinGruposTodavia),
                  )
                : Wrap(
                    spacing: 8,
                    children: <Widget>[
                      for (final GrupoVista g in lista)
                        FilterChip(
                          label: Text('${g.nombre} (${g.totalMiembros})'),
                          selected: elegidos.contains(g.id),
                          onSelected: (_) => alAlternarGrupo(g.id),
                        ),
                    ],
                  ),
          ),
      ],
    );
  }
}

/// Lo que se ve antes de confirmar: el número real y quién queda fuera.
class _ResumenConteo extends StatelessWidget {
  const _ResumenConteo({required this.conteo, required this.urgente});

  final ConteoDestinatarios conteo;
  final bool urgente;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          Textos.conteoDestinatarios(conteo.total),
          style: tema.textTheme.titleMedium?.copyWith(
            color: urgente ? ColoresSian.urgente : ColoresSian.primarioOscuro,
          ),
        ),
        // Quién queda fuera y por qué. «43 de 45» sin decir el motivo deja al
        // emisor sin saber si eso está bien o es un problema.
        if (conteo.excluidos > 0) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            Textos.conteoExcluidos(conteo.excluidos),
            style: tema.textTheme.bodyMedium,
          ),
          for (final MapEntry<String, int> m in conteo.motivos.entries)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(
                '· ${Textos.motivoExclusion(m.key, m.value)}',
                style: tema.textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}
