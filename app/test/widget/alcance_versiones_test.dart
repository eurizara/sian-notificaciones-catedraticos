/// Alcance: quién tiene algún aparato sin la versión publicada.
///
/// La lista de canal solo traía a quien tenía problemas para recibir. Quien
/// recibía bien con una versión vieja no salía en ningún sitio, y es justo a
/// quien hay que pedirle actualizar (13/09/2026).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/infrastructure/firebase/repositorio_canal.dart';
import 'package:sian/presentation/admin/seccion_canal.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';
import 'package:sian/presentation/shared/version_app.dart';

VersionesDePersona _persona(String nombre, List<(String, String)> aparatos) =>
    VersionesDePersona(
      uid: nombre,
      nombre: nombre,
      correo: '$nombre@umg',
      aparatos: <AparatoConVersion>[
        for (final (String plataforma, String version) a in aparatos)
          AparatoConVersion(plataforma: a.$1, versionApp: a.$2),
      ],
    );

void main() {
  group('sinLaVersionPublicada', () {
    test('quien tiene todo al día no aparece', () {
      final List<VersionesDePersona> r = sinLaVersionPublicada(
        <VersionesDePersona>[
          _persona('Ana', <(String, String)>[('WEB_IOS', '1.5.10')]),
        ],
        '1.5.10',
      );
      expect(r, isEmpty);
    });

    test('va por aparato: sale solo el que está atrasado', () {
      final List<VersionesDePersona> r = sinLaVersionPublicada(
        <VersionesDePersona>[
          _persona('Ana', <(String, String)>[
            ('WEB_ANDROID', '1.5.10'),
            ('WEB_ESCRITORIO', '1.5.4'),
          ]),
        ],
        '1.5.10',
      );
      expect(r, hasLength(1));
      expect(r.single.aparatos.map((AparatoConVersion a) => a.plataforma), <String>[
        'WEB_ESCRITORIO',
      ]);
    });

    test('una versión desconocida cuenta como no actualizada', () {
      // Ese aparato no ha abierto SIAN desde que se guarda la versión: no
      // puede estar al día.
      final List<VersionesDePersona> r = sinLaVersionPublicada(
        <VersionesDePersona>[
          _persona('Ana', <(String, String)>[('WEB_IOS', '')]),
        ],
        '1.5.10',
      );
      expect(r, hasLength(1));
    });
  });

  group('en la pantalla de Alcance', () {
    Future<void> montar(
      WidgetTester tester,
      RevisionDeCanal revision, {
      String? publicada = '1.5.10',
    }) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            revisionDeCanalProvider.overrideWith((Ref ref) async => revision),
            versionPublicadaProvider.overrideWith((Ref ref) async => publicada),
          ],
          child: MaterialApp(
            theme: TemaSian.claro(),
            home: const Scaffold(body: SeccionCanal()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lista a quien tiene un aparato atrasado, con qué aparato y versión', (
      WidgetTester tester,
    ) async {
      await montar(
        tester,
        RevisionDeCanal(
          total: 0,
          catedraticos: 3,
          personas: const <PersonaSinCanal>[],
          versiones: <VersionesDePersona>[
            _persona('Ana', <(String, String)>[('WEB_IOS', '1.5.10')]),
            _persona('Beto', <(String, String)>[('WEB_ANDROID', '1.5.9')]),
            _persona('Carla', <(String, String)>[('WEB_ESCRITORIO', '')]),
          ],
        ),
      );

      expect(find.text(Textos.canalVersionesTitulo), findsOneWidget);
      expect(find.text(Textos.canalVersionesResumen(2, 3, '1.5.10')), findsOneWidget);
      expect(find.text('Beto'), findsOneWidget);
      expect(find.text('Carla'), findsOneWidget);
      // Quien está al día no se lista.
      expect(find.text('Ana'), findsNothing);
      expect(find.textContaining('Android · Versión 1.5.9'), findsOneWidget);
      expect(find.textContaining('Computadora · Versión desconocida'), findsOneWidget);
    });

    testWidgets('si todos están al día, lo dice y no lista a nadie', (
      WidgetTester tester,
    ) async {
      await montar(
        tester,
        RevisionDeCanal(
          total: 0,
          catedraticos: 1,
          personas: const <PersonaSinCanal>[],
          versiones: <VersionesDePersona>[
            _persona('Ana', <(String, String)>[('WEB_IOS', '1.5.10')]),
          ],
        ),
      );
      expect(find.text(Textos.canalVersionesResumen(0, 1, '1.5.10')), findsOneWidget);
      expect(find.text(Textos.canalVersionesPedir), findsNothing);
    });

    testWidgets('sin saber la publicada, compara con la de esta aplicación', (
      WidgetTester tester,
    ) async {
      await montar(
        tester,
        RevisionDeCanal(
          total: 0,
          catedraticos: 1,
          personas: const <PersonaSinCanal>[],
          versiones: <VersionesDePersona>[
            _persona('Beto', <(String, String)>[('WEB_ANDROID', '0.0.1')]),
          ],
        ),
        publicada: null,
      );
      expect(find.text('Beto'), findsOneWidget);
    });
  });
}
