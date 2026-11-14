/// Grupos coherentes con la sede y la facultad (2.0.7).
///
/// Lo que se vio en desarrollo el 14/11/2026: en Villa Nueva no aparecía nadie
/// de Villa Nueva para meter en un grupo. La lista se pedía una vez y al
/// cambiar de sede seguía siendo la de la anterior. Y en un grupo de una
/// facultad se ofrecía a toda la sede.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_catalogos.dart';
import 'package:sian/application/proveedores_grupos.dart';
import 'package:sian/application/proveedores_sede.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/infrastructure/firebase/repositorio_catalogos.dart';
import 'package:sian/infrastructure/firebase/repositorio_grupos.dart';
import 'package:sian/presentation/admin/seccion_grupos.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

const List<ElementoCatalogo> _facultades = <ElementoCatalogo>[
  ElementoCatalogo(id: 'ing-sistemas', nombre: 'Ing. Sistemas', activa: true),
  ElementoCatalogo(id: 'psicologia', nombre: 'Psicología', activa: true),
];

const List<Elegible> _gente = <Elegible>[
  Elegible(
    uid: 'ana',
    nombre: 'Ana',
    correo: 'ana@umg.edu.gt',
    facultades: <String>['psicologia'],
  ),
  Elegible(
    uid: 'beto',
    nombre: 'Beto',
    correo: 'beto@umg.edu.gt',
    facultades: <String>['ing-sistemas'],
  ),
];

Future<RepositorioGruposFalso> _montar(
  WidgetTester tester, {
  GrupoDetalle? grupo,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final RepositorioGruposFalso repo = RepositorioGruposFalso(personas: _gente);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositorioGruposProvider.overrideWithValue(repo),
        fuenteFacultadesProvider.overrideWith(
          (Ref ref, String _) => FuenteCatalogoEnMemoria(_facultades),
        ),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: Scaffold(body: EditorGrupo(grupo: grupo)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('en un grupo de una facultad solo se ofrece a quien la tiene', (
    WidgetTester tester,
  ) async {
    await _montar(tester);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Beto'), findsOneWidget);

    await tester.tap(find.text(Textos.grupoSinFacultad));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Psicología').last);
    await tester.pumpAndSettle();
    expect(find.text(Textos.grupoSoloDeLaFacultad), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Beto'), findsNothing);
  });

  testWidgets(
    'quien ya no cabe se dice, y se quita de un toque antes de guardar',
    (WidgetTester tester) async {
      final RepositorioGruposFalso repo = await _montar(
        tester,
        grupo: const GrupoDetalle(
          id: 'g1',
          nombre: 'Psicología',
          descripcion: '',
          // Beto perdió Psicología; «ido» ya no es de la sede.
          miembros: <String>['ana', 'beto', 'ido'],
          activo: true,
          facultadId: 'psicologia',
        ),
      );
      expect(
        find.text(Textos.grupoMiembrosFuera(2, conFacultad: true)),
        findsOneWidget,
      );
      await tester.tap(find.text(Textos.grupoQuitarlos));
      await tester.pumpAndSettle();
      expect(
        find.text(Textos.grupoMiembrosFuera(2, conFacultad: true)),
        findsNothing,
      );
      await tester.tap(find.text(Textos.grupoGuardar));
      await tester.pumpAndSettle();
      expect(repo.ultimosMiembros, <String>['ana']);
    },
  );

  test('al cambiar de sede, la lista de gente se vuelve a pedir', () async {
    final RepositorioGruposFalso repo = RepositorioGruposFalso(
      personas: _gente,
    );
    final ProviderContainer c = ProviderContainer(
      overrides: [
        repositorioGruposProvider.overrideWithValue(repo),
        sesionActualProvider.overrideWithValue(
          const SesionActiva(
            UsuarioSesion(
              uid: 'yo',
              correo: 'yo@umg.edu.gt',
              nombre: 'Yo',
              rol: Rol.coordinador,
              activo: true,
              sedes: <String, Rol>{
                'bdm': Rol.coordinador,
                'villa-nueva': Rol.coordinador,
              },
            ),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(elegiblesProvider, (_, _) {});
    await c.read(elegiblesProvider.future);
    expect(repo.vecesQuePidioElegibles, 1);

    c.read(sedeDeTrabajoProvider.notifier).elegir('villa-nueva');
    await c.read(elegiblesProvider.future);
    expect(repo.vecesQuePidioElegibles, 2);
  });
}
