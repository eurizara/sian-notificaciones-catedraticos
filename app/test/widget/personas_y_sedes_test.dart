/// Personas y sedes (2.0.1 · RF-SED-02, RF-SED-06).
///
/// El superadministrador pone a cada persona en sus sedes con su rol. Desde la
/// 2.0.5 también cambia las suyas, como sus facultades; nadie se queda sin sede.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_catalogos.dart';
import 'package:sian/infrastructure/firebase/repositorio_administracion.dart';
import 'package:sian/infrastructure/firebase/repositorio_catalogos.dart';
import 'package:sian/presentation/admin/personas_y_sedes.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

class _RepoFalso extends RepositorioPersonasYSedes {
  final List<String> llamadas = <String>[];

  @override
  Future<void> asignarSede({
    required String uid,
    required String sedeId,
    required String rol,
    List<String>? facultades,
  }) async => llamadas.add(
    'asignar $sedeId $rol${(facultades ?? <String>[]).isEmpty ? '' : ' ${facultades!.join(',')}'}',
  );

  @override
  Future<void> quitarSede({
    required String uid,
    required String sedeId,
  }) async => llamadas.add('quitar $sedeId');

  @override
  Future<void> cambiarAdminGeneral({
    required String uid,
    required bool valor,
  }) async => llamadas.add('admin $valor');
}

const List<ElementoCatalogo> _sedes = <ElementoCatalogo>[
  ElementoCatalogo(id: 'bdm', nombre: 'Boca del Monte', activa: true),
  ElementoCatalogo(id: 'otra', nombre: 'Otra sede', activa: true),
];

const UsuarioVista _ana = UsuarioVista(
  uid: 'ana',
  correo: 'ana@umg.edu.gt',
  nombre: 'Ana',
  rol: 'CATEDRATICO',
  activo: true,
  puedeEmitirUrgentes: false,
  recibeAvisos: true,
  puedeCrearRecurrentes: false,
);

Future<_RepoFalso> _montar(
  WidgetTester tester, {
  UsuarioVista persona = _ana,
}) async {
  final _RepoFalso repo = _RepoFalso();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositorioPersonasYSedesProvider.overrideWithValue(repo),
        // Lo que ofrece cada sede (2.0.6).
        fuenteFacultadesProvider.overrideWith(
          (Ref ref, String sede) => FuenteCatalogoEnMemoria(
            sede == 'bdm'
                ? const <ElementoCatalogo>[
                    ElementoCatalogo(
                      id: 'ing-sistemas',
                      nombre: 'Ingeniería en Sistemas',
                      activa: true,
                    ),
                    ElementoCatalogo(
                      id: 'psicologia',
                      nombre: 'Psicología',
                      activa: true,
                    ),
                    ElementoCatalogo(
                      id: 'derecho',
                      nombre: 'Derecho',
                      activa: false,
                    ),
                  ]
                : const <ElementoCatalogo>[],
          ),
        ),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: Scaffold(
          body: DialogoSedes(persona: persona, sedes: _sedes),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('cambiosDeSedes', () {
    test('altas y cambios primero, bajas al final', () {
      expect(
        cambiosDeSedes(
          <String, MembresiaDeseada>{
            'bdm': const MembresiaDeseada('CATEDRATICO'),
            'vieja': const MembresiaDeseada('AUDITOR'),
          },
          <String, MembresiaDeseada>{
            'bdm': const MembresiaDeseada('COORDINADOR'),
            'otra': const MembresiaDeseada('CATEDRATICO'),
          },
        ),
        <CambioDeSede>[
          const AsignarSede('bdm', 'COORDINADOR'),
          const AsignarSede('otra', 'CATEDRATICO'),
          const QuitarSede('vieja'),
        ],
      );
    });

    test('sin diferencias, nada que pedir', () {
      expect(
        cambiosDeSedes(
          <String, MembresiaDeseada>{
            'bdm': const MembresiaDeseada('CATEDRATICO', <String>{'a', 'b'}),
          },
          <String, MembresiaDeseada>{
            'bdm': const MembresiaDeseada('CATEDRATICO', <String>{'b', 'a'}),
          },
        ),
        isEmpty,
      );
    });

    test(
      '2.0.6: cambiar solo las facultades de una sede la pide, ordenadas',
      () {
        expect(
          cambiosDeSedes(
            <String, MembresiaDeseada>{
              'bdm': const MembresiaDeseada('CATEDRATICO', <String>{'a'}),
            },
            <String, MembresiaDeseada>{
              'bdm': const MembresiaDeseada('CATEDRATICO', <String>{'c', 'a'}),
            },
          ),
          <CambioDeSede>[
            const AsignarSede('bdm', 'CATEDRATICO', <String>['a', 'c']),
          ],
        );
      },
    );
  });

  test('un perfil de antes de la 2.0 está en bdm con su rol', () {
    expect(_ana.sedesConRol, <String, String>{'bdm': 'CATEDRATICO'});
  });

  testWidgets('poner a alguien en otra sede y darle un rol allí', (
    WidgetTester tester,
  ) async {
    final _RepoFalso repo = await _montar(tester);
    await tester.tap(find.text('Otra sede'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Textos.grupoGuardar));
    await tester.pumpAndSettle();
    expect(repo.llamadas, <String>['asignar otra CATEDRATICO']);
  });

  testWidgets('no se puede dejar a nadie sin sede', (
    WidgetTester tester,
  ) async {
    final _RepoFalso repo = await _montar(tester);
    await tester.tap(find.text('Boca del Monte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Textos.grupoGuardar));
    await tester.pumpAndSettle();
    expect(find.text(Textos.sedesAlMenosUna), findsOneWidget);
    expect(repo.llamadas, isEmpty);
  });

  testWidgets('la administración general ya no se da aquí: se da en Usuarios', (
    WidgetTester tester,
  ) async {
    await _montar(tester);
    expect(find.text(Textos.administracionGeneral), findsNothing);
  });

  testWidgets(
    'cambiar de sede (lo de María): se pide quitar la que deja, después de dar la nueva',
    (WidgetTester tester) async {
      // 2.0.5: el diálogo es el mismo para uno mismo y para otros; el
      // superadministrador también cambia sus propias sedes.
      final _RepoFalso repo = await _montar(tester);
      expect(find.text(Textos.grupoGuardar), findsOneWidget);
      await tester.tap(find.text('Otra sede'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Boca del Monte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Textos.grupoGuardar));
      await tester.pumpAndSettle();
      expect(repo.llamadas, <String>['asignar otra CATEDRATICO', 'quitar bdm']);
    },
  );

  testWidgets(
    '2.0.6: en cada sede elige sus facultades, solo entre las que la sede ofrece',
    (WidgetTester tester) async {
      final _RepoFalso repo = await _montar(tester);
      expect(
        find.text(Textos.facultadesEnSede('Boca del Monte')),
        findsOneWidget,
      );
      expect(find.text('Ingeniería en Sistemas'), findsOneWidget);
      expect(find.text('Psicología'), findsOneWidget);
      // Ya no la ofrece la sede, y Ana no la tiene: no aparece.
      expect(find.text('Derecho'), findsNothing);

      await tester.tap(find.text('Psicología'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Textos.grupoGuardar));
      await tester.pumpAndSettle();
      expect(repo.llamadas, <String>['asignar bdm CATEDRATICO psicologia']);
    },
  );

  testWidgets('una sede que no ofrece facultades lo dice', (
    WidgetTester tester,
  ) async {
    await _montar(tester);
    await tester.tap(find.text('Otra sede'));
    await tester.pumpAndSettle();
    expect(find.text(Textos.sedeSinFacultades('Otra sede')), findsOneWidget);
  });
}
