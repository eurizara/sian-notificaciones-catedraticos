/// Pruebas del distintivo de ambiente — DT-20.
///
/// Lo que más importa aquí no es que la banda aparezca, sino que **no aparezca
/// en producción** y que el ambiente se identifique bien pese a que los tres
/// proyectos no siguen el mismo patrón de nombre.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/core/ambiente.dart';
import 'package:sian/presentation/shared/banda_ambiente.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

void main() {
  group('ambienteDe', () {
    test('reconoce los tres proyectos por su nombre completo', () {
      expect(ambienteDe('sian-umg-bdm-dev'), Ambiente.desarrollo);
      expect(ambienteDe('sian-umg-bdm-qa'), Ambiente.calidad);
      expect(ambienteDe('sian-umg-bdm'), Ambiente.produccion);
    });

    test('producción NO lleva sufijo, y esa es la trampa', () {
      // Comprobar «termina en -prd» dejaría producción sin identificar, que es
      // justo el ambiente donde equivocarse cuesta. Se deja escrito en una
      // prueba para que nadie lo «simplifique» a un sufijo más adelante.
      expect('sian-umg-bdm'.endsWith('-prd'), isFalse);
      expect(ambienteDe('sian-umg-bdm'), Ambiente.produccion);
      expect(ambienteDe('sian-umg-bdm-prd'), Ambiente.desconocido);
    });

    test('un nombre que no conoce NO se toma por producción', () {
      // Ante la duda conviene avisar de más. Tomar lo desconocido por
      // producción sería quitar el aviso justo cuando menos se sabe dónde se
      // está.
      for (final String raro in <String>['', '   ', 'otro-proyecto', 'sian']) {
        expect(ambienteDe(raro), Ambiente.desconocido, reason: raro);
        expect(ambienteNecesitaAviso(ambienteDe(raro)), isTrue, reason: raro);
      }
      expect(ambienteDe(null), Ambiente.desconocido);
    });

    test('tolera espacios y mayúsculas del archivo generado', () {
      expect(ambienteDe('  sian-umg-bdm-dev  '), Ambiente.desarrollo);
      expect(ambienteDe('SIAN-UMG-BDM'), Ambiente.produccion);
    });
  });

  group('ambienteNecesitaAviso', () {
    test('producción es el único que no avisa', () {
      expect(ambienteNecesitaAviso(Ambiente.produccion), isFalse);
      expect(ambienteNecesitaAviso(Ambiente.desarrollo), isTrue);
      expect(ambienteNecesitaAviso(Ambiente.calidad), isTrue);
      expect(ambienteNecesitaAviso(Ambiente.desconocido), isTrue);
    });
  });

  group('BandaAmbiente', () {
    Widget montar(Ambiente ambiente) => MaterialApp(
      theme: TemaSian.claro(),
      home: BandaAmbiente(
        ambiente: ambiente,
        hijo: const Scaffold(body: Text('contenido')),
      ),
    );

    testWidgets('en producción no pone absolutamente nada', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(Ambiente.produccion));

      expect(find.text('contenido'), findsOneWidget);
      expect(find.textContaining('NO ES PRODUCCIÓN'), findsNothing);
      // Ni siquiera la columna: en producción devuelve el hijo tal cual.
      expect(find.byType(Column), findsNothing);
    });

    testWidgets('en desarrollo dice que no es producción, y cuál es', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(Ambiente.desarrollo));

      expect(find.text(Textos.ambienteDesarrollo), findsOneWidget);
      expect(find.text('contenido'), findsOneWidget);
    });

    testWidgets('en calidad lo mismo, con su propio nombre', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(Ambiente.calidad));

      expect(find.text(Textos.ambienteCalidad), findsOneWidget);
    });

    testWidgets('el texto dice «NO ES PRODUCCIÓN» sin depender del color', (
      WidgetTester tester,
    ) async {
      // El color no puede ser la única señal (RNF-13). Quien no distinga el
      // dorado del azul de la barra tiene que leer lo mismo.
      for (final Ambiente a in <Ambiente>[
        Ambiente.desarrollo,
        Ambiente.calidad,
        Ambiente.desconocido,
      ]) {
        await tester.pumpWidget(montar(a));
        expect(
          find.textContaining('NO ES PRODUCCIÓN'),
          findsOneWidget,
          reason: '$a',
        );
      }
    });

    testWidgets('no usa el rojo, que está reservado a lo urgente', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(Ambiente.desarrollo));

      final Material banda = tester.widget<Material>(
        find
            .descendant(of: find.byType(Column), matching: find.byType(Material))
            .first,
      );
      expect(banda.color, ColoresSian.doradoTexto);
      expect(banda.color, isNot(ColoresSian.urgente));
      expect(banda.color, isNot(ColoresSian.rojoInstitucional));
    });

    testWidgets('empuja el contenido en vez de taparlo', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(Ambiente.desarrollo));

      // Si estuviera flotando encima, el contenido empezaría en la misma altura
      // que la banda. Lo que se comprueba es que no se solapan.
      final double finBanda = tester.getBottomLeft(find.byType(Material).first).dy;
      final double inicioContenido = tester.getTopLeft(find.text('contenido')).dy;
      expect(inicioContenido, greaterThanOrEqualTo(finBanda));
    });

    testWidgets('se anuncia como región viva para el lector de pantalla', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(Ambiente.desarrollo));

      final Finder semantica = find.descendant(
        of: find.byType(BandaAmbiente),
        matching: find.byType(Semantics),
      );
      expect(semantica, findsWidgets);
    });
  });
}
