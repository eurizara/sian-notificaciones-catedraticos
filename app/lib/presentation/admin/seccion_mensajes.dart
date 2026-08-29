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

import '../../application/proveedores_grupos.dart';
import '../../application/proveedores_programacion.dart';
import '../../application/proveedores_sesion.dart';
import '../../core/audio/grabacion.dart';
import '../../core/audio/grabadora.dart';
import '../../core/plataforma/selector_archivo.dart';
import '../../domain/sesion.dart';
import '../../infrastructure/firebase/repositorio_adjuntos.dart';
import '../../infrastructure/firebase/repositorio_grupos.dart';
import '../../infrastructure/firebase/repositorio_envio.dart';
import 'adjuntos_mensaje.dart';
import 'programador.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';

final Provider<RepositorioEnvio> repositorioEnvioProvider =
    Provider<RepositorioEnvio>((Ref ref) => RepositorioEnvio());

final Provider<RepositorioAdjuntos> repositorioAdjuntosProvider =
    Provider<RepositorioAdjuntos>((Ref ref) => RepositorioAdjuntos());

/// Las de verdad, con otro nombre porque los campos que las reciben ya ocupan
/// el suyo.
const Grabadora Function() crearGrabadoraReal = crearGrabadora;
const Future<ArchivoElegido?> Function() elegirImagenReal = elegirImagen;

class SeccionMensajes extends ConsumerStatefulWidget {
  const SeccionMensajes({
    this.crearGrabadora = crearGrabadoraReal,
    this.elegirImagen = elegirImagenReal,
    super.key,
  });

  /// Cómo se graba y cómo se elige la imagen.
  ///
  /// ──────────────────────────────────────────────────────────────────────────
  /// Se inyectan aquí, y no solo en el panel, para poder probar el envío
  /// CON adjuntos de punta a punta.
  /// ──────────────────────────────────────────────────────────────────────────
  ///
  /// Antes el panel recibía las suyas por omisión y no había forma de llegar a
  /// ellas desde fuera: una prueba podía adjuntar cosas al panel aislado, o
  /// pulsar enviar sin adjuntos, pero nunca las dos a la vez. Justo en ese
  /// hueco vivía el defecto de que una imagen adjuntada junto a una nota de
  /// voz no llegaba a subirse.
  final Grabadora Function() crearGrabadora;
  final Future<ArchivoElegido?> Function() elegirImagen;

  @override
  ConsumerState<SeccionMensajes> createState() => _SeccionMensajesState();
}

/// Con qué cara sale el aviso flotante del envío.
///
/// Nace de DT-24: antes solo había «normal» y «error», y un envío con fallos
/// parciales caía en «error». Rojo, en esta aplicación, es lo urgente y lo que
/// salió mal — así que el color decía «no se envió» mientras el texto decía
/// «enviado a 19 de 20». Ganaba el color.
enum TonoAviso {
  /// Salió como se esperaba.
  correcto,

  /// Salió, pero hay algo que mirar. Ni celebración ni alarma.
  atencion,

  /// No salió.
  error,
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
  EleccionEnvio _cuando = const EleccionEnvio(modo: ModoEnvio.ahora);
  bool _enviando = false;
  bool _subiendo = false;

  /// Identificador del mensaje que se está redactando, reservado antes de
  /// enviarlo y soltado al vaciar el formulario.
  ///
  /// Es la mitad cliente de la protección contra el envío duplicado (DT-24):
  /// mientras no cambie, el `create` del servidor rechaza un segundo envío del
  /// mismo formulario.
  String? _idReservado;

  /// Hay un adjunto a medias: grabando, o leyendo la imagen recién elegida.
  ///
  /// ──────────────────────────────────────────────────────────────────────────
  /// Con esto en marcha, enviar está prohibido.
  /// ──────────────────────────────────────────────────────────────────────────
  ///
  /// Lo que está a medias todavía no forma parte del mensaje. Enviar en ese
  /// momento produce lo peor que puede pasar aquí: un aviso que sale **sin la
  /// nota de voz que se estaba grabando**, sin error y sin aviso. Quien lo
  /// mandó cree que mandó audio; quien lo recibe ve texto suelto. Y RN-03 dice
  /// que un mensaje enviado no se edita.
  bool _adjuntoAMedias = false;

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
    // Antes que nada, y aunque el botón ya esté deshabilitado: un envío que
    // sale mientras se graba pierde la nota de voz para siempre.
    if (_adjuntoAMedias) {
      _avisar(Textos.adjuntoAMedias, tono: TonoAviso.error);
      return;
    }
    if (!(_formulario.currentState?.validate() ?? false)) {
      return;
    }
    if (!_aTodos && _gruposElegidos.isEmpty) {
      _avisar(Textos.validacionElijeGrupo, tono: TonoAviso.error);
      return;
    }

    // Programar exige fecha; repetir exige haber mirado las próximas. Sin lo
    // segundo, RF-PRG-09 sería un botón decorativo.
    if (_cuando.modo == ModoEnvio.programado && _cuando.fecha == null) {
      _avisar(Textos.validacionFechaObligatoria, tono: TonoAviso.error);
      return;
    }
    if (_cuando.modo == ModoEnvio.recurrente) {
      if (_cuando.patron == null) {
        _avisar(Textos.validacionRangoInvalido, tono: TonoAviso.error);
        return;
      }
      if (!_cuando.vistaPreviaVista) {
        _avisar(Textos.vistaPreviaObligatoria, tono: TonoAviso.error);
        return;
      }
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
        _avisar(Textos.envioSinDestinatarios, tono: TonoAviso.error);
        return;
      }

      final bool confirmado = await _confirmar(conteo);
      if (!confirmado || !mounted) {
        return;
      }

      // El identificador se reserva SIEMPRE, no solo cuando hay adjuntos.
      //
      // ────────────────────────────────────────────────────────────────────────
      // Es lo que impide que el mismo aviso salga dos veces (DT-24).
      // ────────────────────────────────────────────────────────────────────────
      //
      // El servidor crea el mensaje con `create`, que falla si el documento ya
      // existe. Mientras el formulario no se vacíe, este identificador es el
      // mismo, así que un segundo envío del mismo texto lo rechaza el servidor
      // en vez de crear un mensaje nuevo. `_limpiar()` lo suelta, y por eso
      // repetir un aviso a propósito —escribiéndolo de nuevo— sigue siendo
      // posible.
      //
      // Antes solo se reservaba con adjuntos, y salía la paradoja de que un
      // aviso con una nota de voz estaba protegido y uno de solo texto no.
      _idReservado ??= ref.read(repositorioAdjuntosProvider).reservarIdMensaje();
      final String mensajeId = _idReservado!;
      final List<AdjuntoSubido> subidos = <AdjuntoSubido>[];

      if (_adjuntos.hayAlgo) {
        setState(() => _subiendo = true);
        // Las reglas de Storage dependen de la ruta `mensajes/{id}/…`, así que
        // los adjuntos se suben contra este identificador antes de que el
        // mensaje exista.
        final RepositorioAdjuntos adj = ref.read(repositorioAdjuntosProvider);

        // ────────────────────────────────────────────────────────────────────
        // SE SUBEN EN EL ORDEN EN QUE SE ADJUNTARON, Y SE MANDAN EN ESE ORDEN.
        // ────────────────────────────────────────────────────────────────────
        //
        // Es un `for` secuencial y no subidas en paralelo. Ir en paralelo sería
        // más rápido, pero el orden de llegada lo decidiría la red: la imagen
        // pequeña terminaría antes que la nota de voz que iba delante, y el
        // receptor las vería al revés de como se pusieron.
        //
        // Cada subida dice CUÁL falló. Con un «no se pudo enviar» a secas,
        // quien lo recibe no sabe si repetir el mensaje entero o solo volver a
        // adjuntar, y sobre todo no sabe que el fallo fue del adjunto.
        //
        // Y falla el envío completo a propósito: mandar el aviso sin la imagen
        // que lo explica es peor que no mandarlo, porque nadie se entera de
        // que falta.
        for (int i = 0; i < _adjuntos.piezas.length; i++) {
          final AdjuntoEnCurso pieza = _adjuntos.piezas[i];
          try {
            subidos.add(
              switch (pieza) {
                final VozEnCurso v => await adj.subirVoz(
                  mensajeId: mensajeId,
                  bytes: v.grabacion.bytes,
                  tipoMime: v.grabacion.tipoMime,
                  duracionSeg: v.grabacion.duracionSeg,
                  orden: i + 1,
                ),
                final ImagenEnCurso im => await adj.subirImagen(
                  mensajeId: mensajeId,
                  bytes: im.archivo.bytes,
                  tipoMime: im.archivo.tipoMime,
                  nombreOriginal: im.archivo.nombre,
                  orden: i + 1,
                ),
              },
            );
          } on Object catch (_) {
            if (mounted) {
              _avisar(
                pieza is VozEnCurso
                    ? Textos.falloSubidaVoz
                    : Textos.falloSubidaImagen,
                tono: TonoAviso.error,
              );
            }
            return;
          }
        }
        if (mounted) {
          setState(() => _subiendo = false);
        }
      }

      // Programado o recurrente: no se despacha nada ahora, se encola.
      if (!_cuando.esAhora) {
        await ref
            .read(repositorioProgramacionProvider)
            .programar(
              titulo: _titulo.text,
              cuerpo: _cuerpo.text,
              urgente: _urgente,
              requiereConfirmacion: _requiereConfirmacion,
              destinatarios: _destinatarios().aMapa(),
              ejecutarEn: _cuando.fecha,
              recurrencia: _cuando.patron,
              confirmacionUrgente: _urgente,
              mensajeId: mensajeId,
              adjuntos: subidos,
            );

        if (!mounted) {
          return;
        }
        _avisar(
          _cuando.modo == ModoEnvio.recurrente
              ? Textos.recurrenteCorrecto(_cuando.patron!.horaDelDia)
              : Textos.programadoCorrecto('${_cuando.fecha}'),
        );
        _limpiar();
        return;
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
            adjuntos: subidos,
          );

      if (!mounted) {
        return;
      }

      // ────────────────────────────────────────────────────────────────────────
      // SE VACÍA SIEMPRE QUE EL MENSAJE SE HAYA CREADO, CON FALLOS O SIN ELLOS.
      // ────────────────────────────────────────────────────────────────────────
      //
      // Antes solo se vaciaba en el envío perfecto, y eso mandó avisos por
      // duplicado a veinte catedráticos (DT-24). Con un destinatario fallido
      // —alguien en pestaña, un token muerto— el formulario se quedaba con el
      // texto escrito y el acuse era un aviso rojo de seis segundos: se leía
      // como «no se envió», y quien enviaba volvía a pulsar.
      //
      // Un fallo parcial no es un envío fallido. El mensaje existe, quedó
      // registrado y la mayoría lo recibió; reenviarlo no arregla nada, porque
      // a quien le falló le volverá a fallar por el mismo motivo.
      _limpiar();

      _avisar(
        r.huboFallos
            ? Textos.envioConFallos(r.entregados, r.total, r.fallidos)
            : Textos.envioCorrecto(r.entregados, r.total),
        // Rojo, no. En esta aplicación el rojo es lo urgente y lo que salió
        // mal, y un envío con fallos parciales no es ninguna de las dos cosas:
        // es información que hay que mirar. El texto ya lo dice bien —«Enviado
        // a 19 de 20»—; era el color el que contradecía al texto.
        tono: r.huboFallos ? TonoAviso.atencion : TonoAviso.correcto,
      );
    } on FirebaseFunctionsException catch (e) {
      // El mensaje del servidor es el bueno: explica en lenguaje llano por qué
      // no se envió, y lo escribió el dominio.
      if (mounted) {
        _avisar(e.message ?? Textos.envioFallido, tono: TonoAviso.error);
      }
    } on Object catch (_) {
      if (mounted) {
        _avisar(Textos.envioFallido, tono: TonoAviso.error);
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
    // Se suelta el identificador: lo que venga después es un mensaje nuevo y
    // tiene derecho a su propio sitio, aunque el texto sea idéntico. Sin esto,
    // repetir un aviso a propósito quedaría bloqueado para siempre (DT-24).
    _idReservado = null;
    setState(() {
      _urgente = false;
      _requiereConfirmacion = false;
      _adjuntos = const AdjuntosEnCurso();
      _cuando = const EleccionEnvio(modo: ModoEnvio.ahora);
    });
  }

  void _avisar(String texto, {TonoAviso tono = TonoAviso.correcto}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: switch (tono) {
          TonoAviso.correcto => ColoresSian.confirmado,
          // Dorado oscurecido: 5.03:1 con blanco encima, que cumple AA para
          // texto normal (RNF-13). Y no se confunde con el rojo de urgente.
          TonoAviso.atencion => ColoresSian.doradoTexto,
          TonoAviso.error => ColoresSian.urgente,
        },
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
      contenido: _ResumenConteo(
        conteo: conteo,
        urgente: _urgente,
        adjuntos: _adjuntos,
      ),
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

                Programador(
                  eleccion: _cuando,
                  alCambiar: (EleccionEnvio e) => setState(() => _cuando = e),
                ),
                const SizedBox(height: 24),

                PanelAdjuntos(
                  adjuntos: _adjuntos,
                  alCambiar: (AdjuntosEnCurso a) =>
                      setState(() => _adjuntos = a),
                  alOcuparse: (bool ocupado) =>
                      setState(() => _adjuntoAMedias = ocupado),
                  crear: widget.crearGrabadora,
                  elegir: widget.elegirImagen,
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

                // El botón dice POR QUÉ no se puede pulsar. Uno gris y mudo
                // deja a la persona intentándolo sin saber qué le falta.
                FilledButton.icon(
                  onPressed: _enviando || _adjuntoAMedias
                      ? null
                      : _intentarEnviar,
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
                  label: Text(switch ((_enviando, _subiendo, _adjuntoAMedias)) {
                    (_, _, true) => Textos.adjuntoAMedias,
                    (_, true, _) => Textos.subiendoAdjuntos,
                    (true, _, _) => Textos.contandoDestinatarios,
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
    // Solo los activos: ofrecer uno desactivado sería tender la trampa,
    // porque el servidor rechaza el envío a un grupo inactivo.
    final AsyncValue<List<GrupoDetalle>> grupos = ref.watch(
      gruposActivosProvider,
    );

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
            data: (List<GrupoDetalle> lista) => lista.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(left: 16, top: 8),
                    child: Text(Textos.sinGruposTodavia),
                  )
                : Wrap(
                    spacing: 8,
                    children: <Widget>[
                      for (final GrupoDetalle g in lista)
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
  const _ResumenConteo({
    required this.conteo,
    required this.urgente,
    required this.adjuntos,
  });

  final ConteoDestinatarios conteo;
  final bool urgente;
  final AdjuntosEnCurso adjuntos;

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
        // ──────────────────────────────────────────────────────────────────
        // QUÉ SE LLEVA EL MENSAJE, DICHO ANTES DE QUE SEA IRREVERSIBLE.
        // ──────────────────────────────────────────────────────────────────
        //
        // Una imagen que se creía adjunta y no lo estaba no se descubre hasta
        // que alguien la echa de menos en la bandeja, y para entonces ya no
        // hay arreglo: RN-03 dice que un mensaje enviado no se edita. Aquí sí
        // hay arreglo, porque todavía se puede cancelar.
        //
        // Va junto al número de destinatarios porque es la misma idea: lo que
        // no se puede deshacer se enseña antes.
        const SizedBox(height: 12),
        Text(
          adjuntos.hayAlgo
              ? Textos.resumenAdjuntos(
                  voces: adjuntos.voces,
                  imagenes: adjuntos.imagenes,
                )
              : Textos.resumenSinAdjuntos,
          style: tema.textTheme.bodyMedium,
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
          const SizedBox(height: 8),
          // Lo importante no es solo cuántos quedan fuera, sino que quedarse
          // fuera NO deja a nadie a medias en el reporte.
          Text(
            Textos.exclusionNoQuedaPendiente,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
