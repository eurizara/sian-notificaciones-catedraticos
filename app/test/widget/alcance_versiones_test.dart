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

/// Las listas de Alcance arrancan plegadas (26/09/2026): se despliegan para
/// poder mirar dentro.
Future<void> desplegarListas(WidgetTester tester) async {
  for (final String clave in <String>[
    'desplegable-canal',
    'desplegable-versiones',
  ]) {
    final Finder f = find.byKey(Key(clave));
    if (f.evaluate().isNotEmpty) {
      await tester.tap(f);
      await tester.pumpAndSettle();
    }
  }
}

void main() {
  group('clasificarVersiones', () {
    AparatoConVersion ap(
      String plataforma,
      String version, {
      String navegador = 'Safari',
      String? dia,
    }) => AparatoConVersion(
      plataforma: plataforma,
      versionApp: version,
      navegador: navegador,
      ultimaActividad: dia == null ? null : DateTime.parse('2026-$dia'),
    );

    VersionesDePersona persona(List<AparatoConVersion> aparatos) =>
        VersionesDePersona(
          uid: 'u',
          nombre: 'Persona',
          correo: 'p@umg',
          aparatos: aparatos,
        );

    test('quien tiene todo al día no aparece', () {
      final ClasificacionDeVersiones r = clasificarVersiones(
        <VersionesDePersona>[
          persona(<AparatoConVersion>[ap('WEB_IOS', '1.5.11', dia: '09-16')]),
        ],
        '1.5.11',
      );
      expect(r.atrasados, isEmpty);
      expect(r.reemplazados, 0);
    });

    test('registros viejos del MISMO teléfono no la hacen atrasada', () {
      // El caso de producción del 16/09/2026: un iPhone al día y tres
      // registros de instalaciones de finales de agosto.
      final ClasificacionDeVersiones r = clasificarVersiones(
        <VersionesDePersona>[
          persona(<AparatoConVersion>[
            ap('WEB_IOS', '1.5.11', dia: '09-16'),
            ap('WEB_IOS', '', dia: '08-27'),
            ap('WEB_IOS', '', dia: '08-28'),
            ap('WEB_IOS', '', dia: '08-28'),
          ]),
        ],
        '1.5.11',
      );
      expect(r.atrasados, isEmpty);
      expect(r.reemplazados, 3);
    });

    test('otro navegador en el mismo teléfono sí cuenta como atrasado', () {
      // Firefox y Chrome son dos canales: el de Firefox puede seguir en uso.
      final ClasificacionDeVersiones r = clasificarVersiones(
        <VersionesDePersona>[
          persona(<AparatoConVersion>[
            ap('WEB_ANDROID', '1.5.11', navegador: 'Chrome', dia: '09-14'),
            ap('WEB_ANDROID', '', navegador: 'Firefox', dia: '08-28'),
          ]),
        ],
        '1.5.11',
      );
      expect(r.reemplazados, 0);
      expect(r.atrasados.single.aparatos.single.navegador, 'Firefox');
    });

    test('otra plataforma sí cuenta: el teléfono al día no tapa la computadora', () {
      final ClasificacionDeVersiones r = clasificarVersiones(
        <VersionesDePersona>[
          persona(<AparatoConVersion>[
            ap('WEB_ANDROID', '1.5.11', navegador: 'Chrome', dia: '09-14'),
            ap('WEB_ESCRITORIO', '1.5.4', navegador: 'Chrome', dia: '08-20'),
          ]),
        ],
        '1.5.11',
      );
      expect(r.atrasados.single.aparatos.single.plataforma, 'WEB_ESCRITORIO');
    });

    test('un atrasado MÁS reciente que el actualizado no es un resto: es otro aparato', () {
      // Dos iPhone, o un iPhone y un iPad: el que se usó después sigue vivo.
      final ClasificacionDeVersiones r = clasificarVersiones(
        <VersionesDePersona>[
          persona(<AparatoConVersion>[
            ap('WEB_IOS', '1.5.11', dia: '09-10'),
            ap('WEB_IOS', '1.5.9', dia: '09-15'),
          ]),
        ],
        '1.5.11',
      );
      expect(r.reemplazados, 0);
      expect(r.atrasados, hasLength(1));
    });

    test('una versión desconocida sin nada al día cuenta como atrasada', () {
      final ClasificacionDeVersiones r = clasificarVersiones(
        <VersionesDePersona>[
          persona(<AparatoConVersion>[ap('WEB_IOS', '', dia: '08-28')]),
        ],
        '1.5.11',
      );
      expect(r.atrasados, hasLength(1));
      expect(r.reemplazados, 0);
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
      await desplegarListas(tester);
    }

    testWidgets('las dos listas arrancan plegadas, con cuántas personas hay', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            revisionDeCanalProvider.overrideWith(
              (Ref ref) async => RevisionDeCanal(
                total: 1,
                catedraticos: 3,
                personas: const <PersonaSinCanal>[
                  PersonaSinCanal(
                    uid: 'd',
                    nombre: 'Dora',
                    correo: 'd@umg',
                    estado: EstadoCanal.sinDispositivo,
                  ),
                ],
                versiones: <VersionesDePersona>[
                  _persona('Beto', <(String, String)>[
                    ('WEB_ANDROID', '1.5.9'),
                  ]),
                ],
              ),
            ),
            versionPublicadaProvider.overrideWith((Ref ref) async => '1.5.10'),
          ],
          child: MaterialApp(
            theme: TemaSian.claro(),
            home: const Scaffold(body: SeccionCanal()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(Textos.canalVerPersonas(1)), findsOneWidget);
      expect(find.text(Textos.canalVerAtrasados(1)), findsOneWidget);
      expect(find.text('Dora'), findsNothing);
      expect(find.text('Beto'), findsNothing);
      // El resumen sigue a la vista sin desplegar nada.
      expect(
        find.text(Textos.canalVersionesResumen(1, 1, '1.5.10')),
        findsOneWidget,
      );

      await desplegarListas(tester);
      expect(find.text('Dora'), findsOneWidget);
      expect(find.text('Beto'), findsOneWidget);
    });

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

    testWidgets('los registros reemplazados se dicen aparte y no cuentan', (
      WidgetTester tester,
    ) async {
      await montar(
        tester,
        RevisionDeCanal(
          total: 0,
          catedraticos: 1,
          personas: const <PersonaSinCanal>[],
          versiones: <VersionesDePersona>[
            VersionesDePersona(
              uid: 'e',
              nombre: 'Ezequiel',
              correo: 'e@umg',
              aparatos: <AparatoConVersion>[
                AparatoConVersion(
                  plataforma: 'WEB_IOS',
                  navegador: 'Safari',
                  versionApp: '1.5.10',
                  ultimaActividad: DateTime.parse('2026-09-16'),
                ),
                AparatoConVersion(
                  plataforma: 'WEB_IOS',
                  navegador: 'Safari',
                  versionApp: '',
                  ultimaActividad: DateTime.parse('2026-08-27'),
                ),
              ],
            ),
          ],
        ),
      );
      expect(find.text(Textos.canalVersionesResumen(0, 1, '1.5.10')), findsOneWidget);
      expect(find.text(Textos.canalVersionesReemplazados(1)), findsOneWidget);
      expect(find.text('Ezequiel'), findsNothing);
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
