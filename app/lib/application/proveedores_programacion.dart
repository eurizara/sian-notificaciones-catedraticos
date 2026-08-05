/// SIAN — Proveedores de programación y confirmación.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infrastructure/firebase/repositorio_programacion.dart';

final Provider<RepositorioProgramacion> repositorioProgramacionProvider =
    Provider<RepositorioProgramacion>((Ref ref) => RepositorioProgramacion());

final programadosProvider = StreamProvider<List<MensajeProgramado>>(
  (Ref ref) => ref.watch(repositorioProgramacionProvider).observarProgramados(),
);
