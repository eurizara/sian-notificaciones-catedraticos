/// SIAN — Proveedores de las respuestas a un aviso (DT-27).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sesion.dart';
import '../infrastructure/firebase/repositorio_respuestas.dart';
import 'proveedores_sesion.dart';

final Provider<RepositorioRespuestas> repositorioRespuestasProvider =
    Provider<RepositorioRespuestas>((Ref ref) => RepositorioRespuestas());

/// Las conversaciones de los avisos de quien tiene la sesión, por aviso.
///
/// Vacío para quien no emite: la consulta filtra por el emisor, y un
/// catedrático no tiene avisos propios de los que recibir respuestas.
final avisosConRespuestasProvider = StreamProvider<List<AvisoConRespuestas>>((
  Ref ref,
) {
  final Sesion sesion = ref.watch(sesionActualProvider);
  if (sesion is! SesionActiva || !sesion.usuario.rol.esEmisor) {
    return Stream<List<AvisoConRespuestas>>.value(const <AvisoConRespuestas>[]);
  }
  return ref
      .watch(repositorioRespuestasProvider)
      .observarHilosDelEmisor(sesion.usuario.uid)
      .map(agruparPorAviso);
});

/// El número junto a la sección: respuestas que el emisor no ha leído.
///
/// Mientras carga, o si la consulta falla, cero. Un número inventado junto a
/// una sección es peor que ninguno: invita a entrar a buscar lo que no hay.
final respuestasSinLeerProvider = Provider<int>((Ref ref) {
  final List<AvisoConRespuestas> avisos =
      ref.watch(avisosConRespuestasProvider).value ??
      const <AvisoConRespuestas>[];
  return avisos.fold(0, (int t, AvisoConRespuestas a) => t + a.sinLeer);
});
