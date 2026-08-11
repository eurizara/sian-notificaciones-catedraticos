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
    await tester.pumpWidget(montar());
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
    await tester.pumpWidget(montar());
    await tester.pump();

    final double xRecargar = tester.getCenter(find.byIcon(Icons.refresh)).dx;
    final double xSalir = tester.getCenter(find.byIcon(Icons.logout)).dx;

    expect(xRecargar, lessThan(xSalir));
  });

  testWidgets('en pantalla estrecha siguen estando los dos', (
    WidgetTester tester,
  ) async {
    // Es donde más falta hacen y donde menos sitio hay: el bloque de identidad
    // desaparece, pero las acciones no.
    await tester.pumpWidget(montar(ancho: 360));
    await tester.pump();

    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(find.text(Textos.botonRecargar), findsNothing, reason: 'es tooltip');
  });
}
