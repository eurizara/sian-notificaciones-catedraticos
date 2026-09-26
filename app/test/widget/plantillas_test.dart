/// Plantillas de avisos (RF-MSG-14).
///
/// Los recordatorios de actualizar o de responder, los simulacros y las
/// suspensiones se escriben casi igual cada vez. Una plantilla llena el
/// formulario; nada sale hasta que alguien la revisa y pulsa enviar, y lo que
/// quedó entre corchetes sin completar no deja enviar.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/infrastructure/firebase/repositorio_plantillas.dart';
import 'package:sian/presentation/admin/plantillas.dart';
import 'package:sian/presentation/admin/seccion_mensajes.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

class RepositorioPlantillasFalso implements RepositorioPlantillas {
  RepositorioPlantillasFalso(List<Plantilla> iniciales)
    : _plantillas = List<Plantilla>.of(iniciales);

  final List<Plantilla> _plantillas;
  final StreamController<List<Plantilla>> _flujo =
      StreamController<List<Plantilla>>.broadcast();
  final List<Plantilla> guardadas = <Plantilla>[];
  final List<String> borradas = <String>[];

  @override
  Stream<List<Plantilla>> observar() async* {
    yield List<Plantilla>.of(_plantillas);
    yield* _flujo.stream;
  }

  @override
  Future<void> guardar(Plantilla p) async {
    guardadas.add(p);
    _plantillas.add(p);
    _flujo.add(List<Plantilla>.of(_plantillas));
  }

  @override
  Future<void> borrar(String id) async {
    borradas.add(id);
    _plantillas.removeWhere((Plantilla p) => p.id == id);
    _flujo.add(List<Plantilla>.of(_plantillas));
  }
}

const Plantilla _propia = Plantilla(
  id: 'p-1',
  nombre: 'Entrega de notas',
  titulo: 'Entrega de notas del parcial',
  cuerpo: 'Recuerde subir las notas antes del viernes.',
  requiereConfirmacion: true,
);

void main() {
  group('filtrarPlantillas', () {
    test('por nombre o título, sin tildes ni mayúsculas', () {
      final List<Plantilla> todas = <Plantilla>[
        ...plantillasPredefinidas,
        _propia,
      ];
      expect(
        filtrarPlantillas(todas, 'simulacro').map((Plantilla p) => p.nombre),
        contains('Simulacro de evacuación'),
      );
      expect(
        filtrarPlantillas(todas, 'EVACUACION').length,
        greaterThanOrEqualTo(1),
      );
      expect(filtrarPlantillas(todas, 'notas').single.id, 'p-1');
      expect(filtrarPlantillas(todas, '  '), hasLength(todas.length));
    });
  });

  test('marcadores: lo que va entre corchetes en la plantilla', () {
    expect(marcadoresDe('El [día] a las [hora], en [lugar]. [día]'), <String>{
      '[día]',
      '[hora]',
      '[lugar]',
    });
    expect(marcadoresDe('Sin nada que completar.'), isEmpty);
  });

  test('las predefinidas caben en los límites de un aviso', () {
    for (final Plantilla p in plantillasPredefinidas) {
      expect(p.predefinida, isTrue);
      expect(p.nombre.characters.length, lessThanOrEqualTo(60));
      expect(
        p.titulo.characters.length,
        lessThanOrEqualTo(Textos.limiteTitulo),
      );
      expect(
        p.cuerpo.characters.length,
        lessThanOrEqualTo(Textos.limiteCuerpo),
      );
    }
  });

  group('en el formulario', () {
    late RepositorioSesionFalso sesion;
    late RepositorioPlantillasFalso plantillas;
    late RepositorioEnvioFalso envio;

    Future<void> montar(
      WidgetTester tester, {
      Rol rol = Rol.coordinador,
    }) async {
      sesion = RepositorioSesionFalso(
        inicial: SesionActiva(usuarioDePrueba(rol: rol)),
      );
      addTearDown(sesion.cerrar);
      plantillas = RepositorioPlantillasFalso(<Plantilla>[_propia]);
      envio = RepositorioEnvioFalso(conteo: 3);
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositorioSesionProvider.overrideWithValue(sesion),
            repositorioEnvioProvider.overrideWithValue(envio),
            repositorioPlantillasProvider.overrideWithValue(plantillas),
          ],
          child: MaterialApp(
            theme: TemaSian.claro(),
            home: const Scaffold(body: SeccionMensajes()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    String titulo(WidgetTester tester) => tester
        .widget<TextFormField>(
          find.widgetWithText(TextFormField, Textos.etiquetaTituloMensaje),
        )
        .controller!
        .text;
    String cuerpo(WidgetTester tester) => tester
        .widget<TextFormField>(
          find.widgetWithText(TextFormField, Textos.etiquetaCuerpoMensaje),
        )
        .controller!
        .text;

    Future<void> elegir(WidgetTester tester, String nombre) async {
      await tester.tap(find.text(Textos.plantillaUsar));
      await tester.pumpAndSettle();
      await tester.tap(find.text(nombre));
      await tester.pumpAndSettle();
    }

    testWidgets('elegir una plantilla llena el título y el mensaje', (
      WidgetTester tester,
    ) async {
      await montar(tester);
      await elegir(tester, 'Entrega de notas');
      expect(titulo(tester), 'Entrega de notas del parcial');
      expect(cuerpo(tester), 'Recuerde subir las notas antes del viernes.');
    });

    testWidgets('ofrece las predefinidas y las propias', (
      WidgetTester tester,
    ) async {
      await montar(tester);
      await tester.tap(find.text(Textos.plantillaUsar));
      await tester.pumpAndSettle();
      expect(find.text('Simulacro de evacuación'), findsOneWidget);
      expect(find.text('Recordatorio de actualizar SIAN'), findsOneWidget);
      expect(find.text('Entrega de notas'), findsOneWidget);
    });

    testWidgets('sin permiso de urgentes, no se ofrecen plantillas urgentes', (
      WidgetTester tester,
    ) async {
      await montar(tester, rol: Rol.administradora);
      await tester.tap(find.text(Textos.plantillaUsar));
      await tester.pumpAndSettle();
      expect(find.text('Evacuación inmediata'), findsNothing);
      expect(find.text('Simulacro de evacuación'), findsOneWidget);
    });

    testWidgets('si ya había algo escrito, pregunta antes de reemplazarlo', (
      WidgetTester tester,
    ) async {
      await montar(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, Textos.etiquetaTituloMensaje),
        'Lo que estaba escribiendo',
      );
      await elegir(tester, 'Entrega de notas');
      expect(find.text(Textos.plantillaReemplazarTitulo), findsOneWidget);
      await tester.tap(find.text(Textos.botonCancelar));
      await tester.pumpAndSettle();
      expect(titulo(tester), 'Lo que estaba escribiendo');

      await elegir(tester, 'Entrega de notas');
      await tester.tap(find.text(Textos.plantillaReemplazar));
      await tester.pumpAndSettle();
      expect(titulo(tester), 'Entrega de notas del parcial');
    });

    testWidgets('lo que quedó entre corchetes no deja enviar', (
      WidgetTester tester,
    ) async {
      await montar(tester);
      await elegir(tester, 'Simulacro de evacuación');
      expect(cuerpo(tester), contains('['));

      await tester.ensureVisible(find.text(Textos.botonEnviarAhora));
      await tester.tap(find.text(Textos.botonEnviarAhora));
      await tester.pumpAndSettle();
      expect(find.textContaining(Textos.plantillaSinCompletar), findsWidgets);
      expect(envio.vecesQueConto, 0);
      expect(envio.vecesQueEnvio, 0);
    });

    testWidgets('guardar lo escrito como plantilla pide un nombre', (
      WidgetTester tester,
    ) async {
      await montar(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, Textos.etiquetaTituloMensaje),
        'Cierre de actas',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, Textos.etiquetaCuerpoMensaje),
        'Las actas se cierran el [día].',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(Textos.plantillaGuardar));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, Textos.plantillaNombre),
        'Actas',
      );
      await tester.tap(find.text(Textos.plantillaGuardarConfirmar));
      await tester.pumpAndSettle();

      expect(plantillas.guardadas, hasLength(1));
      final Plantilla g = plantillas.guardadas.single;
      expect(g.nombre, 'Actas');
      expect(g.titulo, 'Cierre de actas');
      expect(g.cuerpo, 'Las actas se cierran el [día].');
      expect(g.id, isNull);
    });

    testWidgets(
      'una propia se puede borrar, con confirmación; una predefinida no',
      (WidgetTester tester) async {
        await montar(tester);
        await tester.tap(find.text(Textos.plantillaUsar));
        await tester.pumpAndSettle();
        expect(find.byTooltip(Textos.plantillaBorrar), findsOneWidget);
        await tester.tap(find.byTooltip(Textos.plantillaBorrar));
        await tester.pumpAndSettle();
        await tester.tap(find.text(Textos.plantillaBorrarConfirmar));
        await tester.pumpAndSettle();
        expect(plantillas.borradas, <String>['p-1']);
      },
    );
  });
}
