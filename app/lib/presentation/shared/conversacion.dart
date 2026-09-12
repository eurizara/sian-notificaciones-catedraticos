/// SIAN — Una conversación sobre un aviso (DT-27, mejora M-5).
///
/// La misma pieza para los dos lados: el catedrático la ve dentro del aviso, y
/// quien lo emitió, desde su panel. Dos pantallas que muestran lo mismo con
/// código distinto es cómo se llega a que una se quede atrás.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/proveedores_respuestas.dart';
import '../../infrastructure/firebase/repositorio_respuestas.dart';
import 'tema.dart';
import 'textos.dart';

/// Largo máximo de una respuesta. El mismo que valida el servidor.
const int largoMaximoRespuesta = 1000;

class Conversacion extends ConsumerStatefulWidget {
  const Conversacion({
    required this.mensajeId,
    required this.hiloUid,
    required this.miLado,
    required this.nombreDelOtro,
    this.conRedactor = true,
    super.key,
  });

  final String mensajeId;

  /// El catedrático de esta conversación. Es el identificador del hilo.
  final String hiloUid;

  final LadoHilo miLado;

  /// Cómo se llama a la otra parte, para decir a quién le llega lo que se
  /// escribe.
  final String nombreDelOtro;

  final bool conRedactor;

  @override
  ConsumerState<Conversacion> createState() => _ConversacionState();
}

class _ConversacionState extends ConsumerState<Conversacion> {
  /// Se abre una vez. Pedirlo en `build` volvía a suscribirse a Firestore en
  /// cada redibujado —cada letra escrita en el cuadro de abajo—.
  late final Stream<List<Turno>> _turnos = ref
      .read(repositorioRespuestasProvider)
      .observarTurnos(widget.mensajeId, widget.hiloUid);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StreamBuilder<List<Turno>>(
          stream: _turnos,
          builder: (BuildContext context, AsyncSnapshot<List<Turno>> s) {
            final List<Turno> turnos = s.data ?? const <Turno>[];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final Turno t in turnos)
                  _Burbuja(turno: t, esMio: t.lado == widget.miLado),
              ],
            );
          },
        ),
        if (widget.conRedactor)
          RedactorRespuesta(
            mensajeId: widget.mensajeId,
            // El emisor tiene que decir en qué hilo contesta; el catedrático
            // no puede elegir: su hilo es él.
            hiloUid: widget.miLado == LadoHilo.emisor ? widget.hiloUid : null,
            ayuda: widget.miLado == LadoHilo.emisor
                ? Textos.ayudaContestar(widget.nombreDelOtro)
                : Textos.ayudaRespuesta(widget.nombreDelOtro),
          ),
      ],
    );
  }
}

/// Un turno. Lo propio a la derecha y lo del otro a la izquierda, como en
/// cualquier conversación que ya se sabe leer — pero con el nombre escrito,
/// porque la posición sola no la percibe quien usa un lector de pantalla.
class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.turno, required this.esMio});

  final Turno turno;
  final bool esMio;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final PaletaSian paleta = PaletaSian.de(context);
    final String quien = esMio ? Textos.tu : turno.autorNombre;
    final String cuando = turno.creadoEn == null
        ? Textos.respuestaSinHora
        : DateFormat('dd/MM/yyyy · HH:mm').format(turno.creadoEn!);

    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(
            color: esMio
                ? paleta.primario.withValues(alpha: 0.10)
                : tema.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '$quien · $cuando',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(turno.texto),
            ],
          ),
        ),
      ),
    );
  }
}

/// El cuadro para escribir y el botón de enviar.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Lo que se aprendió con DT-24, aplicado desde el principio.
/// ────────────────────────────────────────────────────────────────────────────
///
///   · Mientras se envía, el botón no se puede volver a pulsar.
///   · Si sale bien, el cuadro se vacía: queda claro que se fue, y no hay nada
///     que invite a mandarlo otra vez.
///   · Si falla, el texto se queda —no se pierde lo escrito— y **conserva su
///     identificador**: si en realidad sí había llegado, reintentar no lo
///     duplica, porque el servidor reconoce el mismo turno.
class RedactorRespuesta extends ConsumerStatefulWidget {
  const RedactorRespuesta({
    required this.mensajeId,
    required this.ayuda,
    this.hiloUid,
    super.key,
  });

  final String mensajeId;
  final String? hiloUid;
  final String ayuda;

  @override
  ConsumerState<RedactorRespuesta> createState() => _RedactorRespuestaState();
}

class _RedactorRespuestaState extends ConsumerState<RedactorRespuesta> {
  final TextEditingController _texto = TextEditingController();
  bool _enviando = false;

  /// Uno por borrador, no por pulsación. Se renueva cuando el envío sale, o
  /// cuando el texto cambió desde el intento fallido: si aquel sí había
  /// llegado, reutilizar el identificador descartaría en silencio lo nuevo.
  String? _turnoId;
  String? _textoDelTurno;

  @override
  void initState() {
    super.initState();
    _texto.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final String texto = _texto.text.trim();
    if (texto.isEmpty || _enviando) {
      return;
    }
    final RepositorioRespuestas repo = ref.read(repositorioRespuestasProvider);
    if (_turnoId == null || _textoDelTurno != texto) {
      _turnoId = repo.nuevoIdDeTurno();
      _textoDelTurno = texto;
    }
    setState(() => _enviando = true);

    try {
      await repo.responder(
        mensajeId: widget.mensajeId,
        texto: texto,
        turnoId: _turnoId!,
        hiloUid: widget.hiloUid,
      );
      if (!mounted) {
        return;
      }
      _texto.clear();
      _turnoId = null;
      _textoDelTurno = null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(Textos.respuestaEnviada)));
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? Textos.errorInesperado)),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(Textos.errorInesperado)));
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hayTexto = _texto.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _texto,
            enabled: !_enviando,
            minLines: 1,
            maxLines: 5,
            maxLength: largoMaximoRespuesta,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: Textos.etiquetaRespuesta,
              helperText: widget.ayuda,
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: hayTexto && !_enviando ? _enviar : null,
              icon: _enviando
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                _enviando
                    ? Textos.enviandoRespuesta
                    : Textos.botonEnviarRespuesta,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
