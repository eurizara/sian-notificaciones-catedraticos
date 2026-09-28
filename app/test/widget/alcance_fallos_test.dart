/// Alcance: cuántos aparatos reportaron fallos en las últimas 24 h (DT-34).
///
/// Sin nombres: el reporte no sabe de quién es el aparato, y así tiene que
/// seguir. Lo que sirve a coordinación es saber que algo está fallando, en qué
/// plataforma y en qué versión, antes de que alguien diga «no me llegó».
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/infrastructure/firebase/repositorio_canal.dart';
import 'package:sian/presentation/admin/seccion_canal.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';
import 'package:sian/presentation/shared/version_app.dart';

Future<void> _montar(WidgetTester tester, FallosDeAparatos fallos) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        revisionDeCanalProvider.overrideWith(
          (Ref ref) async => RevisionDeCanal(
            total: 0,
            catedraticos: 3,
            personas: const <PersonaSinCanal>[],
            fallos: fallos,
          ),
        ),
        versionPublicadaProvider.overrideWith((Ref ref) async => '1.6.10'),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: const Scaffold(body: SeccionCanal()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('se lee lo que manda la función', () {
    final FallosDeAparatos f = FallosDeAparatos.desdeMapa(<Object?, Object?>{
      'aparatos': 2,
      'reportes': 5,
      'porTipo': <Object?>[
        <Object?, Object?>{
          'que': 'worker',
          'aparatos': 2,
          'veces': 4,
          'plataformas': <Object?>['WEB_ANDROID', 'WEB_IOS'],
          'versiones': <Object?>['1.6.9', '1.6.10'],
          'ultimoDetalle': 'sin registro tras 8s',
        },
      ],
    });
    expect(f.aparatos, 2);
    expect(f.reportes, 5);
    expect(f.porTipo.single.que, 'worker');
    expect(f.porTipo.single.plataformas, <String>['WEB_ANDROID', 'WEB_IOS']);
    expect(f.porTipo.single.ultimoDetalle, 'sin registro tras 8s');
  });

  test('sin el campo (una función anterior), ceros', () {
    final FallosDeAparatos f = FallosDeAparatos.desdeMapa(null);
    expect(f.aparatos, 0);
    expect(f.porTipo, isEmpty);
  });

  testWidgets('sin fallos, lo dice en una línea', (WidgetTester tester) async {
    await _montar(tester, FallosDeAparatos.ninguno);
    expect(find.text(Textos.canalFallosTitulo), findsOneWidget);
    expect(find.text(Textos.canalFallosResumen(0)), findsOneWidget);
  });

  testWidgets('con fallos: cuántos aparatos, de qué tipo, dónde y en qué versión', (
    WidgetTester tester,
  ) async {
    await _montar(
      tester,
      const FallosDeAparatos(
        aparatos: 3,
        reportes: 6,
        porTipo: <TipoDeFallosResumido>[
          TipoDeFallosResumido(
            que: 'registro-dispositivo',
            aparatos: 2,
            veces: 5,
            plataformas: <String>['WEB_ANDROID', 'WEB_IOS'],
            versiones: <String>['1.6.9', '1.6.10'],
            ultimoDetalle: 'TimeoutException after 0:00:12',
          ),
          TipoDeFallosResumido(
            que: 'no-controlado',
            aparatos: 1,
            veces: 1,
            plataformas: <String>['WEB_ESCRITORIO'],
            versiones: <String>['1.6.10'],
            ultimoDetalle: '',
          ),
        ],
      ),
    );

    expect(find.text(Textos.canalFallosResumen(3)), findsOneWidget);
    // El detalle por tipo va plegado, como las otras listas de Alcance.
    expect(find.text(Textos.nombreFallo('registro-dispositivo')), findsNothing);
    await tester.tap(find.text(Textos.canalVerFallos(2)));
    await tester.pumpAndSettle();
    expect(find.text(Textos.nombreFallo('registro-dispositivo')), findsOneWidget);
    expect(find.text(Textos.canalFalloCuenta(2, 5)), findsOneWidget);
    expect(find.text('Android, iPhone · 1.6.9, 1.6.10'), findsOneWidget);
    expect(find.text('TimeoutException after 0:00:12'), findsOneWidget);
    expect(find.text(Textos.nombreFallo('no-controlado')), findsOneWidget);
    expect(find.text('Computadora · 1.6.10'), findsOneWidget);
  });

  test('los textos cuentan bien', () {
    expect(Textos.canalFallosResumen(1), contains('1 aparato reportó'));
    expect(Textos.canalFallosResumen(4), contains('4 aparatos reportaron'));
    expect(Textos.canalFalloCuenta(1, 1), '1 aparato · 1 vez');
    expect(Textos.canalFalloCuenta(2, 7), '2 aparatos · 7 veces');
    expect(Textos.nombreFallo('desconocido'), 'desconocido');
  });
}
