/// Personas y sedes (2.0.1 · RF-SED-02, RF-SED-06).
///
/// La administración general pone a cada persona en sus sedes con su rol, y da
/// o quita la administración general. Nadie se cambia a sí mismo, y nadie se
/// queda sin sede.
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

class _RepoFalso extends RepositorioPersonasYSedes {
  final List<String> llamadas = <String>[];

  @override
  Future<void> asignarSede({
    required String uid,
    required String sedeId,
    required String rol,
  }) async => llamadas.add('asignar $sedeId $rol');

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
  required bool unoMismo,
  UsuarioVista persona = _ana,
}) async {
  final _RepoFalso repo = _RepoFalso();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [repositorioPersonasYSedesProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: Scaffold(
          body: DialogoSedes(
            persona: persona,
            sedes: _sedes,
            esUnoMismo: unoMismo,
          ),
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
          <String, String>{'bdm': 'CATEDRATICO', 'vieja': 'AUDITOR'},
          <String, String>{'bdm': 'COORDINADOR', 'otra': 'CATEDRATICO'},
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
          <String, String>{'bdm': 'CATEDRATICO'},
          <String, String>{'bdm': 'CATEDRATICO'},
        ),
        isEmpty,
      );
    });
  });

  test('un perfil de antes de la 2.0 está en bdm con su rol', () {
    expect(_ana.sedesConRol, <String, String>{'bdm': 'CATEDRATICO'});
  });

  testWidgets('poner a alguien en otra sede y darle un rol allí', (
    WidgetTester tester,
  ) async {
    final _RepoFalso repo = await _montar(tester, unoMismo: false);
    await tester.tap(find.text('Otra sede'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Textos.grupoGuardar));
    await tester.pumpAndSettle();
    expect(repo.llamadas, <String>['asignar otra CATEDRATICO']);
  });

  testWidgets('no se puede dejar a nadie sin sede', (
    WidgetTester tester,
  ) async {
    final _RepoFalso repo = await _montar(tester, unoMismo: false);
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
    await _montar(tester, unoMismo: false);
    expect(find.text(Textos.administracionGeneral), findsNothing);
  });

  testWidgets(
    'las propias sedes no se cambian: se dice por qué y no hay guardar',
    (WidgetTester tester) async {
      await _montar(tester, unoMismo: true);
      expect(find.text(Textos.sedesPropias), findsOneWidget);
      expect(find.text(Textos.grupoGuardar), findsNothing);
    },
  );
}
