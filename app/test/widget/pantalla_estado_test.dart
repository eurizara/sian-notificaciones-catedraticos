/// Prueba de widget de la pantalla de estado.
///
/// Documento 02, sección 8: las pantallas críticas se prueban con
/// `flutter_test` en la integración continua.
///
/// Ninguna de estas pruebas toca la red ni levanta un emulador: el resultado
/// del arranque de Firebase entra por el contenedor de inyección, que es
/// exactamente para lo que está puesto (documento 02, sección 3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/infrastructure/firebase/inicializacion.dart';
import 'package:sian/presentation/shared/pantalla_estado.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

void main() {
  Widget envolver({
    ResultadoArranque arranque = const ResultadoArranque(
      conexion: ConexionFirebase.emuladores,
    ),
  }) {
    return ProviderScope(
      overrides: [arranqueProvider.overrideWithValue(arranque)],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: const PantallaEstado(),
      ),
    );
  }

  /// Encuentra la fila de una pieza por su nombre.
  Finder filaDe(String nombre) => find.ancestor(
    of: find.text(nombre),
    matching: find.byType(ListTile),
  );

  testWidgets('muestra la identidad del sistema', (WidgetTester tester) async {
    await tester.pumpWidget(envolver());

    expect(find.text(Textos.nombreApp), findsOneWidget);
    expect(find.text(Textos.nombreCompleto), findsOneWidget);
  });

  testWidgets('enumera las piezas del sistema con su estado', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(envolver());

    // Lo ya construido, visible sin desplazar.
    expect(find.text(Textos.cimientosListos), findsOneWidget);
    expect(find.text(Textos.flutterListo), findsOneWidget);
    expect(find.text(Textos.autenticacionPendiente), findsOneWidget);

    // Lo que todavía no existe queda bajo el pliegue en la ventana de prueba,
    // y `ListView` construye de forma perezosa: hay que desplazar de verdad,
    // como haría el usuario.
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
    await tester.pumpWidget(envolver());

    final Finder fila = filaDe(Textos.autenticacionPendiente);
    expect(fila, findsOneWidget);
    expect(
      find.descendant(of: fila, matching: find.text(Textos.pendiente)),
      findsOneWidget,
    );
  });

  group('estado de Firebase', () {
    testWidgets('conectado a los emuladores lo dice, y advierte del push', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        envolver(
          arranque: const ResultadoArranque(
            conexion: ConexionFirebase.emuladores,
          ),
        ),
      );

      expect(find.text(Textos.firebaseDetalleEmulador), findsOneWidget);
      expect(
        find.descendant(
          of: filaDe(Textos.firebasePendiente),
          matching: find.text(Textos.listo),
        ),
        findsOneWidget,
      );
    });

    testWidgets('conectado a la nube lo distingue del emulador', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        envolver(
          arranque: const ResultadoArranque(conexion: ConexionFirebase.nube),
        ),
      );

      expect(find.text(Textos.firebaseDetalleNube), findsOneWidget);
      expect(find.text(Textos.firebaseDetalleEmulador), findsNothing);
    });

    testWidgets('un arranque fallido explica el motivo en pantalla', (
      WidgetTester tester,
    ) async {
      // Una pantalla en blanco no le dice nada a nadie: si Firebase no
      // arranca, el usuario tiene que poder leer por qué.
      const String motivo = 'Firebase rechazó el arranque: app/invalid-api-key';

      await tester.pumpWidget(
        envolver(
          arranque: const ResultadoArranque(
            conexion: ConexionFirebase.fallida,
            detalle: motivo,
          ),
        ),
      );

      expect(find.text(motivo), findsOneWidget);
      expect(
        find.descendant(
          of: filaDe(Textos.firebasePendiente),
          matching: find.text(Textos.pendiente),
        ),
        findsOneWidget,
      );
    });
  });
}
