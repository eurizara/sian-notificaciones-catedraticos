/// Administración general desde Usuarios (2.0.2).
///
/// La da la coordinación, solo a quien coordina, y nunca a sí misma. El
/// servidor lo vuelve a comprobar (`motivoParaNoCambiarAdminGeneral`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_catalogos.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/infrastructure/firebase/repositorio_administracion.dart';
import 'package:sian/infrastructure/firebase/repositorio_catalogos.dart';
import 'package:sian/presentation/admin/seccion_usuarios.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

UsuarioVista _persona(
  String uid,
  String nombre,
  String rol, {
  bool adminGeneral = false,
}) => UsuarioVista(
  uid: uid,
  correo: '$uid@umg.edu.gt',
  nombre: nombre,
  rol: rol,
  activo: true,
  puedeEmitirUrgentes: false,
  recibeAvisos: rol == 'CATEDRATICO',
  puedeCrearRecurrentes: false,
  adminGeneral: adminGeneral,
);

Future<RepositorioAdminFalso> _montar(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final RepositorioAdminFalso admin = RepositorioAdminFalso(
    usuarios: <UsuarioVista>[
      _persona('yo', 'Yo Mismo', 'COORDINADOR', adminGeneral: true),
      _persona('beto', 'Beto Coordinador', 'COORDINADOR'),
      _persona('carla', 'Carla Catedrática', 'CATEDRATICO'),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositorioAdminProvider.overrideWithValue(admin),
        sesionActualProvider.overrideWithValue(
          SesionActiva(usuarioDePrueba(rol: Rol.coordinador, uid: 'yo')),
        ),
        fuenteFacultadesProvider.overrideWith(
          (Ref ref, String _) => FuenteCatalogoEnMemoria(<ElementoCatalogo>[]),
        ),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: const Scaffold(body: SeccionUsuarios()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(Textos.pestanaUsuarios));
  await tester.pumpAndSettle();
  return admin;
}

SwitchListTile _interruptor(WidgetTester tester) =>
    tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, Textos.administracionGeneral),
    );

void main() {
  testWidgets('la coordinación se la da a otro coordinador', (
    WidgetTester tester,
  ) async {
    final RepositorioAdminFalso admin = await _montar(tester);
    await tester.tap(find.text('Beto Coordinador'));
    await tester.pumpAndSettle();
    expect(_interruptor(tester).onChanged, isNotNull);
    await tester.tap(
      find.widgetWithText(SwitchListTile, Textos.administracionGeneral),
    );
    await tester.pumpAndSettle();
    expect(admin.cambiosAdminGeneral.single, (uid: 'beto', valor: true));
  });

  testWidgets('a quien no coordina no se le da, y se dice por qué', (
    WidgetTester tester,
  ) async {
    await _montar(tester);
    await tester.tap(find.text('Carla Catedrática'));
    await tester.pumpAndSettle();
    expect(_interruptor(tester).onChanged, isNull);
    expect(find.text(Textos.adminGeneralSoloCoordinadores), findsOneWidget);
  });

  testWidgets('la propia no se cambia', (WidgetTester tester) async {
    await _montar(tester);
    await tester.tap(find.text('Yo Mismo'));
    await tester.pumpAndSettle();
    expect(_interruptor(tester).onChanged, isNull);
    expect(find.text(Textos.adminGeneralPropia), findsOneWidget);
  });
}
