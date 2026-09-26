/// Enviar a personas concretas, de 1 a n (U-6, RF-USR-06).
///
/// A veces no hay un grupo que sirva y hace falta escribirle a una o dos
/// personas puntuales. El servidor ya lo soportaba; faltaba la pantalla.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/infrastructure/firebase/repositorio_envio.dart';
import 'package:sian/presentation/admin/seccion_mensajes.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

const List<PersonaDestinataria> personas = <PersonaDestinataria>[
  PersonaDestinataria(uid: 'ana', nombre: 'Ana López', correo: 'alopez@miumg.edu.gt'),
  PersonaDestinataria(uid: 'oscar', nombre: 'Óscar Pérez', correo: 'operez@miumg.edu.gt'),
  PersonaDestinataria(uid: 'sin-nombre', nombre: '', correo: 'jdoe@miumg.edu.gt'),
];

void main() {
  group('filtrarPersonas', () {
    test('por nombre, sin importar tildes ni mayúsculas', () {
      expect(filtrarPersonas(personas, 'oscar').single.uid, 'oscar');
      expect(filtrarPersonas(personas, 'ÓSC').single.uid, 'oscar');
      expect(filtrarPersonas(personas, 'lopez').single.uid, 'ana');
    });

    test('por correo, y quien no tiene nombre se encuentra igual', () {
      expect(filtrarPersonas(personas, 'jdoe').single.uid, 'sin-nombre');
      expect(filtrarPersonas(personas, '@miumg'), hasLength(3));
    });

    test('lo ya elegido no se vuelve a ofrecer; sin búsqueda, nada', () {
      expect(filtrarPersonas(personas, 'miumg', excluir: <String>{'ana'}), hasLength(2));
      expect(filtrarPersonas(personas, '   '), isEmpty);
    });
  });

  group('en el formulario', () {
    late RepositorioSesionFalso sesion;
    late RepositorioEnvioFalso envio;

    setUp(() {
      sesion = RepositorioSesionFalso(
        inicial: SesionActiva(usuarioDePrueba(rol: Rol.administradora)),
      );
      envio = RepositorioEnvioFalso(conteo: 2, personasDisponibles: personas);
    });
    tearDown(() => sesion.cerrar());

    Future<void> montar(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositorioSesionProvider.overrideWithValue(sesion),
            repositorioEnvioProvider.overrideWithValue(envio),
          ],
          child: MaterialApp(
            theme: TemaSian.claro(),
            home: const Scaffold(body: SeccionMensajes()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> elegir(WidgetTester tester, String busqueda, String visible) async {
      await tester.enterText(
        find.widgetWithText(TextField, Textos.buscarPersona),
        busqueda,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, visible));
      await tester.pumpAndSettle();
    }

    testWidgets('se eligen dos personas y la confirmación dice sus nombres', (
      WidgetTester tester,
    ) async {
      await montar(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, Textos.etiquetaTituloMensaje),
        'Reunión',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, Textos.etiquetaCuerpoMensaje),
        'Mañana a las 9.',
      );
      await tester.tap(find.text(Textos.destinatariosPersonas));
      await tester.pumpAndSettle();

      await elegir(tester, 'ana', 'Ana López');
      await elegir(tester, 'osc', 'Óscar Pérez');
      // Quedan como fichas que se pueden quitar.
      expect(find.widgetWithText(InputChip, 'Ana López'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Óscar Pérez'), findsOneWidget);

      await tester.ensureVisible(find.text(Textos.botonEnviarAhora));
      await tester.tap(find.text(Textos.botonEnviarAhora));
      // Con el diálogo abierto el botón muestra un indicador que no se asienta.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(Textos.confirmarPara(<String>['Ana López', 'Óscar Pérez'])), findsOneWidget);
      final Map<String, Object?> mapa = envio.ultimosDestinatarios!.aMapa();
      expect(mapa['modo'], 'INDIVIDUAL');
      expect(mapa['usuariosIds'], <String>['ana', 'oscar']);
    });

    testWidgets('quitar una ficha la saca del envío', (WidgetTester tester) async {
      await montar(tester);
      await tester.tap(find.text(Textos.destinatariosPersonas));
      await tester.pumpAndSettle();
      await elegir(tester, 'ana', 'Ana López');
      await elegir(tester, 'jdoe', 'jdoe@miumg.edu.gt');

      await tester.tap(find.byTooltip(Textos.quitarPersona('Ana López')));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(InputChip, 'Ana López'), findsNothing);
      expect(find.widgetWithText(InputChip, 'jdoe@miumg.edu.gt'), findsOneWidget);
    });

    testWidgets('sin nadie elegido no se envía, y se dice por qué', (
      WidgetTester tester,
    ) async {
      await montar(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, Textos.etiquetaTituloMensaje),
        'Reunión',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, Textos.etiquetaCuerpoMensaje),
        'Mañana.',
      );
      await tester.tap(find.text(Textos.destinatariosPersonas));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(Textos.botonEnviarAhora));
      await tester.tap(find.text(Textos.botonEnviarAhora));
      await tester.pumpAndSettle();

      expect(find.text(Textos.validacionElijePersona), findsOneWidget);
      expect(envio.vecesQueConto, 0);
    });
  });

  test('la confirmación con muchos nombres no se vuelve una lista interminable', () {
    final List<String> muchos = <String>[for (int i = 1; i <= 15; i += 1) 'P$i'];
    expect(Textos.confirmarPara(muchos), endsWith('y 3 personas más.'));
    expect(Textos.confirmarPara(<String>['Ana']), 'Va a: Ana.');
  });
}
