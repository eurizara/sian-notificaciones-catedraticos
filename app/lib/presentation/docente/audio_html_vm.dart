/// Sustituto para la máquina virtual: pruebas y herramientas.
///
/// Declara que hay una nota de voz pero no la reproduce. Fuera del navegador
/// no hay elemento `<audio>` que incrustar, y fingir un reproductor haría que
/// una prueba diera por bueno algo que nunca se ejercitó.
library;

import 'package:flutter/material.dart';

import '../shared/textos.dart';

class ReproductorAudio extends StatelessWidget {
  const ReproductorAudio({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text(Textos.detalleNotaDeVoz));
}
