/// Alcance: retirar un registro y recordar a quien sigue atrasado (1.6).
///
/// El 16/09/2026 hubo que borrar a mano nueve registros viejos en producción y
/// redactar el recordatorio copiando nombres. Esto lo pone en la pantalla.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/infrastructure/firebase/repositorio_canal.dart';
import 'package:sian/infrastructure/firebase/repositorio_envio.dart';
import 'package:sian/presentation/admin/borrador_prefijado.dart';
import 'package:sian/presentation/admin/seccion_canal.dart';
import 'package:sian/presentation/admin/seccion_mensajes.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';
import 'package:sian/presentation/shared/version_app.dart';

import '../dobles/repositorios_falsos.dart';

class _CanalFalso extends RepositorioCanal {
  final List<(String, String)> retirados = <(String, String)>[];

  @override
  Future<void> retirar({required String uid, required String dispositivoId}) async {
    retirados.add((uid, dispositivoId));
  }
}

final RevisionDeCanal revision = RevisionDeCanal(
  total: 0,
  catedraticos: 2,
  personas: const <PersonaSinCanal>[],
  versiones: <VersionesDePersona>[
    VersionesDePersona(
      uid: 'beto',
      nombre: 'Beto Ruiz',
      correo: 'b@umg',
      aparatos: <AparatoConVersion>[
        AparatoConVersion(
          id: 'ins_beto',
          plataforma: 'WEB_ANDROID',
          navegador: 'Chrome',
          versionApp: '1.6.0',
          ultimaActividad: DateTime(2026, 9, 20),
        ),
      ],
    ),
    VersionesDePersona(
      uid: 'ana',
      nombre: 'Ana López',
      correo: 'a@umg',
      aparatos: <AparatoConVersion>[
        AparatoConVersion(
          id: 'ins_nuevo',
          plataforma: 'WEB_IOS',
          navegador: 'Safari',
          versionApp: '1.6.7',
          ultimaActividad: DateTime(2026, 9, 25),
        ),
        AparatoConVersion(
          id: 'ins_viejo',
          plataforma: 'WEB_IOS',
          navegador: 'Safari',
          versionApp: '',
          ultimaActividad: DateTime(2026, 8, 28),
        ),
      ],
    ),
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
  late _CanalFalso canal;
  setUp(() => canal = _CanalFalso());

  Future<ProviderContainer> montar(WidgetTester tester, Rol rol) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final RepositorioSesionFalso sesion = RepositorioSesionFalso(
      inicial: SesionActiva(usuarioDePrueba(rol: rol)),
    );
    addTearDown(sesion.cerrar);
    final ProviderContainer c = ProviderContainer(
      overrides: [
        repositorioSesionProvider.overrideWithValue(sesion),
        repositorioCanalProvider.overrideWithValue(canal),
        revisionDeCanalProvider.overrideWith((Ref ref) async => revision),
        versionPublicadaProvider.overrideWith((Ref ref) async => '1.6.7'),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: TemaSian.claro(),
          home: const Scaffold(body: SeccionCanal()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await desplegarListas(tester);
    return c;
  }

  testWidgets('coordinación retira un registro, con confirmación', (
    WidgetTester tester,
  ) async {
    await montar(tester, Rol.coordinador);
    await tester.tap(find.byTooltip(Textos.retirarRegistro).first);
    await tester.pumpAndSettle();
    expect(find.text(Textos.retirarTitulo), findsOneWidget);

    await tester.tap(find.text(Textos.botonRetirar));
    await tester.pumpAndSettle();
    expect(canal.retirados, <(String, String)>[('beto', 'ins_beto')]);
    expect(find.text(Textos.registroRetirado), findsOneWidget);
  });

  testWidgets('cancelar no retira nada', (WidgetTester tester) async {
    await montar(tester, Rol.coordinador);
    await tester.tap(find.byTooltip(Textos.retirarRegistro).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(Textos.botonCancelar));
    await tester.pumpAndSettle();
    expect(canal.retirados, isEmpty);
  });

  testWidgets('los registros reemplazados se pueden ver y retirar', (
    WidgetTester tester,
  ) async {
    await montar(tester, Rol.coordinador);
    await tester.tap(find.text(Textos.verReemplazados));
    await tester.pumpAndSettle();
    // Beto (atrasado) y el registro viejo de Ana.
    expect(find.byTooltip(Textos.retirarRegistro), findsNWidgets(2));
  });

  testWidgets('la administradora ve Alcance pero no puede retirar', (
    WidgetTester tester,
  ) async {
    await montar(tester, Rol.administradora);
    expect(find.byTooltip(Textos.retirarRegistro), findsNothing);
    expect(find.text(Textos.verReemplazados), findsNothing);
    // Recordar sí: también redacta.
    expect(find.text(Textos.botonRecordarVersion(1)), findsOneWidget);
  });

  testWidgets('«Enviar recordatorio» deja el aviso preparado para quien está atrasado', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = await montar(tester, Rol.coordinador);
    await tester.tap(find.text(Textos.botonRecordarVersion(1)));
    await tester.pump();

    final BorradorPrefijado b = c.read(borradorPrefijadoProvider)!;
    expect(b.personas.map((PersonaDestinataria p) => p.uid), <String>['beto']);
    expect(b.titulo, Textos.recordatorioTitulo);
    expect(b.cuerpo, contains('SIAN 1.6.7'));
  });

  testWidgets('el formulario recoge el borrador: personas elegidas y el texto', (
    WidgetTester tester,
  ) async {
    final RepositorioSesionFalso sesion = RepositorioSesionFalso(
      inicial: SesionActiva(usuarioDePrueba(rol: Rol.coordinador)),
    );
    addTearDown(sesion.cerrar);
    final ProviderContainer c = ProviderContainer(
      overrides: [
        repositorioSesionProvider.overrideWithValue(sesion),
        repositorioEnvioProvider.overrideWithValue(RepositorioEnvioFalso()),
      ],
    );
    addTearDown(c.dispose);
    c.read(borradorPrefijadoProvider.notifier).preparar(
      const BorradorPrefijado(
        personas: <PersonaDestinataria>[
          PersonaDestinataria(uid: 'beto', nombre: 'Beto Ruiz', correo: 'b@umg'),
        ],
        titulo: 'Recordatorio',
        cuerpo: 'Actualice.',
      ),
    );
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: TemaSian.claro(),
          home: const Scaffold(body: SeccionMensajes()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, 'Beto Ruiz'), findsOneWidget);
    expect(find.text('Recordatorio'), findsOneWidget);
    expect(find.text('Actualice.'), findsOneWidget);
    expect(c.read(borradorPrefijadoProvider), isNull, reason: 'se toma una vez');
  });
}
