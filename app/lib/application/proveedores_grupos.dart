/// SIAN — Proveedores de grupos.
///
/// Uno solo para las dos pantallas que los usan: la que los administra y la
/// que los elige como destinatarios. Tener dos fuentes de la misma lista es
/// cómo se llega a que un grupo recién creado no aparezca al redactar.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infrastructure/firebase/repositorio_grupos.dart';
import 'proveedores_sede.dart';

final Provider<RepositorioGrupos> repositorioGruposProvider =
    Provider<RepositorioGrupos>((Ref ref) => RepositorioGrupos());

/// Todos los grupos, activos e inactivos.
/// Los grupos de la sede de trabajo (2.0). Los de otra sede no se ofrecen: el
/// servidor los rechazaría igual (`GRUPO_DE_OTRA_SEDE`).
final gruposProvider = StreamProvider<List<GrupoDetalle>>((Ref ref) {
  final String sede = ref.watch(sedeDeTrabajoProvider);
  return ref
      .watch(repositorioGruposProvider)
      .observarGrupos()
      .map(
        (List<GrupoDetalle> todos) =>
            todos.where((GrupoDetalle g) => g.sedeId == sede).toList(),
      );
});

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

/// Quiénes pueden meterse en un grupo: la gente de la sede de trabajo.
///
/// Por Function, no leyendo `usuarios`: un administrador académico no tiene
/// permiso sobre el padrón, y administrar grupos no debería dárselo.
///
/// Mira la sede de trabajo (2.0.7): sin eso, la lista se pedía una vez y al
/// cambiar de sede seguía ofreciendo la gente de la anterior — en Villa Nueva
/// no aparecía nadie de Villa Nueva.
final elegiblesProvider = FutureProvider<List<Elegible>>((Ref ref) {
  ref.watch(sedeDeTrabajoProvider);
  return ref.watch(repositorioGruposProvider).elegibles();
});
