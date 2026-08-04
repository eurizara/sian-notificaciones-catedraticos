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

import 'infrastructure/firebase/inicializacion.dart';
import 'presentation/shared/enrutador.dart';
import 'presentation/shared/pantalla_estado.dart';
import 'presentation/shared/tema.dart';
import 'presentation/shared/textos.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final ResultadoArranque arranque = await inicializarFirebase();

  // ProviderScope es el contenedor de inyección de dependencias del cliente
  // (documento 02, sección 3). Se monta en la raíz para poder sustituir
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
      debugShowCheckedModeBanner: false,
      // Si Firebase no arrancó no hay sesión que resolver, así que se muestra
      // el diagnóstico en vez de un formulario que no podría funcionar.
      home: arranque.correcto ? const Enrutador() : const PantallaEstado(),
    );
  }
}
