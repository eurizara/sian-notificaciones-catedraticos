/// El manual en la barra superior — DT-28, mejora M-3.
///
/// Lo que se comprueba no es solo que el botón exista, sino lo que lo hace útil
/// y seguro: que abra el manual que le toca a cada rol, que la ruta no lleve el
/// dominio escrito, que avise que se abre en otra pestaña, y que esté en el
/// sitio que no se confunde con salir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/core/ruta_manual.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/presentation/shared/barra_sesion.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

void main() {
  group('rutaDelManual', () {
    test('el catedrático va a su manual, no al índice general', () {
      // Mandarlo al general lo obliga a buscar su parte entre secciones que no
      // le tocan: la ayuda existe y no se usa.
      expect(rutaDelManual(Rol.catedratico), '/manuales/catedratico/');
    });

    test('quien usa el panel va al manual general', () {
      for (final Rol rol in <Rol>[Rol.coordinador, Rol.administradora, Rol.auditor]) {
        expect(rutaDelManual(rol), '/manuales/', reason: '$rol');
      }
    });

    test('la ruta NO lleva dominio: la resuelve el origen', () {
      // Desde desarrollo abre el manual de desarrollo; desde producción, el de
      // producción. La dirección de desarrollo ya quedó escrita una vez en
      // dieciocho sitios de los manuales.
      for (final Rol rol in Rol.values) {
        final String ruta = rutaDelManual(rol);
        expect(ruta.startsWith('/'), isTrue, reason: '$rol');
        expect(ruta, isNot(contains('http')), reason: '$rol');
        expect(ruta, isNot(contains('web.app')), reason: '$rol');
      }
    });
  });

  group('el botón en la barra', () {
    late RepositorioSesionFalso sesion;
    late List<String> abiertos;

    setUp(() {
      sesion = RepositorioSesionFalso();
      abiertos = <String>[];
    });
    tearDown(() => sesion.cerrar());

    Widget montar(Rol rol) => ProviderScope(
      overrides: [repositorioSesionProvider.overrideWithValue(sesion)],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: Scaffold(
          appBar: BarraSesion(
            usuario: usuarioDePrueba(rol: rol),
            titulo: 'Prueba',
            recargar: () {},
            abrirManualDe: abiertos.add,
          ),
        ),
      ),
    );

    testWidgets('abre el manual que le toca al rol', (WidgetTester tester) async {
      await tester.pumpWidget(montar(Rol.catedratico));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.menu_book_outlined));
      await tester.pump();

      expect(abiertos, <String>['/manuales/catedratico/']);
      expect(sesion.vecesQueSalio, 0, reason: 'abrir el manual no cierra nada');
    });

    testWidgets('su nombre accesible avisa que se abre en otra pestaña', (
      WidgetTester tester,
    ) async {
      // WCAG 3.2.5: un cambio de contexto sin anunciar desorienta a quien
      // navega sin ver la pantalla.
      await tester.pumpWidget(montar(Rol.coordinador));
      await tester.pump();

      expect(find.byTooltip(Textos.botonManual), findsOneWidget);
      expect(Textos.botonManual, contains('pestaña nueva'));
    });

    testWidgets('va a la izquierda de recargar, lejos de salir', (
      WidgetTester tester,
    ) async {
      // Cuanto más inocua la acción, más lejos del borde donde está salir.
      await tester.pumpWidget(montar(Rol.coordinador));
      await tester.pump();

      final double manual = tester.getCenter(find.byIcon(Icons.menu_book_outlined)).dx;
      final double recargar = tester.getCenter(find.byIcon(Icons.refresh)).dx;
      final double salir = tester.getCenter(find.byIcon(Icons.logout)).dx;

      expect(manual, lessThan(recargar));
      expect(recargar, lessThan(salir));
    });

    testWidgets('el objetivo táctil tiene el tamaño mínimo', (
      WidgetTester tester,
    ) async {
      // WCAG 2.5.8 pide al menos 24 px; Material usa 48, que es lo que se
      // aprieta con un pulgar en una barra estrecha.
      await tester.pumpWidget(montar(Rol.catedratico));
      await tester.pump();

      final Size tamano = tester.getSize(
        find.ancestor(
          of: find.byIcon(Icons.menu_book_outlined),
          matching: find.byType(IconButton),
        ),
      );
      expect(tamano.width, greaterThanOrEqualTo(48));
      expect(tamano.height, greaterThanOrEqualTo(48));
    });
  });
}
