/// SIAN — Proveedores de programación y confirmación.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sesion.dart';
import '../infrastructure/firebase/repositorio_programacion.dart';
import 'proveedores_sesion.dart';
import 'proveedores_sede.dart';

final Provider<RepositorioProgramacion> repositorioProgramacionProvider =
    Provider<RepositorioProgramacion>((Ref ref) => RepositorioProgramacion());

/// Lo programado y lo enviado, con el alcance que permita el rol.
///
/// El coordinador y el auditor lo ven todo; el administrador académico, solo
/// lo suyo. La restricción viaja en la CONSULTA y no en un filtro posterior,
/// porque Firestore no evalúa las reglas fila por fila en una lista: una
/// consulta que pida más de lo permitido se rechaza entera.
final programadosProvider = StreamProvider<List<MensajeProgramado>>((Ref ref) {
  final Sesion sesion = ref.watch(sesionActualProvider);

  final String? soloDe =
      sesion is SesionActiva && !sesion.usuario.rol.veMensajesDeTodos
      ? sesion.usuario.uid
      : null;

  // Solo los de la sede de trabajo (2.0). Hasta que las reglas exijan la sede
  // (2.0-f) el filtro es aquí; después irá en la consulta.
  final String sede = ref.watch(sedeDeTrabajoProvider);
  return ref
      .watch(repositorioProgramacionProvider)
      .observarProgramados(soloDe: soloDe)
      .map(
        (List<MensajeProgramado> todos) => todos
            .where((MensajeProgramado m) => m.sedeId == sede)
            .toList(),
      );
});
