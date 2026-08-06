/// SIAN — Proveedores de grupos.
///
/// Uno solo para las dos pantallas que los usan: la que los administra y la
/// que los elige como destinatarios. Tener dos fuentes de la misma lista es
/// cómo se llega a que un grupo recién creado no aparezca al redactar.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infrastructure/firebase/repositorio_grupos.dart';

final Provider<RepositorioGrupos> repositorioGruposProvider =
    Provider<RepositorioGrupos>((Ref ref) => RepositorioGrupos());

/// Todos los grupos, activos e inactivos.
final gruposProvider = StreamProvider<List<GrupoDetalle>>(
  (Ref ref) => ref.watch(repositorioGruposProvider).observarGrupos(),
);

/// Solo los elegibles como destinatarios.
///
/// Un grupo desactivado sigue existiendo para el historial, pero no puede
/// aparecer al redactar: enviar a un grupo inactivo es un error que el
/// servidor rechaza, y ofrecerlo sería tender la trampa.
final gruposActivosProvider = Provider<AsyncValue<List<GrupoDetalle>>>((
  Ref ref,
) {
  return ref
      .watch(gruposProvider)
      .whenData(
        (List<GrupoDetalle> todos) =>
            todos.where((GrupoDetalle g) => g.activo).toList(),
      );
});

/// Quiénes pueden meterse en un grupo.
///
/// Por Function, no leyendo `usuarios`: un administrador académico no tiene
/// permiso sobre el padrón, y administrar grupos no debería dárselo.
final elegiblesProvider = FutureProvider<List<Elegible>>(
  (Ref ref) => ref.watch(repositorioGruposProvider).elegibles(),
);
