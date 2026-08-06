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
      color: ColoresSian.primario.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.graphic_eq, color: ColoresSian.primario),
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
            url.when(
              loading: () => const LinearProgressIndicator(),
              error: (Object e, StackTrace _) => Text(
                Textos.detalleErrorAdjunto,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: ColoresSian.urgente,
                ),
              ),
              data: (String u) =>
                  SizedBox(height: 56, child: ReproductorAudio(url: u)),
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
    final ThemeData tema = Theme.of(context);

    if (!_pedida) {
      return OutlinedButton.icon(
        onPressed: () => setState(() => _pedida = true),
        icon: const Icon(Icons.image_outlined),
        label: const Text(Textos.imagenTocarParaVer),
      );
    }

    return _ImagenCargada(ruta: widget.ruta, tema: tema);
  }
}

class _ImagenCargada extends ConsumerWidget {
  const _ImagenCargada({required this.ruta, required this.tema});

  final String ruta;
  final ThemeData tema;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<String> url = ref.watch(urlAdjuntoProvider(ruta));

    return url.when(
      loading: () => const SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text(Textos.imagenCargando),
            ],
          ),
        ),
      ),
      error: (Object e, StackTrace _) => Text(
        Textos.detalleErrorAdjunto,
        style: tema.textTheme.bodySmall?.copyWith(color: ColoresSian.urgente),
      ),
      data: (String u) => GestureDetector(
        // Un plano de evacuación en miniatura no sirve de nada: hay que poder
        // ampliarlo.
        onTap: () => showDialog<void>(
          context: context,
          builder: (BuildContext c) => Dialog(
            insetPadding: const EdgeInsets.all(12),
            child: Stack(
              children: <Widget>[
                InteractiveViewer(child: Image.network(u)),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton.filledTonal(
                    onPressed: () => Navigator.of(c).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                u,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                    const Text(Textos.detalleErrorAdjunto),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              Textos.imagenTocarParaAmpliar,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
