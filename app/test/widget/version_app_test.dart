/// La versión de la aplicación, a la vista.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Se pide en voz alta, así que tiene que ser legible y tiene que ser cierta.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Para saber qué código tenía alguien delante había que mirar el `commit` de
/// `version.json`: cuarenta caracteres que nadie va a dictar por teléfono.
/// «1.5.0» sí. Lo que se fija aquí es que el número no se contradiga entre los
/// sitios donde vive, y que el aviso de «hay una versión nueva» no aparezca
/// cuando no se sabe — un aviso que sale sin motivo enseña a ignorarlo.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/core/version.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';
import 'package:sian/presentation/shared/version_app.dart';

void main() {
  group('el número', () {
    test('tiene la forma MAYOR.MENOR.PARCHE', () {
      expect(versionSian, matches(RegExp(r'^\d+\.\d+\.\d+$')));
    });

    test('pubspec.yaml dice lo mismo', () {
      // Dos sitios con la misma verdad se separan solos. `pubspec` es el que
      // acaba en el paquete compilado, y `version.dart` el que se enseña: si
      // discrepan, lo que se ve en pantalla deja de describir lo que corre.
      final String pubspec = File('pubspec.yaml').readAsStringSync();
      final RegExpMatch? linea = RegExp(
        r'^version:\s*([\d.]+)\+',
        multiLine: true,
      ).firstMatch(pubspec);
      expect(linea, isNotNull, reason: 'pubspec.yaml sin línea de versión');
      expect(linea!.group(1), versionSian);
    });

    test('el sellado del despliegue lo lee de un solo sitio', () {
      // Si el guion dejara de leer `version.dart`, `version.json` publicaría
      // una versión distinta de la que la aplicación cree tener, y el aviso de
      // actualización saldría para siempre.
      final String guion = File(
        '../scripts/sellar-version.sh',
      ).readAsStringSync();
      expect(guion, contains('app/lib/core/version.dart'));
      expect(guion, contains('"version": "\$VERSION"'));
    });
  });

  group('el aviso de versión nueva', () {
    Widget montar(String? publicada, {VoidCallback? recargar}) => ProviderScope(
      overrides: [
        versionPublicadaProvider.overrideWith((Ref ref) async => publicada),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: Scaffold(body: AvisoDeVersionNueva(recargar: recargar ?? () {})),
      ),
    );

    testWidgets('no aparece mientras no se sabe qué hay publicado', (
      WidgetTester tester,
    ) async {
      // La consulta tarda. Un aviso que sale antes de tener la respuesta
      // enseña a ignorar el aviso.
      await tester.pumpWidget(montar(null));
      await tester.pump();
      expect(find.text(Textos.botonActualizarAhora), findsNothing);
    });

    testWidgets('no aparece si lo publicado es lo que ya se tiene', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(versionSian));
      await tester.pumpAndSettle();
      expect(find.text(Textos.botonActualizarAhora), findsNothing);
    });

    testWidgets('aparece cuando hay otra versión publicada, y recarga', (
      WidgetTester tester,
    ) async {
      int recargas = 0;
      await tester.pumpWidget(montar('9.9.9', recargar: () => recargas += 1));
      await tester.pumpAndSettle();

      expect(find.text(Textos.hayVersionNueva), findsOneWidget);
      await tester.tap(find.text(Textos.botonActualizarAhora));
      await tester.pump();
      expect(recargas, 1);
    });

    testWidgets('dice que no se pierde nada: actualizar da miedo', (
      WidgetTester tester,
    ) async {
      expect(Textos.hayVersionNueva, contains('no pierdes nada'));
    });
  });

  group('el sello del pie', () {
    Widget montar(String? publicada) => ProviderScope(
      overrides: [
        versionPublicadaProvider.overrideWith((Ref ref) async => publicada),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: const Scaffold(body: SelloDeVersion()),
      ),
    );

    testWidgets('enseña la versión que se está usando', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(versionSian));
      await tester.pumpAndSettle();
      expect(find.text(Textos.version(versionSian)), findsOneWidget);
    });

    testWidgets('y avisa en la misma línea si hay una más reciente', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar('9.9.9'));
      await tester.pumpAndSettle();
      expect(
        find.text(Textos.versionConActualizacion(versionSian)),
        findsOneWidget,
      );
    });
  });
}
