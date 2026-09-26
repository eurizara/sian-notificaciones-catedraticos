/// SIAN — Reproducción de la nota de voz y vista de la imagen (RF-ENT-08, 09).
///
/// ────────────────────────────────────────────────────────────────────────────
/// El reproductor es un `<audio>` del navegador, no uno propio.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Safari graba en `audio/mp4` y Chrome en `audio/webm`, y no hay un formato
/// que ambos produzcan. El elemento nativo entiende los dos y trae sus propios
/// controles accesibles, con teclado y lector de pantalla ya resueltos.
/// Reimplementarlos sería trabajo para quedar peor.
///
/// La URL se pide en el momento de mostrar y no se guarda: las de Storage
/// caducan, y una guardada dejaría de funcionar sin decir por qué.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_dispositivos.dart';
import '../../core/navegador.dart';
import '../../core/plataforma/descarga.dart';
import '../../infrastructure/firebase/repositorio_adjuntos.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';
import 'audio_html.dart';

final Provider<RepositorioAdjuntos> repositorioAdjuntosDocenteProvider =
    Provider<RepositorioAdjuntos>((Ref ref) => RepositorioAdjuntos());

final urlAdjuntoProvider = FutureProvider.family<String, String>(
  (Ref ref, String ruta) =>
      ref.watch(repositorioAdjuntosDocenteProvider).urlDe(ruta),
);

/// Alto de los controles de audio. Constante a propósito.
const double _altoReproductor = 56;

/// Nota de voz con los controles del navegador.
class NotaDeVoz extends ConsumerWidget {
  const NotaDeVoz({required this.ruta, this.duracionSeg, super.key});

  final String ruta;
  final int? duracionSeg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData tema = Theme.of(context);
    final AsyncValue<String> url = ref.watch(urlAdjuntoProvider(ruta));

    return Card(
      color: PaletaSian.de(context).primario.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.graphic_eq, color: PaletaSian.de(context).primario),
                const SizedBox(width: 8),
                Text(
                  duracionSeg == null
                      ? Textos.detalleNotaDeVoz
                      : Textos.vozAdjunta(duracionSeg!),
                  style: tema.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Mismo alto en los tres estados, por la misma razón que la
            // imagen: una fila que cambia de tamaño al cargar empuja la lista
            // y rompe el desplazamiento hacia arriba.
            SizedBox(
              height: _altoReproductor,
              child: url.when(
                loading: () => const Center(child: LinearProgressIndicator()),
                error: (Object e, StackTrace _) => Center(
                  child: Text(
                    Textos.detalleErrorAdjunto,
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: PaletaSian.de(context).urgente,
                    ),
                  ),
                ),
                data: (String u) => ReproductorAudio(url: u),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Imagen adjunta, ampliable a pantalla completa.
///
/// ────────────────────────────────────────────────────────────────────────────
/// No se descarga hasta que alguien la pide.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Una bandeja con diez avisos ilustrados serían diez descargas de hasta cinco
/// megas cada una nada más abrir la pantalla, con datos móviles y sin haber
/// pedido ninguna. Lo que urge de un aviso es el texto; la imagen casi siempre
/// es apoyo.
///
/// Se muestra un botón que dice que hay imagen, y se descarga al tocarlo. En
/// una alerta urgente eso cuesta un toque; a cambio, la bandeja abre igual de
/// rápido con conexión mala, que es cuando más falta hace.
class ImagenAdjunta extends ConsumerStatefulWidget {
  const ImagenAdjunta({required this.ruta, super.key});

  final String ruta;

  @override
  ConsumerState<ImagenAdjunta> createState() => _ImagenAdjuntaState();
}

class _ImagenAdjuntaState extends ConsumerState<ImagenAdjunta> {
  bool _pedida = false;

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────────────
    // MISMO ALTO EN TODOS LOS ESTADOS. Esto no es estética.
    // ────────────────────────────────────────────────────────────────────────
    //
    // Una imagen sin alto declarado mide lo que mida el archivo, y eso no se
    // sabe hasta que se descarga y decodifica. Dentro de una lista eso rompe
    // el desplazamiento **hacia arriba**: al subir, la lista reconstruye lo
    // que quedó por encima; cada imagen nace midiendo cero y salta a su alto
    // real, todo lo de abajo se corre, y la vista vuelve donde estaba. El
    // dedo sube y la pantalla no.
    //
    // Hacia abajo no se nota, porque lo que crece está fuera de la vista. Por
    // eso el fallo parecía caprichoso: solo de abajo hacia arriba, y cediendo
    // tras varios intentos.
    //
    // Con un alto fijo, la fila mide lo mismo esté la imagen pedida,
    // cargando, cargada o rota. La lista no tiene que recalcular nada.
    return SizedBox(
      height: _altoImagen,
      child: !_pedida
          ? Center(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _pedida = true),
                icon: const Icon(Icons.image_outlined),
                label: const Text(Textos.imagenTocarParaVer),
              ),
            )
          : _ImagenCargada(ruta: widget.ruta),
    );
  }
}

/// Alto reservado para cualquier estado de la imagen.
const double _altoImagen = 220;

class _ImagenCargada extends ConsumerWidget {
  const _ImagenCargada({required this.ruta});

  final String ruta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData tema = Theme.of(context);
    final AsyncValue<String> url = ref.watch(urlAdjuntoProvider(ruta));

    return url.when(
      loading: () => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text(Textos.imagenCargando),
          ],
        ),
      ),
      error: (Object e, StackTrace _) => Center(
        child: Text(
          Textos.detalleErrorAdjunto,
          textAlign: TextAlign.center,
          style: tema.textTheme.bodySmall?.copyWith(color: PaletaSian.de(context).urgente),
        ),
      ),
      data: (String u) => GestureDetector(
        // En miniatura un plano de evacuación no sirve de nada: hay que poder
        // ampliarlo, y ahí sí a tamaño completo y con zoom.
        onTap: () => showDialog<void>(
          context: context,
          builder: (BuildContext c) => ImagenAmpliada(url: u, ruta: ruta),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                u,
                fit: BoxFit.cover,
                // El recuadro ya está reservado: mientras decodifica se deja
                // en blanco en vez de encoger la fila y volver a estirarla.
                frameBuilder:
                    (BuildContext _, Widget hijo, int? cuadro, bool sincrono) =>
                        cuadro == null && !sincrono
                        ? const Center(child: CircularProgressIndicator())
                        : hijo,
                errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                    Center(
                      child: Text(
                        Textos.detalleErrorAdjunto,
                        textAlign: TextAlign.center,
                        style: tema.textTheme.bodySmall,
                      ),
                    ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  Textos.imagenTocarParaAmpliar,
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La imagen a pantalla completa, con zoom y con **Guardar** (U-3).
///
/// La imagen se prepara al abrirse y no al tocar Guardar: en iPhone, Safari
/// solo abre el menú Compartir en el mismo gesto que lo pide, y bajarla después
/// del toque lo haría fallar. El botón se habilita cuando está lista.
class ImagenAmpliada extends ConsumerStatefulWidget {
  const ImagenAmpliada({required this.url, required this.ruta, super.key});

  final String url;

  /// La ruta en Storage; su último tramo da el nombre del archivo.
  final String ruta;

  @override
  ConsumerState<ImagenAmpliada> createState() => _ImagenAmpliadaState();
}

class _ImagenAmpliadaState extends ConsumerState<ImagenAmpliada> {
  ImagenPreparada? _lista;

  @override
  void initState() {
    super.initState();
    final String nombre = widget.ruta.split('/').last.isEmpty
        ? 'imagen-sian'
        : widget.ruta.split('/').last;
    prepararImagen(widget.url, nombre).then((ImagenPreparada? i) {
      if (mounted) {
        setState(() => _lista = i);
      }
    });
  }

  Future<void> _guardar() async {
    final ImagenPreparada? imagen = _lista;
    if (imagen == null) {
      return;
    }
    // En iPhone, «Guardar imagen» vive en el menú Compartir.
    final bool compartir =
        ref.read(repositorioDispositivosProvider).entorno.plataforma ==
        PlataformaWeb.ios;
    final bool ok = await guardarImagen(imagen, compartir: compartir);
    if (!ok && mounted && !compartir) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Textos.imagenNoSeGuardo)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(12),
    child: Stack(
      children: <Widget>[
        InteractiveViewer(
          child: Image.network(
            widget.url,
            errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Text(Textos.detalleErrorAdjunto, textAlign: TextAlign.center),
                ),
          ),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton.filledTonal(
                tooltip: _lista == null
                    ? Textos.guardandoImagen
                    : Textos.guardarImagen,
                onPressed: _lista == null ? null : _guardar,
                icon: const Icon(Icons.download),
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

