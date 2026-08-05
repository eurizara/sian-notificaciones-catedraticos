/// SIAN — Nota de voz e imagen al redactar (RF-MSG-03, 04, 05, 07, 08).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Una nota de voz existe porque escribir con prisa es difícil.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Quien tiene que avisar de una fuga de gas no va a redactar 500 caracteres.
/// Por eso grabar tiene que ser un botón grande y un solo gesto, y por eso el
/// contador de segundos avisa **mientras** se graba y no al intentar enviar:
/// descubrir a los 70 segundos que el límite eran 60 es perder el mensaje
/// entero y volver a empezar.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/audio/grabacion.dart';
import '../../core/audio/grabadora.dart';
import '../../core/plataforma/selector_archivo.dart';
import '../../infrastructure/firebase/repositorio_adjuntos.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';

/// Lo que el emisor lleva adjunto, todavía sin subir.
class AdjuntosEnCurso {
  const AdjuntosEnCurso({this.voz, this.imagen});

  final Grabacion? voz;
  final ArchivoElegido? imagen;

  bool get hayAlgo => voz != null || imagen != null;
}

class PanelAdjuntos extends StatefulWidget {
  const PanelAdjuntos({
    required this.adjuntos,
    required this.alCambiar,
    this.crear = crearGrabadora,
    this.elegir = elegirImagen,
    super.key,
  });

  final AdjuntosEnCurso adjuntos;
  final ValueChanged<AdjuntosEnCurso> alCambiar;

  /// Inyectables para poder probar sin navegador.
  final Grabadora Function() crear;
  final Future<ArchivoElegido?> Function() elegir;

  @override
  State<PanelAdjuntos> createState() => _PanelAdjuntosState();
}

class _PanelAdjuntosState extends State<PanelAdjuntos> {
  late final Grabadora _grabadora = widget.crear();
  Timer? _cronometro;
  String? _error;

  @override
  void dispose() {
    _cronometro?.cancel();
    // Si alguien cierra la pantalla grabando, el micrófono se suelta igual.
    // Dejarlo abierto encendería el indicador del sistema indefinidamente.
    _grabadora.liberar();
    super.dispose();
  }

  Future<void> _alternarGrabacion() async {
    if (_grabadora.grabando) {
      await _detener();
      return;
    }

    setState(() => _error = null);
    final FalloGrabacion? fallo = await _grabadora.iniciar();

    if (!mounted) {
      return;
    }
    if (fallo != null) {
      setState(() => _error = Textos.explicarFalloVoz(fallo));
      return;
    }

    // Un tic por segundo: es lo que mueve el contador y lo que corta solo al
    // llegar al límite.
    _cronometro = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      if (!mounted) {
        return;
      }
      setState(() {});
      if (_grabadora.segundos >= LimitesVoz.maxSegundos) {
        unawaited(_detener(porLimite: true));
      }
    });
    setState(() {});
  }

  Future<void> _detener({bool porLimite = false}) async {
    _cronometro?.cancel();
    _cronometro = null;

    final Grabacion? g = await _grabadora.detener();
    if (!mounted) {
      return;
    }

    setState(() {
      if (g == null) {
        _error = Textos.vozSinContenido;
        return;
      }
      if (g.excedePeso) {
        _error = Textos.vozMuyPesada;
        return;
      }
      _error = porLimite ? Textos.vozCortadaPorLimite : null;
    });

    if (g != null && g.esValida) {
      widget.alCambiar(
        AdjuntosEnCurso(voz: g, imagen: widget.adjuntos.imagen),
      );
    }
  }

  Future<void> _elegirImagen() async {
    setState(() => _error = null);
    final ArchivoElegido? a = await widget.elegir();

    if (a == null || !mounted) {
      return;
    }

    // Se comprueba antes de subir: no tiene sentido gastar los datos móviles
    // de nadie en una subida que las reglas de Storage van a rechazar igual.
    final String? motivo = motivoRechazoImagen(
      bytes: a.bytes.length,
      tipoMime: a.tipoMime,
    );
    if (motivo != null) {
      setState(() => _error = Textos.explicarRechazoImagen(motivo));
      return;
    }

    widget.alCambiar(AdjuntosEnCurso(voz: widget.adjuntos.voz, imagen: a));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final bool grabando = _grabadora.grabando;
    final Grabacion? voz = widget.adjuntos.voz;
    final ArchivoElegido? imagen = widget.adjuntos.imagen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(Textos.etiquetaAdjuntos, style: tema.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          Textos.adjuntosDetalle,
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            if (_grabadora.soportada)
              FilledButton.tonalIcon(
                onPressed: _alternarGrabacion,
                style: grabando
                    ? FilledButton.styleFrom(
                        backgroundColor: ColoresSian.urgente,
                        foregroundColor: Colors.white,
                      )
                    : null,
                icon: Icon(grabando ? Icons.stop : Icons.mic),
                label: Text(
                  grabando
                      ? Textos.vozDetener(_grabadora.segundos)
                      : Textos.vozGrabar,
                ),
              )
            else
              Text(
                Textos.vozSinSoporte,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),

            OutlinedButton.icon(
              onPressed: grabando ? null : _elegirImagen,
              icon: const Icon(Icons.image_outlined),
              label: const Text(Textos.imagenElegir),
            ),
          ],
        ),

        // Mientras se graba, la cuenta atrás es lo único que importa: avisa
        // antes de que el límite arruine la grabación entera.
        if (grabando) ...<Widget>[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _grabadora.segundos / LimitesVoz.maxSegundos,
            color: _grabadora.segundos > LimitesVoz.maxSegundos - 10
                ? ColoresSian.urgente
                : ColoresSian.primario,
          ),
          const SizedBox(height: 4),
          Text(
            Textos.vozRestantes(LimitesVoz.maxSegundos - _grabadora.segundos),
            style: tema.textTheme.bodySmall,
          ),
        ],

        if (voz != null && !grabando) ...<Widget>[
          const SizedBox(height: 12),
          _Adjunto(
            icono: Icons.graphic_eq,
            titulo: Textos.vozAdjunta(voz.duracionSeg),
            detalle: Textos.pesoLegible(voz.bytes.length),
            alQuitar: () => widget.alCambiar(
              AdjuntosEnCurso(imagen: widget.adjuntos.imagen),
            ),
          ),
        ],

        if (imagen != null) ...<Widget>[
          const SizedBox(height: 12),
          _Adjunto(
            icono: Icons.image,
            titulo: imagen.nombre,
            detalle: Textos.pesoLegible(imagen.bytes.length),
            vistaPrevia: imagen.bytes,
            alQuitar: () =>
                widget.alCambiar(AdjuntosEnCurso(voz: widget.adjuntos.voz)),
          ),
        ],

        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.error_outline,
                size: 18,
                color: ColoresSian.urgente,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _error!,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: ColoresSian.urgente,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Un adjunto ya listo, con su tamaño y la forma de quitarlo.
class _Adjunto extends StatelessWidget {
  const _Adjunto({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.alQuitar,
    this.vistaPrevia,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback alQuitar;
  final Uint8List? vistaPrevia;

  @override
  Widget build(BuildContext context) {
    final Uint8List? previa = vistaPrevia;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: previa != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(
                  previa,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              )
            : Icon(icono, color: ColoresSian.primario),
        title: Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(detalle),
        trailing: IconButton(
          onPressed: alQuitar,
          icon: const Icon(Icons.close),
          tooltip: Textos.quitarAdjunto,
        ),
      ),
    );
  }
}
