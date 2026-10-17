/// Demostración 3 (CI/CD): un componente pequeño de la interfaz.
library;

import 'package:flutter/material.dart';

/// Dice cuántos avisos faltan por leer.
class ContadorAvisos extends StatelessWidget {
  /// Crea el contador para [cantidad] avisos sin leer.
  const ContadorAvisos({required this.cantidad, super.key});

  /// Avisos que la persona todavía no ha leído.
  final int cantidad;

  @override
  Widget build(BuildContext context) {
    return Text('$cantidad avisos sin leer');
  }
}
