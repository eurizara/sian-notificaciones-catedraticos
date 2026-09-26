/// Respuestas muestra 10 conversaciones a la vez, como Entregas (26/09/2026).
///
/// Cada aviso agrupa sus conversaciones; lo que se cuenta son las
/// conversaciones, no los avisos: un aviso respondido por treinta personas
/// llenaba la pantalla solo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_respuestas.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/infrastructure/firebase/repositorio_respuestas.dart';
import 'package:sian/presentation/admin/seccion_respuestas.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

AvisoConRespuestas aviso(String id, int conversaciones) => AvisoConRespuestas(
  mensajeId: id,
  tituloAviso: 'Aviso $id',
  hilos: <Hilo>[
    for (int i = 1; i <= conversaciones; i += 1)
      Hilo(
        mensajeId: id,
        uid: '$id-$i',
        nombre: 'Persona $id$i',
        emisorUid: 'yo',
        tituloAviso: 'Aviso $id',
      ),
  ],
);

void main() {
  group('primerasConversaciones', () {
    test('corta por conversaciones, aunque parta un aviso', () {
      final List<AvisoConRespuestas> r = primerasConversaciones(
        <AvisoConRespuestas>[aviso('a', 6), aviso('b', 6), aviso('c', 2)],
        10,
      );
      expect(r.map((AvisoConRespuestas a) => a.mensajeId), <String>['a', 'b']);
      expect(r[0].hilos, hasLength(6));
      expect(r[1].hilos, hasLength(4));
    });

    test('con menos del límite, todo', () {
      final List<AvisoConRespuestas> todos = <AvisoConRespuestas>[
        aviso('a', 3),
        aviso('b', 2),
      ];
      expect(primerasConversaciones(todos, 10), hasLength(2));
      expect(totalDeConversaciones(todos), 5);
    });
  });

  testWidgets('muestra 10 y «Ver más» trae las siguientes', (
    WidgetTester tester,
  ) async {
    final RepositorioSesionFalso sesion = RepositorioSesionFalso(
      inicial: SesionActiva(usuarioDePrueba(rol: Rol.coordinador)),
    );
    addTearDown(sesion.cerrar);
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositorioSesionProvider.overrideWithValue(sesion),
          avisosConRespuestasProvider.overrideWith(
            (Ref ref) => Stream<List<AvisoConRespuestas>>.value(
              <AvisoConRespuestas>[aviso('a', 8), aviso('b', 7)],
            ),
          ),
        ],
        child: MaterialApp(
          theme: TemaSian.claro(),
          home: const Scaffold(body: SeccionRespuestas()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(FilaDeHilo), findsNWidgets(10));
    expect(find.text(Textos.mostrandoDe(10, 15)), findsOneWidget);

    await tester.tap(find.text(Textos.verMas));
    await tester.pump();
    expect(find.byType(FilaDeHilo), findsNWidgets(15));
    expect(find.text(Textos.verMas), findsNothing);
  });
}
