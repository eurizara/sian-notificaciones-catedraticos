/// SIAN — Punto de entrada de la aplicación.
///
/// Estado: iteración 1.1. La aplicación arranca, aplica el tema institucional
/// y muestra el estado real del sistema. Todavía **no** inicializa Firebase:
/// `lib/firebase_options.dart` lo genera `flutterfire configure`, y eso ocurre
/// cuando existe el proyecto `sian-umg-bdm-dev` (documento 06, etapa C.5).
///
/// El enrutado por rol, el inicio de sesión y el registro de dispositivo
/// llegan en la iteración 1.2.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/shared/pantalla_estado.dart';
import 'presentation/shared/tema.dart';
import 'presentation/shared/textos.dart';

void main() {
  // ProviderScope es el contenedor de inyección de dependencias del cliente
  // (documento 02, sección 3). Se monta en la raíz para que cualquier capa
  // pueda sustituirse por un doble de prueba sin tocar la lógica.
  runApp(const ProviderScope(child: AplicacionSian()));
}

class AplicacionSian extends StatelessWidget {
  const AplicacionSian({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Textos.nombreApp,
      theme: TemaSian.claro(),
      darkTheme: TemaSian.oscuro(),
      debugShowCheckedModeBanner: false,
      home: const PantallaEstado(),
    );
  }
}
