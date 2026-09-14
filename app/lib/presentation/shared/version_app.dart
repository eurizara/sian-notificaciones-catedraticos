/// SIAN — La versión, a la vista y comparada con la publicada.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Dos preguntas distintas, y las dos hacían falta.
/// ────────────────────────────────────────────────────────────────────────────
///
///   · **«¿Qué versión tengo?»** — la persona puede leerla y decirla por
///     teléfono. Antes, para saber qué código tenía alguien delante había que
///     mirar el `commit` de `version.json`: cuarenta caracteres que nadie va a
///     dictar.
///   · **«¿Es la última?»** — la aplicación lo comprueba sola contra lo que hay
///     publicado y ofrece actualizar. Una aplicación instalada puede llevar
///     días con la versión vieja sin que nadie se entere, y desde C-5 eso tiene
///     consecuencias medibles: el acuse de que una notificación se mostró lo
///     manda el service worker, así que un aparato atrasado aparece como «no se
///     mostró» aunque su dueño la haya visto.
///
/// El aviso de versión nueva **no interrumpe**: es una tarjeta que se puede
/// ignorar. Actualizar recarga la aplicación, y recargar mientras se redacta un
/// aviso urgente sería peor que estar una versión atrás.
///
/// ────────────────────────────────────────────────────────────────────────────
/// En un iPhone, «abrir la aplicación» no siempre es cargarla
/// ────────────────────────────────────────────────────────────────────────────
///
/// Una PWA instalada en iOS se restaura tal como se dejó: la misma página, con
/// el mismo código, sin volver a pedir nada al servidor. Se puede estar
/// «abriéndola» todos los días y seguir ejecutando el paquete de hace una
/// semana. Se midió el 12 de septiembre de 2026: el servidor publicaba 1.5.3 y
/// el teléfono seguía en una versión anterior a 1.5.0 —lo delató que registraba
/// su dispositivo sin decir qué versión era—.
///
/// Por eso la comprobación **se repite al volver a la aplicación**, y no solo
/// al arrancar: es el único momento en que una PWA restaurada puede enterarse
/// de que hay algo más nuevo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/plataforma/recarga.dart';
import '../../core/plataforma/version_desplegada.dart';
import '../../core/version.dart';
import 'tema.dart';
import 'textos.dart';

/// La versión publicada en el servidor, o nulo si no se pudo preguntar.
final versionPublicadaProvider = FutureProvider<String?>(
  (Ref ref) => consultarVersionPublicada(),
);

/// Vuelve a preguntar al servidor qué versión hay publicada.
///
/// Se llama al volver a la aplicación. En una PWA de iOS restaurada, esta es la
/// única forma de enterarse: no hubo arranque que hiciera la primera consulta.
class VigilanteDeVersion extends ConsumerStatefulWidget {
  const VigilanteDeVersion({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<VigilanteDeVersion> createState() => _VigilanteDeVersionState();
}

class _VigilanteDeVersionState extends ConsumerState<VigilanteDeVersion>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      ref.invalidate(versionPublicadaProvider);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// ¿Lo que se está usando es distinto de lo publicado?
///
/// Mientras no se sepa, `false`: un aviso de actualización que aparece porque
/// la consulta aún no volvió enseña a ignorarlo.
final hayVersionNuevaProvider = Provider<bool>((Ref ref) {
  final String? publicada = ref.watch(versionPublicadaProvider).value;
  return publicada != null && publicada.isNotEmpty && publicada != versionSian;
});

/// La línea discreta del pie: qué versión es esta.
class SelloDeVersion extends ConsumerWidget {
  const SelloDeVersion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData tema = Theme.of(context);
    final bool atrasada = ref.watch(hayVersionNuevaProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        atrasada
            ? Textos.versionConActualizacion(versionSian)
            : Textos.version(versionSian),
        textAlign: TextAlign.center,
        style: tema.textTheme.bodySmall?.copyWith(
          color: tema.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// La tarjeta que aparece solo cuando hay algo más nuevo publicado.
class AvisoDeVersionNueva extends ConsumerWidget {
  const AvisoDeVersionNueva({this.recargar = recargarAplicacion, super.key});

  /// Inyectable: en las pruebas no hay navegador que recargar.
  final void Function() recargar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hayVersionNuevaProvider)) {
      return const SizedBox.shrink();
    }
    final ThemeData tema = Theme.of(context);
    final PaletaSian paleta = PaletaSian.de(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: paleta.primario.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: <Widget>[
            Icon(Icons.system_update_alt, color: paleta.primario),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                Textos.hayVersionNueva,
                style: tema.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: recargar,
              child: const Text(Textos.botonActualizarAhora),
            ),
          ],
        ),
      ),
    );
  }
}
