/// SIAN — Proveedores de programación y confirmación.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sesion.dart';
import '../infrastructure/firebase/repositorio_programacion.dart';
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
  // Con el rol en la sede de trabajo (2.0.13): quien coordina en una sede y
  // emite en otra ve todos los avisos solo donde coordina.
  final UsuarioSesion? usuario = ref.watch(usuarioEnSedeProvider);

  final String? soloDe = usuario != null && !usuario.rol.veMensajesDeTodos
      ? usuario.uid
      : null;

  // Solo los de la sede de trabajo (2.0). Desde la 2.0.12 la sede va en la
  // consulta; el filtro de aquí queda como segunda defensa.
  final String sede = ref.watch(sedeDeTrabajoProvider);
  return ref
      .watch(repositorioProgramacionProvider)
      .observarProgramados(soloDe: soloDe, sede: sede)
      .map(
        (List<MensajeProgramado> todos) => todos
            .where((MensajeProgramado m) => m.sedeId == sede)
            .toList(),
      );
});
