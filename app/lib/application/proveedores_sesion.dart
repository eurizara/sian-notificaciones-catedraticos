/// SIAN — Proveedores de sesión.
///
/// Es el cableado entre la infraestructura y la interfaz. Todo pasa por aquí,
/// de modo que una prueba de widget puede sustituir el repositorio por un doble
/// sin tocar ninguna pantalla (documento 02, sección 3).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositorios.dart';
import '../domain/sesion.dart';
import '../infrastructure/firebase/repositorio_sesion.dart';

/// Repositorio de sesión. Se sobrescribe en las pruebas.
final Provider<RepositorioSesion> repositorioSesionProvider =
    Provider<RepositorioSesion>((Ref ref) => RepositorioSesionFirebase());

/// Estado de sesión observado en tiempo real.
final StreamProvider<Sesion> sesionProvider = StreamProvider<Sesion>(
  (Ref ref) => ref.watch(repositorioSesionProvider).observar(),
);

/// Estado de sesión ya resuelto, con «cargando» como valor de partida.
///
/// Evita que cada pantalla tenga que desenvolver un `AsyncValue` para saber
/// algo tan simple como si hay alguien dentro.
final Provider<Sesion> sesionActualProvider = Provider<Sesion>((Ref ref) {
  return ref
      .watch(sesionProvider)
      .maybeWhen(
        data: (Sesion sesion) => sesion,
        orElse: () => const SesionCargando(),
      );
});
