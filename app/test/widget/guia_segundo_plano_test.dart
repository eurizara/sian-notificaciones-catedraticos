/// La guía de «Permitir uso en segundo plano» en Android.
///
/// El 13 de septiembre de 2026, con ese ajuste apagado, un Android con todo lo
/// demás concedido retenía los avisos y los soltaba tarde y de golpe. Con el
/// ajuste encendido llegaron en segundos. Desde la web no se puede cambiar ni
/// consultar, así que se explica — a quien le aplica, y una sola vez.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_dispositivos.dart';
import 'package:sian/core/navegador.dart';
import 'package:sian/core/plataforma/almacen_local.dart';
import 'package:sian/infrastructure/firebase/repositorio_dispositivos.dart';
import 'package:sian/presentation/docente/guia_segundo_plano.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

EntornoNavegador _entorno(PlataformaWeb plataforma, {bool instalada = true}) =>
    EntornoNavegador(
      plataforma: plataforma,
      instalada: instalada,
      navegador: 'Chrome',
      soportaNotificaciones: true,
      versionIos: plataforma == PlataformaWeb.ios ? 17 : null,
    );

void main() {
  setUp(almacenLocalDePrueba.clear);

  group('a quién se le enseña', () {
    test('Android, instalada y con permiso: sí', () {
      expect(
        debeMostrarGuiaSegundoPlano(
          entorno: _entorno(PlataformaWeb.android),
          permiso: EstadoPermiso.concedido,
          yaVista: false,
        ),
        isTrue,
      );
    });

    test('iPhone y computadora: no, allí no existe ese ajuste', () {
      for (final PlataformaWeb p in <PlataformaWeb>[
        PlataformaWeb.ios,
        PlataformaWeb.escritorio,
      ]) {
        expect(
          debeMostrarGuiaSegundoPlano(
            entorno: _entorno(p),
            permiso: EstadoPermiso.concedido,
            yaVista: false,
          ),
          isFalse,
          reason: '$p',
        );
      }
    });

    test('Android sin instalar: no, no hay aplicación a la que despertar', () {
      expect(
        debeMostrarGuiaSegundoPlano(
          entorno: _entorno(PlataformaWeb.android, instalada: false),
          permiso: EstadoPermiso.concedido,
          yaVista: false,
        ),
        isFalse,
      );
    });

    test('sin permiso: no, lo primero es activar las notificaciones', () {
      for (final EstadoPermiso p in <EstadoPermiso>[
        EstadoPermiso.pendiente,
        EstadoPermiso.denegado,
        EstadoPermiso.noSoportado,
      ]) {
        expect(
          debeMostrarGuiaSegundoPlano(
            entorno: _entorno(PlataformaWeb.android),
            permiso: p,
            yaVista: false,
          ),
          isFalse,
          reason: '$p',
        );
      }
    });

    test('ya vista: no se repite', () {
      expect(
        debeMostrarGuiaSegundoPlano(
          entorno: _entorno(PlataformaWeb.android),
          permiso: EstadoPermiso.concedido,
          yaVista: true,
        ),
        isFalse,
      );
    });
  });

  group('en pantalla', () {
    Widget montar(EntornoNavegador entorno, EstadoPermiso permiso) =>
        ProviderScope(
          overrides: [
            repositorioDispositivosProvider.overrideWithValue(
              RepositorioDispositivosFalso(entorno: entorno, permiso: permiso),
            ),
          ],
          child: MaterialApp(
            theme: TemaSian.claro(),
            home: const Scaffold(body: GuiaSegundoPlano()),
          ),
        );

    testWidgets('da los tres pasos y advierte de «Anular suscripción»', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(_entorno(PlataformaWeb.android), EstadoPermiso.concedido),
      );
      await tester.pumpAndSettle();

      expect(find.text(Textos.segundoPlanoTitulo), findsOneWidget);
      expect(find.text(Textos.segundoPlanoPaso1), findsOneWidget);
      expect(find.text(Textos.segundoPlanoPaso2), findsOneWidget);
      expect(find.text(Textos.segundoPlanoPaso3), findsOneWidget);
      expect(find.text(Textos.segundoPlanoNoAnular), findsOneWidget);
      // Las dos maneras en que los fabricantes llaman al mismo ajuste.
      expect(Textos.segundoPlanoPaso3, contains('Permitir uso en segundo plano'));
      expect(Textos.segundoPlanoPaso3, contains('Sin restricciones'));
    });

    testWidgets('«Ya lo activé» la retira y no vuelve a salir', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(_entorno(PlataformaWeb.android), EstadoPermiso.concedido),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(Textos.botonSegundoPlanoListo));
      await tester.pumpAndSettle();
      expect(find.text(Textos.segundoPlanoTitulo), findsNothing);
      expect(leerLocal(claveGuiaSegundoPlano), 'vista');

      // Otra apertura de la aplicación en el mismo aparato.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        montar(_entorno(PlataformaWeb.android), EstadoPermiso.concedido),
      );
      await tester.pumpAndSettle();
      expect(find.text(Textos.segundoPlanoTitulo), findsNothing);
    });

    testWidgets('en un iPhone no ocupa sitio', (WidgetTester tester) async {
      await tester.pumpWidget(
        montar(_entorno(PlataformaWeb.ios), EstadoPermiso.concedido),
      );
      await tester.pumpAndSettle();
      expect(find.text(Textos.segundoPlanoTitulo), findsNothing);
    });
  });
}
