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

/// Un adjunto puesto por el emisor, todavía sin subir.
sealed class AdjuntoEnCurso {
  const AdjuntoEnCurso();

  int get bytes;
}

class VozEnCurso extends AdjuntoEnCurso {
  const VozEnCurso(this.grabacion);

  final Grabacion grabacion;

  @override
  int get bytes => grabacion.bytes.length;
}

class ImagenEnCurso extends AdjuntoEnCurso {
  const ImagenEnCurso(this.archivo);

  final ArchivoElegido archivo;

  @override
  int get bytes => archivo.bytes.length;
}

/// Lo que el emisor lleva adjunto, todavía sin subir.
///
/// ────────────────────────────────────────────────────────────────────────────
/// UNA LISTA ORDENADA, NO UN HUECO POR TIPO.
/// ────────────────────────────────────────────────────────────────────────────
///
/// El orden lo elige quien redacta y significa algo: un plano, después la nota
/// de voz que lo explica, después la foto del punto de reunión. El receptor los
/// ve en ese mismo orden, y eso solo es posible si se guarda —no hay forma de
/// reconstruir después lo que nunca se anotó.
class AdjuntosEnCurso {
  const AdjuntosEnCurso([this.piezas = const <AdjuntoEnCurso>[]]);

  final List<AdjuntoEnCurso> piezas;

  bool get hayAlgo => piezas.isNotEmpty;

  int get voces => piezas.whereType<VozEnCurso>().length;
  int get imagenes => piezas.whereType<ImagenEnCurso>().length;
  int get bytesTotales =>
      piezas.fold(0, (int suma, AdjuntoEnCurso a) => suma + a.bytes);

  bool get cabeOtraVoz => voces < LimitesAdjuntos.maxVoces;
  bool get cabeOtraImagen => imagenes < LimitesAdjuntos.maxImagenes;

  AdjuntosEnCurso mas(AdjuntoEnCurso pieza) =>
      AdjuntosEnCurso(<AdjuntoEnCurso>[...piezas, pieza]);

  AdjuntosEnCurso sin(int indice) => AdjuntosEnCurso(
    <AdjuntoEnCurso>[
      for (int i = 0; i < piezas.length; i++)
        if (i != indice) piezas[i],
    ],
  );
}

/// Cuántos adjuntos caben. Duplicados del dominio del servidor, que es la
/// fuente de verdad: aquí solo sirven para no dejar adjuntar de más y
/// descubrirlo al enviar.
abstract final class LimitesAdjuntos {
  static const int maxImagenes = 3;
  static const int maxVoces = 2;
  static const int maxBytesTotal = 10 * 1024 * 1024;
}

class PanelAdjuntos extends StatefulWidget {
  const PanelAdjuntos({
    required this.adjuntos,
    required this.alCambiar,
    this.alOcuparse,
    this.crear = crearGrabadora,
    this.elegir = elegirImagen,
    super.key,
  });

  final AdjuntosEnCurso adjuntos;
  final ValueChanged<AdjuntosEnCurso> alCambiar;

  /// Avisa de que hay algo a medias: grabando, o leyendo la imagen elegida.
  ///
  /// ──────────────────────────────────────────────────────────────────────────
  /// Lo que está a medias todavía NO está en `adjuntos`.
  /// ──────────────────────────────────────────────────────────────────────────
  ///
  /// Una grabación solo pasa a formar parte del mensaje cuando se detiene, y
  /// una imagen cuando termina de leerse. Si en ese hueco alguien pulsa
  /// enviar, el aviso sale sin ella y nada lo advierte: la persona cree que
  /// mandó una nota de voz y mandó texto suelto. Por eso el panel tiene que
  /// decirlo hacia fuera, no basta con saberlo por dentro.
  final ValueChanged<bool>? alOcuparse;

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

  /// Hay una imagen elegida que todavía se está leyendo.
  bool _leyendoImagen = false;

  bool get _ocupado => _grabadora.grabando || _leyendoImagen;

  /// Último valor anunciado, para no repetir el aviso en cada repintado.
  bool _ultimoOcupado = false;

  void _anunciarOcupacion() {
    if (_ocupado != _ultimoOcupado) {
      _ultimoOcupado = _ocupado;
      widget.alOcuparse?.call(_ocupado);
    }
  }

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
    setState(_anunciarOcupacion);
  }

  Future<void> _detener({bool porLimite = false}) async {
    _cronometro?.cancel();
    _cronometro = null;

    final Grabacion? g = await _grabadora.detener();
    if (!mounted) {
      return;
    }

    setState(() {
      _anunciarOcupacion();
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
      _anadir(VozEnCurso(g));
    }
  }

  /// Añade al final: el orden es el de quien redacta, y así se conserva.
  void _anadir(AdjuntoEnCurso pieza) {
    final AdjuntosEnCurso nuevos = widget.adjuntos.mas(pieza);

    // El peso del conjunto se comprueba aquí y no al enviar: descubrir que
    // sobra un adjunto cuando ya se pulsó enviar es descubrirlo tarde.
    if (nuevos.bytesTotales > LimitesAdjuntos.maxBytesTotal) {
      setState(() => _error = Textos.adjuntosMuyPesados);
      return;
    }
    widget.alCambiar(nuevos);
  }

  Future<void> _elegirImagen() async {
    setState(() {
      _error = null;
      _leyendoImagen = true;
      _anunciarOcupacion();
    });

    final ArchivoElegido? a;
    try {
      a = await widget.elegir();
    } finally {
      if (mounted) {
        setState(() {
          _leyendoImagen = false;
          _anunciarOcupacion();
        });
      }
    }

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

    _anadir(ImagenEnCurso(a));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final bool grabando = _grabadora.grabando;
    final AdjuntosEnCurso puestos = widget.adjuntos;

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
            // Un botón que ya no puede añadir nada se apaga y lo dice en su
            // etiqueta: pulsarlo y que no pase nada es peor que no ofrecerlo.
            if (_grabadora.soportada)
              FilledButton.tonalIcon(
                onPressed: grabando || puestos.cabeOtraVoz
                    ? _alternarGrabacion
                    : null,
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
                      : puestos.cabeOtraVoz
                      ? Textos.vozGrabar
                      : Textos.vozAlMaximo,
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
              onPressed: grabando || !puestos.cabeOtraImagen
                  ? null
                  : _elegirImagen,
              icon: const Icon(Icons.image_outlined),
              label: Text(
                puestos.cabeOtraImagen
                    ? Textos.imagenElegir
                    : Textos.imagenAlMaximo,
              ),
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

        // ────────────────────────────────────────────────────────────────────
        // EN EL ORDEN EN QUE SE PUSIERON, Y NUMERADOS.
        // ────────────────────────────────────────────────────────────────────
        //
        // El receptor los verá exactamente así. Enseñar aquí el mismo orden, y
        // con su número delante, es lo que permite comprobarlo antes de enviar
        // en vez de descubrirlo después en el teléfono de otro.
        for (int i = 0; i < puestos.piezas.length; i++)
          if (!(grabando && puestos.piezas[i] is VozEnCurso)) ...<Widget>[
            const SizedBox(height: 12),
            switch (puestos.piezas[i]) {
              final VozEnCurso v => _Adjunto(
                orden: i + 1,
                icono: Icons.graphic_eq,
                titulo: Textos.vozAdjunta(v.grabacion.duracionSeg),
                detalle: Textos.pesoLegible(v.bytes),
                alQuitar: () => widget.alCambiar(puestos.sin(i)),
              ),
              final ImagenEnCurso im => _Adjunto(
                orden: i + 1,
                icono: Icons.image,
                titulo: im.archivo.nombre,
                detalle: Textos.pesoLegible(im.bytes),
                vistaPrevia: im.archivo.bytes,
                alQuitar: () => widget.alCambiar(puestos.sin(i)),
              ),
            },
          ],

        if (puestos.piezas.length > 1) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            Textos.adjuntosOrden(Textos.pesoLegible(puestos.bytesTotales)),
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
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
    required this.orden,
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.alQuitar,
    this.vistaPrevia,
  });

  /// Posición en la que lo verá el receptor, empezando en 1.
  final int orden;
  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback alQuitar;
  final Uint8List? vistaPrevia;

  @override
  Widget build(BuildContext context) {
    final Uint8List? previa = vistaPrevia;
    final ThemeData tema = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 20,
              child: Text(
                '$orden.',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (previa != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(
                  previa,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              )
            else
              Icon(icono, color: ColoresSian.primario),
          ],
        ),
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
