/// SIAN — Punto de entrada de la aplicación.
///
/// Estado: iteración 1.1. Arranca Firebase (contra emuladores o contra la
/// nube, según `--dart-define=USE_EMULATOR`), aplica el tema institucional y
/// muestra el estado real del sistema.
///
/// El enrutado por rol, el inicio de sesión y el registro de dispositivo
/// llegan en la iteración 1.2.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/ambiente.dart';
import 'core/plataforma/actualizar_worker.dart';
import 'firebase_options.dart';
import 'infrastructure/firebase/inicializacion.dart';
import 'presentation/shared/apariencia.dart';
import 'presentation/shared/version_app.dart';
import 'presentation/shared/banda_ambiente.dart';
import 'presentation/shared/enrutador.dart';
import 'presentation/shared/pantalla_estado.dart';
import 'presentation/shared/tema.dart';
import 'presentation/shared/textos.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final ResultadoArranque arranque = await inicializarFirebase();

  // Comprueba si hay un service worker nuevo, en cada arranque.
  //
  // Servir el archivo sin caché no basta: alguien tiene que preguntar, y una
  // PWA de iOS que se reabre no siempre lo hace. Como la aplicación sí se
  // renueva en cada arranque, se llegaba a la situación de tener el código
  // nuevo con el worker viejo por debajo — y como es el worker quien muestra
  // las notificaciones, los arreglos parecían no haber llegado.
  //
  // Va después de Firebase, que es quien registra el worker de mensajería, y
  // sin esperarlo: comprobar es útil, pero arrancar es más importante.
  actualizarWorkers();

  // ProviderScope es el contenedor de inyección de dependencias del cliente
  // (documento 02, sección 4). Se monta en la raíz para poder sustituir
  // cualquier implementación por un doble de prueba sin tocar la lógica.
  runApp(
    ProviderScope(
      overrides: [arranqueProvider.overrideWithValue(arranque)],
      child: const AplicacionSian(),
    ),
  );
}

class AplicacionSian extends ConsumerWidget {
  const AplicacionSian({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ResultadoArranque arranque = ref.watch(arranqueProvider);

    return MaterialApp(
      title: Textos.nombreApp,
      theme: TemaSian.claro(),
      darkTheme: TemaSian.oscuro(),
      // Por omisión, el tema del dispositivo; la persona puede fijar otro
      // desde la barra superior (DT-21).
      //
      // Hasta la mejora M-4 esto era `ThemeMode.light` fijo: la paleta oscura
      // no estaba verificada, y medida resultó que ninguno de los colores con
      // significado llegaba a AA sobre fondo oscuro. Ahora cada uno tiene su
      // par oscuro (`PaletaSian`) y una prueba que mide los contrastes.
      themeMode: ref.watch(aparienciaProvider).modo,
      debugShowCheckedModeBanner: false,
      // La banda de ambiente envuelve TODO, incluida la pantalla de ingreso y la
      // de diagnóstico, que no tienen barra donde ponerla (DT-20). En producción
      // `BandaAmbiente` devuelve el hijo tal cual: ni un widget de más.
      builder: (BuildContext context, Widget? hijo) => VigilanteDeVersion(
        child: BandaAmbiente(
          ambiente: ambienteDe(
            DefaultFirebaseOptions.currentPlatform.projectId,
          ),
          hijo: hijo ?? const SizedBox.shrink(),
        ),
      ),
      // Si Firebase no arrancó no hay sesión que resolver, así que se muestra
      // el diagnóstico en vez de un formulario que no podría funcionar.
      home: arranque.correcto ? const Enrutador() : const PantallaEstado(),
    );
  }
}
