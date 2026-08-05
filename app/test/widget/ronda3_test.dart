/// Pruebas de la ronda 3 — RF-AUT-01, RF-USR-09, RES-05, RES-07.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/core/navegador.dart';
import 'package:sian/domain/repositorios.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/presentation/docente/bandeja_docente.dart';
import 'package:sian/presentation/docente/instructivo_ios.dart';
import 'package:sian/presentation/docente/tarjeta_notificaciones.dart';
import 'package:sian/presentation/shared/pantalla_ingreso.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

/// Entorno de navegador a medida, para poder probar cada plataforma.
EntornoNavegador entorno({
  PlataformaWeb plataforma = PlataformaWeb.escritorio,
  bool instalada = false,
  String navegador = 'Chrome',
  bool soporta = true,
  int? versionIos,
}) {
  return EntornoNavegador(
    plataforma: plataforma,
    instalada: instalada,
    navegador: navegador,
    soportaNotificaciones: soporta,
    versionIos: versionIos,
  );
}

void main() {
  group('RF-AUT-01 · entrar con Google', () {
    late RepositorioSesionFalso sesion;

    setUp(() => sesion = RepositorioSesionFalso());
    tearDown(() => sesion.cerrar());

    Widget montar() => ProviderScope(
      overrides: [repositorioSesionProvider.overrideWithValue(sesion)],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: const PantallaIngreso(),
      ),
    );

    testWidgets('el botón aparece antes que el formulario', (
      WidgetTester tester,
    ) async {
      // Google va primero a propósito: es el camino que la institución quiere
      // por omisión y el que no obliga a inventar otra contraseña.
      await tester.pumpWidget(montar());
      await tester.pump();

      final Finder google = find.text(Textos.botonEntrarConGoogle);
      expect(google, findsOneWidget);

      final double yGoogle = tester.getTopLeft(google).dy;
      final double yCorreo = tester
          .getTopLeft(find.widgetWithText(TextFormField, Textos.etiquetaCorreo))
          .dy;
      expect(yGoogle, lessThan(yCorreo));
    });

    testWidgets('pulsarlo delega en el repositorio', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar());
      await tester.pump();

      await tester.tap(find.text(Textos.botonEntrarConGoogle));
      await tester.pumpAndSettle();

      expect(sesion.vecesQueEntroConGoogle, 1);
    });
  });

  group('RES-05 · instructivo de instalación en iOS', () {
    late RepositorioSesionFalso sesion;
    late RepositorioBandejaFalso bandeja;

    setUp(() {
      sesion = RepositorioSesionFalso();
      bandeja = RepositorioBandejaFalso(const <MensajeRecibido>[]);
    });
    tearDown(() => sesion.cerrar());

    Widget montar(EntornoNavegador e) => ProviderScope(
      overrides: [
        repositorioSesionProvider.overrideWithValue(sesion),
        repositorioBandejaProvider.overrideWithValue(bandeja),
        repositorioDispositivosProvider.overrideWithValue(
          RepositorioDispositivosFalso(entorno: e),
        ),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: BandejaDocente(usuario: usuarioDePrueba(rol: Rol.catedratico)),
      ),
    );

    testWidgets('en iPhone sin instalar, aparece ANTES que la bandeja', (
      WidgetTester tester,
    ) async {
      // Un catedrático con iPhone que use SIAN desde una pestaña está
      // incomunicado y no lo sabe. Por eso el instructivo no se esconde en
      // una ayuda: aparece solo (riesgo R-02).
      await tester.pumpWidget(
        montar(entorno(plataforma: PlataformaWeb.ios, navegador: 'Safari')),
      );
      await tester.pump();

      expect(find.byType(InstructivoIos), findsOneWidget);
      expect(find.text(Textos.instalarPorQue), findsOneWidget);
    });

    testWidgets('se puede continuar sin instalar, con su advertencia', (
      WidgetTester tester,
    ) async {
      // Bloquear la aplicación dejaría al catedrático sin poder ni leer sus
      // mensajes, que es peor que dejarlo sin notificaciones.
      await tester.pumpWidget(
        montar(entorno(plataforma: PlataformaWeb.ios, navegador: 'Safari')),
      );
      await tester.pump();

      expect(find.text(Textos.avisoSeguirSinInstalar), findsOneWidget);

      await tester.ensureVisible(find.text(Textos.botonSeguirSinInstalar));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Textos.botonSeguirSinInstalar));
      await tester.pumpAndSettle();

      expect(find.byType(InstructivoIos), findsNothing);
      expect(find.byType(BandejaDocente), findsOneWidget);
    });

    testWidgets('en iPhone ya instalada, no estorba', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(
          entorno(
            plataforma: PlataformaWeb.ios,
            instalada: true,
            navegador: 'Safari',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InstructivoIos), findsNothing);
    });

    testWidgets('en Android y escritorio nunca aparece', (
      WidgetTester tester,
    ) async {
      for (final PlataformaWeb p in <PlataformaWeb>[
        PlataformaWeb.android,
        PlataformaWeb.escritorio,
      ]) {
        await tester.pumpWidget(montar(entorno(plataforma: p)));
        await tester.pumpAndSettle();
        expect(find.byType(InstructivoIos), findsNothing, reason: '$p');
      }
    });

    testWidgets('avisa si se abrió con un navegador que no es Safari', (
      WidgetTester tester,
    ) async {
      // En iPhone solo Safari puede añadir a la pantalla de inicio; seguir los
      // pasos en Chrome no lleva a ninguna parte.
      await tester.pumpWidget(
        montar(entorno(plataforma: PlataformaWeb.ios, navegador: 'Chrome')),
      );
      await tester.pump();

      expect(find.text(Textos.instalarSoloSafari('Chrome')), findsOneWidget);
    });

    testWidgets('avisa si la versión de iOS es demasiado antigua', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(
          entorno(
            plataforma: PlataformaWeb.ios,
            navegador: 'Safari',
            versionIos: 15,
          ),
        ),
      );
      await tester.pump();

      expect(find.text(Textos.instalarIosAntiguo), findsOneWidget);
    });
  });

  group('RES-05 · el instructivo se alcanza SIN haber entrado', () {
    // ──────────────────────────────────────────────────────────────────────
    // En iPhone ningún navegador ofrece un botón de instalar.
    // ──────────────────────────────────────────────────────────────────────
    //
    // Se hace desde el menú Compartir de Safari, y quien no lo sepa no lo
    // encuentra. El instructivo estaba solo tras el ingreso: tarde para quien
    // entra, e inalcanzable para quien todavía no tiene cuenta.
    late RepositorioSesionFalso sesion;

    setUp(() => sesion = RepositorioSesionFalso());
    tearDown(() => sesion.cerrar());

    Widget montar(EntornoNavegador e) => ProviderScope(
      overrides: [
        repositorioSesionProvider.overrideWithValue(sesion),
        repositorioDispositivosProvider.overrideWithValue(
          RepositorioDispositivosFalso(entorno: e),
        ),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: const PantallaIngreso(),
      ),
    );

    testWidgets('en iPhone sin instalar, el ingreso ofrece cómo hacerlo', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(entorno(plataforma: PlataformaWeb.ios, navegador: 'Safari')),
      );
      await tester.pump();

      final Finder aviso = find.text(Textos.ingresoInstalarTitulo);
      expect(aviso, findsOneWidget);

      await tester.ensureVisible(aviso);
      await tester.pumpAndSettle();
      await tester.tap(aviso);
      await tester.pumpAndSettle();

      expect(find.byType(InstructivoIos), findsOneWidget);
      // Es exactamente el paso que se pierde quien abre el menú equivocado.
      expect(
        find.textContaining('Compartir', findRichText: true),
        findsWidgets,
      );
    });

    testWidgets('en Android y escritorio no estorba', (
      WidgetTester tester,
    ) async {
      for (final PlataformaWeb p in <PlataformaWeb>[
        PlataformaWeb.android,
        PlataformaWeb.escritorio,
      ]) {
        await tester.pumpWidget(montar(entorno(plataforma: p)));
        await tester.pump();
        expect(
          find.text(Textos.ingresoInstalarTitulo),
          findsNothing,
          reason: '$p',
        );
      }
    });

    testWidgets('ya instalada, deja de ofrecerlo', (WidgetTester tester) async {
      await tester.pumpWidget(
        montar(
          entorno(
            plataforma: PlataformaWeb.ios,
            instalada: true,
            navegador: 'Safari',
          ),
        ),
      );
      await tester.pump();

      expect(find.text(Textos.ingresoInstalarTitulo), findsNothing);
    });
  });

  group('RES-07 · instrucciones para revertir un permiso denegado', () {
    test('cada navegador tiene las suyas, y no son intercambiables', () {
      // «Bloqueado» sin decir dónde se desbloquea es un callejón sin salida.
      final Set<String> textos = <String>{
        for (final String n in <String>['Chrome', 'Edge', 'Firefox', 'Safari'])
          Textos.comoRevertirPermiso(n),
      };
      expect(textos.length, 4, reason: 'ningún navegador repite instrucciones');
    });

    test('un navegador desconocido recibe una indicación genérica', () {
      expect(Textos.comoRevertirPermiso('Netscape'), isNotEmpty);
    });
  });

  group('detección de entorno', () {
    test(
      'el valor por omisión fuera del navegador no promete notificaciones',
      () {
        // En pruebas y herramientas no hay navegador: mentir aquí haría que la
        // interfaz mostrara «notificaciones activas» donde no puede haberlas.
        const EntornoNavegador e = EntornoNavegador.desconocido;
        expect(e.soportaNotificaciones, isFalse);
        expect(e.necesitaInstructivoInstalacion, isFalse);
      },
    );

    test('solo iOS sin instalar necesita el instructivo', () {
      expect(
        entorno(plataforma: PlataformaWeb.ios).necesitaInstructivoInstalacion,
        isTrue,
      );
      expect(
        entorno(
          plataforma: PlataformaWeb.ios,
          instalada: true,
        ).necesitaInstructivoInstalacion,
        isFalse,
      );
      expect(
        entorno(
          plataforma: PlataformaWeb.android,
        ).necesitaInstructivoInstalacion,
        isFalse,
      );
    });

    test('la plataforma persistida coincide con el documento 05', () {
      expect(
        entorno(plataforma: PlataformaWeb.ios).plataformaPersistida,
        'WEB_IOS',
      );
      expect(
        entorno(plataforma: PlataformaWeb.android).plataformaPersistida,
        'WEB_ANDROID',
      );
      expect(
        entorno(plataforma: PlataformaWeb.escritorio).plataformaPersistida,
        'WEB_ESCRITORIO',
      );
    });

    test('iOS anterior a la 16 se marca como demasiado antiguo', () {
      expect(
        entorno(
          plataforma: PlataformaWeb.ios,
          versionIos: 15,
        ).iosDemasiadoAntiguo,
        isTrue,
      );
      expect(
        entorno(
          plataforma: PlataformaWeb.ios,
          versionIos: 17,
        ).iosDemasiadoAntiguo,
        isFalse,
      );
      expect(
        entorno(
          plataforma: PlataformaWeb.android,
          versionIos: 15,
        ).iosDemasiadoAntiguo,
        isFalse,
      );
    });
  });
}
