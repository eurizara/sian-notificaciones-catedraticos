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

import 'core/plataforma/actualizar_worker.dart';
import 'infrastructure/firebase/inicializacion.dart';
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
      // Tema claro fijo, sin seguir la preferencia del sistema.
      //
      // El escudo institucional tiene fondo blanco y un anillo rojo que sobre
      // superficies oscuras pierde definición, y el azul #1C72A5 se aclara
      // tanto en modo oscuro que deja de ser el color de la universidad. Hasta
      // tener una paleta oscura verificada contra WCAG 2.1 AA (RNF-13), es más
      // honesto servir siempre el tema que sí está comprobado.
      //
      // `darkTheme` queda declarado a propósito: reactivarlo es cambiar esta
      // línea por `ThemeMode.system`.
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      // Si Firebase no arrancó no hay sesión que resolver, así que se muestra
      // el diagnóstico en vez de un formulario que no podría funcionar.
      home: arranque.correcto ? const Enrutador() : const PantallaEstado(),
    );
  }
}
