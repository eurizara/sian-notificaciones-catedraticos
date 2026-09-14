/// Barra superior — recargar y cerrar sesión.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Dos botones vecinos con consecuencias muy distintas.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Recargar se deshace pulsándolo otra vez; cerrar sesión obliga a volver a
/// entrar. Por eso lo que aquí se comprueba no es que existan, sino que están
/// en el orden que evita confundirlos y que cada uno hace lo suyo y solo lo
/// suyo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/presentation/shared/apariencia.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/core/plataforma/almacen_local.dart';
import 'package:sian/presentation/shared/barra_sesion.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

void main() {
  late RepositorioSesionFalso sesion;
  int recargas = 0;

  setUp(() {
    sesion = RepositorioSesionFalso();
    recargas = 0;
  });
  tearDown(() => sesion.cerrar());

  Widget montar({double ancho = 400}) => ProviderScope(
    overrides: [repositorioSesionProvider.overrideWithValue(sesion)],
    child: MaterialApp(
      theme: TemaSian.claro(),
      home: MediaQuery(
        data: MediaQueryData(size: Size(ancho, 800)),
        child: Scaffold(
          appBar: BarraSesion(
            usuario: usuarioDePrueba(rol: Rol.catedratico),
            titulo: 'Mis mensajes',
            recargar: () => recargas += 1,
          ),
        ),
      ),
    ),
  );

  testWidgets('recargar recarga, y NO cierra la sesión', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(montar());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();

    expect(recargas, 1);
    expect(sesion.vecesQueSalio, 0, reason: 'la sesión sigue abierta');
  });

  testWidgets('cerrar sesión cierra, y NO recarga', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(montar(ancho: 800));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pump();

    expect(sesion.vecesQueSalio, 1);
    expect(recargas, 0);
  });

  testWidgets('cerrar sesión se queda en el borde, recargar a su izquierda', (
    WidgetTester tester,
  ) async {
    // Quien busca «salir» sin mirar lo busca en la esquina, donde siempre
    // estuvo. Meter el botón nuevo en ese sitio haría que pulse lo que no
    // quería, y eso lo descubre después de haber salido.
    await tester.pumpWidget(montar(ancho: 800));
    await tester.pump();

    final double xRecargar = tester.getCenter(find.byIcon(Icons.refresh)).dx;
    final double xSalir = tester.getCenter(find.byIcon(Icons.logout)).dx;

    expect(xRecargar, lessThan(xSalir));
  });

  group('en un teléfono', () {
    testWidgets('tres botones y no cuatro: el título no se corta', (
      WidgetTester tester,
    ) async {
      // Con cuatro, el título quedaba en «Mis mensa…» (11/09/2026).
      await tester.pumpWidget(montar(ancho: 390));
      await tester.pump();

      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byType(MenuCuenta), findsOneWidget);
      expect(find.byType(SelectorApariencia), findsNothing);
      expect(find.byIcon(Icons.logout), findsNothing);
    });

    testWidgets('la cuenta va en el borde, donde estaba salir', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(ancho: 390));
      await tester.pump();

      final double xRecargar = tester.getCenter(find.byIcon(Icons.refresh)).dx;
      final double xCuenta = tester.getCenter(find.byType(MenuCuenta)).dx;
      expect(xRecargar, lessThan(xCuenta));
    });

    testWidgets('el botón de la cuenta dice quién está dentro', (
      WidgetTester tester,
    ) async {
      // En pantalla estrecha el nombre no cabe en la barra.
      await tester.pumpWidget(montar(ancho: 390));
      await tester.pump();

      final UsuarioSesion u = usuarioDePrueba(rol: Rol.catedratico);
      expect(
        find.byTooltip(Textos.botonCuenta(u.nombre, u.rol.etiqueta)),
        findsOneWidget,
      );
    });

    testWidgets('cerrar sesión pide dos toques, y cierra', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(ancho: 390));
      await tester.pump();

      await tester.tap(find.byType(MenuCuenta));
      await tester.pumpAndSettle();
      expect(sesion.vecesQueSalio, 0, reason: 'abrir el menú no sale');

      await tester.tap(find.text(Textos.botonSalir));
      await tester.pumpAndSettle();
      expect(sesion.vecesQueSalio, 1);
      expect(recargas, 0);
    });

    testWidgets('la apariencia se elige desde la cuenta', (
      WidgetTester tester,
    ) async {
      almacenLocalDePrueba.clear();
      await tester.pumpWidget(montar(ancho: 390));
      await tester.pump();

      await tester.tap(find.byType(MenuCuenta));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Textos.temaOscuro));
      await tester.pumpAndSettle();

      expect(leerLocal(Apariencia.clave), 'oscuro');
      expect(sesion.vecesQueSalio, 0);
    });

    testWidgets('recargar sigue a un toque', (WidgetTester tester) async {
      await tester.pumpWidget(montar(ancho: 360));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      expect(recargas, 1);
      expect(
        find.text(Textos.botonRecargar),
        findsNothing,
        reason: 'es tooltip',
      );
    });
  });
}
