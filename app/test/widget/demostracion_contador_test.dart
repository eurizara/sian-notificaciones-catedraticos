/// Demostración 3 · prueba de INTERFAZ (widget).
///
/// Comprueba lo que la persona ve en pantalla: con un solo aviso pendiente
/// el texto va en singular.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../demostraciones/contador_avisos.dart';

Future<void> _mostrar(WidgetTester tester, int cantidad) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ContadorAvisos(cantidad: cantidad)),
    ),
  );
}

void main() {
  testWidgets('con varios avisos el texto va en plural', (tester) async {
    await _mostrar(tester, 3);
    expect(find.text('3 avisos sin leer'), findsOneWidget);
  });

  testWidgets('con un solo aviso el texto va en singular', (tester) async {
    await _mostrar(tester, 1);
    expect(find.text('1 aviso sin leer'), findsOneWidget);
  });
}
