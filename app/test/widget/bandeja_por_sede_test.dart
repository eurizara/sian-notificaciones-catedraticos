/// El catedrático en varias sedes (2.0.8).
///
/// Pedido del responsable el 14/11/2026: quien está en más de una sede o
/// facultad tiene que ver en su aplicación en qué sede está, y los avisos que
/// se le muestran tienen que respetarlo. Lo de las otras sedes no se esconde:
/// se dice cuánto hay y se cambia de un toque, y una notificación de otra
/// sede lleva a ella.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_catalogos.dart';
import 'package:sian/application/proveedores_programacion.dart';
import 'package:sian/application/proveedores_respuestas.dart';
import 'package:sian/application/proveedores_sede.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/domain/repositorios.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/infrastructure/firebase/repositorio_catalogos.dart';
import 'package:sian/presentation/docente/bandeja_docente.dart';
import 'package:sian/presentation/docente/sede_en_bandeja.dart';
import 'package:sian/presentation/shared/apertura.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

const UsuarioSesion _dosSedes = UsuarioSesion(
  uid: 'maria',
  correo: 'maria@umg.edu.gt',
  nombre: 'María',
  rol: Rol.catedratico,
  activo: true,
  sedes: <String, Rol>{'bdm': Rol.catedratico, 'villa-nueva': Rol.catedratico},
);

MensajeRecibido _aviso(
  String id,
  String titulo,
  String sede, {
  bool urgente = false,
  List<String> facultades = const <String>[],
}) => MensajeRecibido(
  mensajeId: id,
  titulo: titulo,
  cuerpo: 'Cuerpo.',
  tipo: urgente ? 'URGENTE' : 'INFORMATIVO',
  estado: 'ENTREGADO',
  requiereConfirmacion: urgente,
  entregadoEn: DateTime.utc(2026, 11, 14, 13),
  sedeId: sede,
  facultadesDestino: facultades,
);

final List<MensajeRecibido> _avisos = <MensajeRecibido>[
  _aviso('a1', 'Claustro en Boca del Monte', 'bdm'),
  _aviso(
    'a2',
    'Simulacro en Villa Nueva',
    'villa-nueva',
    urgente: true,
    facultades: <String>['psicologia'],
  ),
];

Future<ProviderContainer> _montar(
  WidgetTester tester, {
  UsuarioSesion usuario = _dosSedes,
}) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositorioSesionProvider.overrideWithValue(RepositorioSesionFalso()),
        sesionActualProvider.overrideWithValue(SesionActiva(usuario)),
        repositorioBandejaProvider.overrideWithValue(
          RepositorioBandejaFalso(_avisos),
        ),
        repositorioProgramacionProvider.overrideWithValue(
          RepositorioProgramacionFalso(),
        ),
        repositorioRespuestasProvider.overrideWithValue(
          RepositorioRespuestasFalso(),
        ),
        nombreDeSedeProvider.overrideWith(
          (Ref ref, String id) async =>
              id == 'bdm' ? 'Boca del Monte' : 'Villa Nueva',
        ),
        misFacultadesProvider.overrideWith(
          (Ref ref, ({String uid, String sede}) c) =>
              Stream<List<String>>.value(
                c.sede == 'bdm'
                    ? const <String>['ing-sistemas', 'psicologia']
                    : const <String>['psicologia'],
              ),
        ),
        fuenteFacultadesProvider.overrideWith(
          (Ref ref, String _) => FuenteCatalogoEnMemoria(<ElementoCatalogo>[
            const ElementoCatalogo(
              id: 'ing-sistemas',
              nombre: 'Ingeniería en Sistemas',
              activa: true,
            ),
            const ElementoCatalogo(
              id: 'psicologia',
              nombre: 'Psicología',
              activa: true,
            ),
          ]),
        ),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: BandejaDocente(usuario: usuario),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(BandejaDocente)));
}

void main() {
  testWidgets(
    'en el teléfono se ve en qué sede está y con qué facultades, y solo sus avisos',
    (WidgetTester tester) async {
      await _montar(tester);
      expect(find.text(Textos.estaEnSede('Boca del Monte')), findsOneWidget);
      expect(
        find.text(
          Textos.susFacultades(<String>[
            'Ingeniería en Sistemas',
            'Psicología',
          ]),
        ),
        findsOneWidget,
      );
      expect(find.text('Claustro en Boca del Monte'), findsOneWidget);
      expect(find.text('Simulacro en Villa Nueva'), findsNothing);
    },
  );

  testWidgets(
    'lo de la otra sede no se esconde: se dice, con la urgente, y se va de un toque',
    (WidgetTester tester) async {
      await _montar(tester);
      final String pendiente = Textos.pendienteEnOtraSede(
        'Villa Nueva',
        sinLeer: 1,
        urgentes: 1,
      );
      expect(find.text(pendiente), findsOneWidget);

      await tester.tap(find.text(pendiente));
      await tester.pumpAndSettle();
      expect(find.text(Textos.estaEnSede('Villa Nueva')), findsOneWidget);
      expect(find.text('Simulacro en Villa Nueva'), findsOneWidget);
      expect(find.text('Claustro en Boca del Monte'), findsNothing);
      // Por qué facultad le llegó.
      expect(
        find.text(Textos.paraFacultades(<String>['Psicología'])),
        findsOneWidget,
      );
    },
  );

  testWidgets('una notificación de otra sede la lleva a esa sede', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = await _montar(tester);
    c
        .read(aperturaPendienteProvider.notifier)
        .fijar(const DestinoApertura.aviso('a2'));
    await tester.pumpAndSettle();
    expect(c.read(sedeDeTrabajoProvider), 'villa-nueva');
    expect(find.text('Simulacro en Villa Nueva'), findsOneWidget);
  });

  testWidgets('con una sola sede y una facultad no hay nada que aclarar', (
    WidgetTester tester,
  ) async {
    await _montar(
      tester,
      usuario: const UsuarioSesion(
        uid: 'uno',
        correo: 'uno@umg.edu.gt',
        nombre: 'Uno',
        rol: Rol.catedratico,
        activo: true,
        sedes: <String, Rol>{'villa-nueva': Rol.catedratico},
      ),
    );
    expect(find.byType(SedeEnBandeja), findsOneWidget);
    expect(find.text(Textos.estaEnSede('Villa Nueva')), findsNothing);
    expect(find.text('Simulacro en Villa Nueva'), findsOneWidget);
  });

  test('lo pendiente en las otras sedes', () {
    expect(
      pendientesEnOtrasSedes(<String>['bdm', 'villa-nueva'], 'bdm', _avisos),
      <PendienteEnSede>[(sede: 'villa-nueva', sinLeer: 1, urgentes: 1)],
    );
    expect(
      pendientesEnOtrasSedes(
        <String>['bdm', 'villa-nueva'],
        'villa-nueva',
        _avisos,
      ),
      <PendienteEnSede>[(sede: 'bdm', sinLeer: 1, urgentes: 0)],
    );
  });
}
