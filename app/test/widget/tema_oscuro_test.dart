/// Tema oscuro — DT-21, mejora M-4.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Por qué los contrastes se miden aquí y no solo en un comentario
/// ────────────────────────────────────────────────────────────────────────────
///
/// El tema oscuro estuvo declarado desde el principio y apagado a propósito,
/// porque nadie había medido su paleta. Al medirla, **ninguno** de los colores
/// con significado llegaba a AA sobre la superficie oscura: el rojo de urgente
/// daba 2.55:1. Un número escrito en un comentario no avisa cuando alguien
/// cambia el color; esta prueba sí.
///
/// Las superficies contra las que se mide son las tres que usa la aplicación,
/// incluida la más clara del tema oscuro (#313539), que es el caso peor para un
/// texto claro.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/core/plataforma/almacen_local.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/presentation/shared/apariencia.dart';
import 'package:sian/presentation/shared/barra_sesion.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

/// Relación de contraste WCAG 2.1 entre dos colores opacos.
double contraste(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double claro = la > lb ? la : lb;
  final double oscuro = la > lb ? lb : la;
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  final ColorScheme oscuro = TemaSian.oscuro().colorScheme;
  final ColorScheme claro = TemaSian.claro().colorScheme;
  final Map<String, Color> superficiesOscuras = <String, Color>{
    'surface': oscuro.surface,
    'surfaceContainerLow': oscuro.surfaceContainerLow,
    'surfaceContainerHighest': oscuro.surfaceContainerHighest,
  };

  group('la paleta oscura cumple AA', () {
    const PaletaSian p = PaletaSian.oscura;

    test('los colores de TEXTO pasan 4.5:1 sobre las tres superficies', () {
      final Map<String, Color> textos = <String, Color>{
        'urgente': p.urgente,
        'confirmado': p.confirmado,
        'doradoTexto': p.doradoTexto,
        'primario': p.primario,
        'primarioTexto': p.primarioTexto,
      };
      textos.forEach((String nombre, Color color) {
        superficiesOscuras.forEach((String fondo, Color f) {
          expect(
            contraste(color, f),
            greaterThanOrEqualTo(4.5),
            reason: '$nombre sobre $fondo',
          );
        });
      });
    });

    test('el texto sobre un fondo tenido de su propio color sigue pasando', () {
      // Las tarjetas de aviso son el mismo color al 7-10 % sobre la superficie,
      // con texto de ese color encima.
      for (final Color c in <Color>[p.urgente, p.doradoTexto, p.confirmado]) {
        final Color tinte = Color.alphaBlend(
          c.withValues(alpha: 0.10),
          oscuro.surface,
        );
        expect(contraste(c, tinte), greaterThanOrEqualTo(4.5));
      }
    });

    test('el dorado GRÁFICO pasa 3:1, que es lo que piden los gráficos', () {
      superficiesOscuras.forEach((String fondo, Color f) {
        expect(
          contraste(p.dorado, f),
          greaterThanOrEqualTo(3),
          reason: 'dorado sobre $fondo',
        );
      });
    });

    test('los rellenos llevan texto blanco a 4.5:1 y se separan del fondo', () {
      final Map<String, Color> rellenos = <String, Color>{
        'fondoUrgente': p.fondoUrgente,
        'fondoConfirmado': p.fondoConfirmado,
        'fondoDorado': p.fondoDorado,
        'fondoPrimario': p.fondoPrimario,
      };
      rellenos.forEach((String nombre, Color c) {
        expect(
          contraste(PaletaSian.sobreFondo, c),
          greaterThanOrEqualTo(4.5),
          reason: 'blanco sobre $nombre',
        );
        // WCAG 1.4.11: la forma de la etiqueta se distingue de lo que la rodea.
        expect(
          contraste(c, oscuro.surface),
          greaterThanOrEqualTo(3),
          reason: '$nombre contra la superficie',
        );
      });
    });

    test('el rojo de urgente del tema claro NO sirve en el oscuro', () {
      // La razón de que exista la paleta. Si alguien «simplifica» usando la
      // constante de siempre, esta es la cuenta que se rompe.
      expect(contraste(ColoresSian.urgente, oscuro.surface), lessThan(3));
    });
  });

  group('el esquema oscuro de Material cumple AA', () {
    test('texto y primario sobre la superficie', () {
      expect(contraste(oscuro.onSurface, oscuro.surface), greaterThan(4.5));
      expect(
        contraste(oscuro.onSurfaceVariant, oscuro.surface),
        greaterThan(4.5),
      );
      expect(contraste(oscuro.primary, oscuro.surface), greaterThan(4.5));
      expect(contraste(oscuro.error, oscuro.surface), greaterThan(4.5));
    });

    test('lo que va SOBRE el primario y SOBRE el error', () {
      expect(contraste(oscuro.onPrimary, oscuro.primary), greaterThan(4.5));
      // El que generaba Material para el rojo del tema claro daba 1.80:1.
      expect(contraste(oscuro.onError, oscuro.error), greaterThan(4.5));
    });

    test('el icono seleccionado del menú lateral se distingue del fondo', () {
      final Color? icono =
          TemaSian.oscuro().navigationRailTheme.selectedIconTheme?.color;
      expect(icono, isNotNull);
      expect(contraste(icono!, oscuro.surface), greaterThanOrEqualTo(3));
    });
  });

  group('el tema claro no cambia', () {
    test('la paleta clara son las constantes de siempre', () {
      const PaletaSian p = PaletaSian.clara;
      expect(p.primario, ColoresSian.primario);
      expect(p.primarioTexto, ColoresSian.primarioOscuro);
      expect(p.urgente, ColoresSian.urgente);
      expect(p.confirmado, ColoresSian.confirmado);
      expect(p.dorado, ColoresSian.dorado);
      expect(p.doradoTexto, ColoresSian.doradoTexto);
      expect(p.fondoUrgente, ColoresSian.urgente);
      expect(p.fondoConfirmado, ColoresSian.confirmado);
      expect(p.fondoPrimario, ColoresSian.primario);
    });

    test('el esquema claro conserva primario, error y terciario', () {
      expect(claro.primary, ColoresSian.primario);
      expect(claro.error, ColoresSian.urgente);
      expect(claro.tertiary, ColoresSian.dorado);
      expect(
        TemaSian.claro().appBarTheme.backgroundColor,
        ColoresSian.primario,
      );
    });

    test('en el tema claro, adaptar no cambia nada', () {
      for (final Color c in <Color>[
        ColoresSian.urgente,
        ColoresSian.dorado,
        ColoresSian.urgente.withValues(alpha: 0.07),
      ]) {
        expect(PaletaSian.clara.adaptar(c), c);
      }
    });
  });

  group('adaptar', () {
    test('traduce cada constante a su par oscuro', () {
      const PaletaSian p = PaletaSian.oscura;
      expect(p.adaptar(ColoresSian.urgente), p.urgente);
      expect(p.adaptar(ColoresSian.confirmado), p.confirmado);
      expect(p.adaptar(ColoresSian.dorado), p.dorado);
      expect(p.adaptar(ColoresSian.doradoTexto), p.doradoTexto);
      expect(p.adaptar(ColoresSian.primario), p.primario);
      expect(p.adaptar(ColoresSian.primarioOscuro), p.primarioTexto);
    });

    test('conserva la transparencia de los fondos tenues', () {
      final Color tenue = PaletaSian.oscura.adaptar(
        ColoresSian.urgente.withValues(alpha: 0.07),
      );
      expect(tenue.a, closeTo(0.07, 0.001));
      expect(tenue.withValues(alpha: 1), PaletaSian.oscura.urgente);
    });

    test('un color que no es de la paleta pasa tal cual', () {
      expect(PaletaSian.oscura.adaptar(Colors.purple), Colors.purple);
    });
  });

  group('preferencia de apariencia', () {
    setUp(almacenLocalDePrueba.clear);

    test('sin nada guardado, lo del dispositivo', () {
      expect(PreferenciaTema.desde(null), PreferenciaTema.sistema);
    });

    test(
      'un valor que no se entiende NO rompe: vuelve a lo del dispositivo',
      () {
        expect(PreferenciaTema.desde('violeta'), PreferenciaTema.sistema);
      },
    );

    test('se lee lo guardado al arrancar', () {
      guardarLocal(Apariencia.clave, 'oscuro');
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(aparienciaProvider), PreferenciaTema.oscuro);
    });

    test('elegir guarda', () {
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(aparienciaProvider.notifier).elegir(PreferenciaTema.claro);
      expect(leerLocal(Apariencia.clave), 'claro');
    });
  });

  group('el selector', () {
    setUp(almacenLocalDePrueba.clear);

    Widget montar() => ProviderScope(
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, _) => MaterialApp(
          theme: TemaSian.claro(),
          darkTheme: TemaSian.oscuro(),
          themeMode: ref.watch(aparienciaProvider).modo,
          home: Scaffold(
            appBar: AppBar(actions: const <Widget>[SelectorApariencia()]),
            body: Builder(
              builder: (BuildContext context) =>
                  Text('brillo:${Theme.of(context).brightness.name}'),
            ),
          ),
        ),
      ),
    );

    testWidgets('por omisión sigue al dispositivo', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(montar());
      expect(find.text('brillo:dark'), findsOneWidget);
    });

    testWidgets('elegir «Oscuro» cambia el tema y lo recuerda', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar());
      expect(find.text('brillo:light'), findsOneWidget);

      await tester.tap(find.byType(SelectorApariencia));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Textos.temaOscuro));
      await tester.pumpAndSettle();

      expect(find.text('brillo:dark'), findsOneWidget);
      expect(leerLocal(Apariencia.clave), 'oscuro');
    });

    testWidgets('el nombre accesible dice qué está elegido', (
      WidgetTester tester,
    ) async {
      // Sin abrir el menú, quien usa lector de pantalla ya sabe el estado.
      await tester.pumpWidget(montar());
      expect(
        find.byTooltip(Textos.botonApariencia(Textos.temaSistema)),
        findsOneWidget,
      );
    });

    testWidgets('el menú marca la opción elegida', (WidgetTester tester) async {
      guardarLocal(Apariencia.clave, 'claro');
      await tester.pumpWidget(montar());
      await tester.tap(find.byType(SelectorApariencia));
      await tester.pumpAndSettle();

      final CheckedPopupMenuItem<PreferenciaTema> claroItem = tester.widget(
        find.ancestor(
          of: find.text(Textos.temaClaro),
          matching: find.byType(CheckedPopupMenuItem<PreferenciaTema>),
        ),
      );
      expect(claroItem.checked, isTrue);
    });
  });

  group('la barra superior en los dos temas', () {
    late RepositorioSesionFalso sesion;
    setUp(() => sesion = RepositorioSesionFalso());
    tearDown(() => sesion.cerrar());

    Future<void> montar(
      WidgetTester tester, {
      required ThemeData tema,
      required double ancho,
    }) async {
      tester.view.physicalSize = Size(ancho, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositorioSesionProvider.overrideWithValue(sesion)],
          child: MaterialApp(
            theme: tema,
            home: Scaffold(
              appBar: BarraSesion(
                usuario: usuarioDePrueba(rol: Rol.coordinador),
                titulo: 'Panel de administración',
                recargar: () {},
                abrirManualDe: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    for (final (String nombre, ThemeData tema) in <(String, ThemeData)>[
      ('claro', TemaSian.claro()),
      ('oscuro', TemaSian.oscuro()),
    ]) {
      testWidgets('tema $nombre: el nombre y el rol se leen sobre la barra', (
        WidgetTester tester,
      ) async {
        // En el oscuro, el rol se pintaba con `onPrimary` —azul marino— sobre
        // la barra de color superficie: oscuro sobre oscuro.
        await montar(tester, tema: tema, ancho: 1000);
        final Color fondo =
            tema.appBarTheme.backgroundColor ?? tema.colorScheme.surface;
        final UsuarioSesion u = usuarioDePrueba(rol: Rol.coordinador);

        final Color nombreColor = tester
            .widget<Text>(find.text(u.nombre))
            .style!
            .color!;
        final Color rolColor = tester
            .widget<Text>(find.text(u.rol.etiqueta))
            .style!
            .color!;

        expect(contraste(nombreColor, fondo), greaterThanOrEqualTo(4.5));
        expect(
          contraste(Color.alphaBlend(rolColor, fondo), fondo),
          greaterThanOrEqualTo(4.5),
        );
      });

      testWidgets('tema $nombre: en un teléfono estrecho no se desborda', (
        WidgetTester tester,
      ) async {
        // Cuatro botones en la barra: el título cede, los botones no.
        await montar(tester, tema: tema, ancho: 320);
        expect(tester.takeException(), isNull);
        expect(find.byType(SelectorApariencia), findsOneWidget);
        expect(find.byIcon(Icons.logout), findsOneWidget);
      });
    }

    testWidgets('el selector va entre el manual y recargar', (
      WidgetTester tester,
    ) async {
      await montar(tester, tema: TemaSian.claro(), ancho: 400);
      final double manual = tester
          .getCenter(find.byIcon(Icons.menu_book_outlined))
          .dx;
      final double apariencia = tester
          .getCenter(find.byType(SelectorApariencia))
          .dx;
      final double recargar = tester.getCenter(find.byIcon(Icons.refresh)).dx;
      expect(manual, lessThan(apariencia));
      expect(apariencia, lessThan(recargar));
    });
  });

  group('el escudo', () {
    Future<void> montar(WidgetTester tester, ThemeData tema) =>
        tester.pumpWidget(
          MaterialApp(
            theme: tema,
            home: const Center(child: EscudoUmg(tamano: 96)),
          ),
        );

    testWidgets('en el oscuro va sobre un disco blanco, del mismo tamaño', (
      WidgetTester tester,
    ) async {
      await montar(tester, TemaSian.oscuro());
      final Container disco = tester.widget<Container>(
        find.descendant(
          of: find.byType(EscudoUmg),
          matching: find.byType(Container),
        ),
      );
      final BoxDecoration d = disco.decoration! as BoxDecoration;
      expect(d.color, Colors.white);
      expect(d.shape, BoxShape.circle);
      expect(tester.getSize(find.byType(EscudoUmg)), const Size(96, 96));
    });

    testWidgets('en el claro, como siempre: sin disco', (
      WidgetTester tester,
    ) async {
      await montar(tester, TemaSian.claro());
      expect(
        find.descendant(
          of: find.byType(EscudoUmg),
          matching: find.byType(Container),
        ),
        findsNothing,
      );
    });
  });

  group('las pantallas no usan colores fijos', () {
    test('solo estos archivos pueden nombrar ColoresSian', () {
      // Un `ColoresSian.urgente` escrito directamente en una pantalla se ve
      // bien en claro y falla AA en oscuro, sin que nada lo avise. Las
      // pantallas piden los colores a `PaletaSian.de(context)`.
      //
      // Las excepciones tienen motivo: el propio tema; la banda de ambiente y
      // la cabecera de la portada, que pintan su propio fondo y se ven igual
      // en los dos temas; y las funciones que deciden un color sin tema (el
      // estado de una entrega, el realce de un mensaje), cuyo resultado se
      // adapta con `adaptar` donde se pinta.
      const Set<String> permitidos = <String>{
        'lib/presentation/shared/tema.dart',
        'lib/presentation/shared/banda_ambiente.dart',
        'lib/presentation/shared/pantalla_ingreso.dart',
        'lib/presentation/admin/seccion_entregas.dart',
        'lib/presentation/admin/seccion_canal.dart',
        'lib/presentation/docente/realce_mensaje.dart',
        'lib/presentation/docente/tarjeta_notificaciones.dart',
      };
      final List<String> infractores = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .where((File f) => f.readAsStringSync().contains('ColoresSian.'))
          .map((File f) => f.path)
          .where((String p) => !permitidos.contains(p))
          .toList();
      expect(infractores, isEmpty);
    });
  });
}
