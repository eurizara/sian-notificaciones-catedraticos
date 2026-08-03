/// Prueba de widget de la pantalla de estado.
///
/// Documento 02, sección 8: las pantallas críticas se prueban con
/// `flutter_test` en la integración continua.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/presentation/shared/pantalla_estado.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

void main() {
  Widget envolver(Widget hijo) =>
      MaterialApp(theme: TemaSian.claro(), home: hijo);

  testWidgets('muestra la identidad del sistema', (WidgetTester tester) async {
    await tester.pumpWidget(envolver(const PantallaEstado()));

    expect(find.text(Textos.nombreApp), findsOneWidget);
    expect(find.text(Textos.nombreCompleto), findsOneWidget);
  });

  testWidgets('enumera las piezas del sistema con su estado', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(envolver(const PantallaEstado()));

    // Lo ya construido en la iteración 1.1, visible sin desplazar.
    expect(find.text(Textos.cimientosListos), findsOneWidget);
    expect(find.text(Textos.flutterListo), findsOneWidget);
    expect(find.text(Textos.autenticacionPendiente), findsOneWidget);

    // Lo que todavía no existe, dicho sin disimulo. Queda bajo el pliegue en
    // la ventana de prueba, y `ListView` construye de forma perezosa: hay que
    // desplazar de verdad, como haría el usuario.
    for (final String pendiente in <String>[
      Textos.notificacionesPendiente,
      Textos.programacionPendiente,
    ]) {
      await tester.scrollUntilVisible(
        find.text(pendiente),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(pendiente), findsOneWidget);
    }
  });

  testWidgets('no promete autenticación como lista', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(envolver(const PantallaEstado()));

    final Finder filaAuth = find.ancestor(
      of: find.text(Textos.autenticacionPendiente),
      matching: find.byType(ListTile),
    );
    expect(filaAuth, findsOneWidget);
    expect(
      find.descendant(of: filaAuth, matching: find.text(Textos.pendiente)),
      findsOneWidget,
    );
  });
}
