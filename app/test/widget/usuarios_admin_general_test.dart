/// Superadministrador y sedes desde Usuarios (2.0.4).
///
/// Todo lo de una persona se maneja en Usuarios. Sus sedes y si es
/// superadministrador, solo lo ve y lo cambia un superadministrador: la
/// coordinación no pone a nadie en otra sede. Nunca a sí mismo ni a un
/// catedrático; el servidor tampoco deja retirar al último.
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
  Map<String, Object?> membresias = const <String, Object?>{},
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
  membresias: membresias,
);

Future<RepositorioAdminFalso> _montar(
  WidgetTester tester, {
  required bool superadministrador,
}) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final RepositorioAdminFalso admin = RepositorioAdminFalso(
    usuarios: <UsuarioVista>[
      _persona(
        'yo',
        'Yo Mismo',
        'COORDINADOR',
        adminGeneral: superadministrador,
      ),
      _persona('beto', 'Beto Coordinador', 'COORDINADOR'),
      _persona('carla', 'Carla Catedrática', 'CATEDRATICO'),
      _persona('dina', 'Dina Administradora', 'ADMINISTRADORA'),
      _persona(
        'eva',
        'Eva de Otra Sede',
        'CATEDRATICO',
        membresias: <String, Object?>{
          'otra': <String, Object?>{
            'rol': 'CATEDRATICO',
            'facultades': <Object?>[],
          },
        },
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositorioAdminProvider.overrideWithValue(admin),
        sesionActualProvider.overrideWithValue(
          SesionActiva(
            UsuarioSesion(
              uid: 'yo',
              correo: 'yo@umg.edu.gt',
              nombre: 'Yo Mismo',
              rol: Rol.coordinador,
              activo: true,
              adminGeneral: superadministrador,
            ),
          ),
        ),
        fuenteFacultadesProvider.overrideWith(
          (Ref ref, String _) => FuenteCatalogoEnMemoria(<ElementoCatalogo>[]),
        ),
        fuenteSedesProvider.overrideWithValue(
          FuenteCatalogoEnMemoria(<ElementoCatalogo>[
            const ElementoCatalogo(
              id: 'bdm',
              nombre: 'Boca del Monte',
              activa: true,
            ),
            const ElementoCatalogo(
              id: 'otra',
              nombre: 'Otra sede',
              activa: true,
            ),
          ]),
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
  group('un superadministrador', () {
    testWidgets('designa a quien decida que use el panel', (
      WidgetTester tester,
    ) async {
      final RepositorioAdminFalso admin = await _montar(
        tester,
        superadministrador: true,
      );
      await tester.tap(find.text('Dina Administradora'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, Textos.administracionGeneral),
      );
      await tester.pumpAndSettle();
      expect(admin.cambiosAdminGeneral.single, (uid: 'dina', valor: true));
    });

    testWidgets('a un catedrático no: no tiene panel, y se dice por qué', (
      WidgetTester tester,
    ) async {
      await _montar(tester, superadministrador: true);
      await tester.tap(find.text('Carla Catedrática'));
      await tester.pumpAndSettle();
      expect(_interruptor(tester).onChanged, isNull);
      expect(find.text(Textos.adminGeneralSinPanel), findsOneWidget);
    });

    testWidgets('el propio no se cambia', (WidgetTester tester) async {
      await _montar(tester, superadministrador: true);
      await tester.tap(find.text('Yo Mismo'));
      await tester.pumpAndSettle();
      expect(_interruptor(tester).onChanged, isNull);
      expect(find.text(Textos.adminGeneralPropia), findsOneWidget);
    });

    testWidgets(
      'cambia sus propias sedes, como sus facultades (2.0.5); no su rol de superadministrador',
      (WidgetTester tester) async {
        await _montar(tester, superadministrador: true);
        await tester.tap(find.text('Yo Mismo'));
        await tester.pumpAndSettle();
        expect(find.text(Textos.usuarioSedes), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.widgetWithText(ListTile, Textos.usuarioSedes),
            matching: find.text(Textos.usuarioCambiar),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(Textos.sedesDe('Yo Mismo')), findsOneWidget);
        final FilledButton guardar = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, Textos.grupoGuardar),
        );
        expect(guardar.onPressed, isNotNull);
      },
    );

    testWidgets(
      've las sedes de cada persona y puede ver a la gente de todas las sedes',
      (WidgetTester tester) async {
        await _montar(tester, superadministrador: true);
        expect(
          find.text('Eva de Otra Sede'),
          findsNothing,
          reason: 'por omisión, la sede de trabajo',
        );
        await tester.tap(find.text('Beto Coordinador'));
        await tester.pumpAndSettle();
        expect(find.text(Textos.usuarioSedes), findsOneWidget);

        await tester.tap(find.text(Textos.usuariosTodasLasSedes));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eva de Otra Sede'));
        await tester.pumpAndSettle();
        // De otra sede: solo sus sedes; su rol y facultades de aquí no existen.
        expect(find.text('Otra sede · Catedrático'), findsOneWidget);
      },
    );
  });

  group('la coordinación sin ser superadministrador', () {
    testWidgets('no ve ni designa superadministradores, ni cambia sedes', (
      WidgetTester tester,
    ) async {
      await _montar(tester, superadministrador: false);
      expect(find.text(Textos.usuariosTodasLasSedes), findsNothing);
      await tester.tap(find.text('Beto Coordinador'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(SwitchListTile, Textos.administracionGeneral),
        findsNothing,
      );
      expect(find.text(Textos.usuarioSedes), findsNothing);
    });

    testWidgets(
      'tampoco cambia sus propias sedes: eso es del superadministrador',
      (WidgetTester tester) async {
        await _montar(tester, superadministrador: false);
        await tester.tap(find.text('Yo Mismo'));
        await tester.pumpAndSettle();
        expect(find.text(Textos.usuarioSedes), findsNothing);
      },
    );
  });
}
