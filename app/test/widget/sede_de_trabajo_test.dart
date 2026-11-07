/// La sede de trabajo (2.0 · RF-SED-04, RF-SED-05).
///
/// Con una sola sede no se pregunta nada. Con varias, se elige en la barra, se
/// recuerda, se manda en cada llamada al servidor, y las listas muestran solo
/// lo de esa sede.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_catalogos.dart';
import 'package:sian/application/proveedores_grupos.dart';
import 'package:sian/application/proveedores_sede.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/core/plataforma/almacen_local_vm.dart';
import 'package:sian/core/sede_de_trabajo.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/infrastructure/firebase/repositorio_grupos.dart';
import 'package:sian/presentation/shared/barra_sesion.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

UsuarioSesion _usuario(Map<String, Rol> sedes) => UsuarioSesion(
  uid: 'u',
  correo: 'a@umg.edu.gt',
  nombre: 'Ana',
  rol: Rol.coordinador,
  activo: true,
  sedes: sedes,
);

const Map<String, String> _nombres = <String, String>{
  'bdm': 'Boca del Monte',
  'otra': 'Otra sede',
};

List<Override> _overrides(
  UsuarioSesion u, {
  RepositorioGrupos? grupos,
}) => <Override>[
  sesionActualProvider.overrideWithValue(SesionActiva(u)),
  nombreDeSedeProvider.overrideWith((Ref ref, String id) async => _nombres[id]),
  if (grupos != null) repositorioGruposProvider.overrideWithValue(grupos),
];

Future<ProviderContainer> _montarBarra(
  WidgetTester tester,
  UsuarioSesion u,
) async {
  final ProviderContainer c = ProviderContainer(overrides: _overrides(u));
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1200, 800)),
          child: Scaffold(
            appBar: BarraSesion(usuario: u, titulo: 'Panel'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

void main() {
  setUp(() {
    almacenLocalDePrueba.clear();
    SedeDeTrabajo.fijar(null);
  });

  group('conSede', () {
    test('sin sesión no agrega nada', () {
      expect(conSede(<String, Object?>{'a': 1}), <String, Object?>{'a': 1});
    });

    test('con sede de trabajo la agrega a la llamada', () {
      SedeDeTrabajo.fijar('otra');
      expect(conSede(<String, Object?>{'a': 1}), <String, Object?>{
        'a': 1,
        'sedeId': 'otra',
      });
      expect(conSede(), <String, Object?>{'sedeId': 'otra'});
    });

    test('un documento sin sede es de la inicial', () {
      expect(sedeDelDocumento(<String, dynamic>{}), 'bdm');
      expect(sedeDelDocumento(null), 'bdm');
      expect(sedeDelDocumento(<String, dynamic>{'sedeId': 'otra'}), 'otra');
    });
  });

  testWidgets(
    'con una sola sede no aparece el selector, y la sede queda fijada',
    (WidgetTester tester) async {
      await _montarBarra(
        tester,
        _usuario(<String, Rol>{'bdm': Rol.coordinador}),
      );
      expect(find.byIcon(Icons.location_city_outlined), findsNothing);
      expect(SedeDeTrabajo.actual, 'bdm');
    },
  );

  testWidgets('con un token de antes de la 2.0 trabaja en la inicial', (
    WidgetTester tester,
  ) async {
    await _montarBarra(tester, _usuario(<String, Rol>{}));
    expect(find.byIcon(Icons.location_city_outlined), findsNothing);
    expect(SedeDeTrabajo.actual, 'bdm');
  });

  testWidgets(
    'con varias: se ve en cuál y con qué rol, se elige, y se recuerda',
    (WidgetTester tester) async {
      final ProviderContainer c = await _montarBarra(
        tester,
        _usuario(<String, Rol>{
          'bdm': Rol.coordinador,
          'otra': Rol.catedratico,
        }),
      );
      expect(
        find.text('${Rol.coordinador.etiqueta} · Boca del Monte'),
        findsOneWidget,
      );
      expect(
        find.byTooltip(Textos.sedeDeTrabajo('Boca del Monte')),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.location_city_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Otra sede · ${Rol.catedratico.etiqueta}'));
      await tester.pumpAndSettle();

      expect(c.read(sedeDeTrabajoProvider), 'otra');
      expect(SedeDeTrabajo.actual, 'otra');
      expect(almacenLocalDePrueba['sian.sede'], 'otra');
      expect(
        find.text('${Rol.catedratico.etiqueta} · Otra sede'),
        findsOneWidget,
      );
    },
  );

  test('una sede recordada que ya no es suya se ignora', () {
    almacenLocalDePrueba['sian.sede'] = 'vieja';
    final ProviderContainer c = ProviderContainer(
      overrides: _overrides(
        _usuario(<String, Rol>{
          'bdm': Rol.coordinador,
          'otra': Rol.catedratico,
        }),
      ),
    );
    addTearDown(c.dispose);
    expect(c.read(sedeDeTrabajoProvider), 'bdm');
    c.read(sedeDeTrabajoProvider.notifier).elegir('ajena');
    expect(c.read(sedeDeTrabajoProvider), 'bdm');
  });

  test(
    'los grupos que se ofrecen son solo los de la sede de trabajo',
    () async {
      final ProviderContainer c = ProviderContainer(
        overrides: _overrides(
          _usuario(<String, Rol>{
            'bdm': Rol.coordinador,
            'otra': Rol.coordinador,
          }),
          grupos: RepositorioGruposFalso(
            grupos: const <GrupoDetalle>[
              GrupoDetalle(
                id: 'g1',
                nombre: 'Docentes',
                descripcion: '',
                miembros: <String>[],
                activo: true,
              ),
              GrupoDetalle(
                id: 'g2',
                nombre: 'De la otra',
                descripcion: '',
                miembros: <String>[],
                activo: true,
                sedeId: 'otra',
              ),
            ],
          ),
        ),
      );
      addTearDown(c.dispose);
      // Con alguien escuchando, como en la pantalla: si no, se pausa.
      c.listen(gruposProvider, (Object? _, Object? _) {});
      final List<GrupoDetalle> enBdm = await c.read(gruposProvider.future);
      expect(enBdm.map((GrupoDetalle g) => g.id), <String>['g1']);

      c.read(sedeDeTrabajoProvider.notifier).elegir('otra');
      final List<GrupoDetalle> enOtra = await c.read(gruposProvider.future);
      expect(enOtra.map((GrupoDetalle g) => g.id), <String>['g2']);
    },
  );
}
