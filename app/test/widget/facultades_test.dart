/// Facultades en la aplicación (2.0 · RF-FAC-01 a RF-FAC-04).
///
/// Con menos de dos facultades no se pregunta nada (RF-FAC-04): con una sola,
/// «la facultad» es lo mismo que «todos». Con dos o más: enviar a una
/// facultad, ponerle facultad a un grupo y decir a cuáles pertenece cada uno.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_catalogos.dart';
import 'package:sian/application/proveedores_grupos.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/infrastructure/firebase/repositorio_administracion.dart';
import 'package:sian/infrastructure/firebase/repositorio_catalogos.dart';
import 'package:sian/infrastructure/firebase/repositorio_grupos.dart';
import 'package:sian/presentation/admin/seccion_grupos.dart';
import 'package:sian/presentation/admin/seccion_mensajes.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

const ElementoCatalogo _sistemas = ElementoCatalogo(
  id: 'ing-sistemas',
  nombre: 'Ingeniería en Sistemas',
  activa: true,
);
const ElementoCatalogo _derecho = ElementoCatalogo(
  id: 'derecho',
  nombre: 'Derecho',
  activa: true,
);
const ElementoCatalogo _cerrada = ElementoCatalogo(
  id: 'cerrada',
  nombre: 'Cerrada',
  activa: false,
);

void main() {
  group('al redactar (RF-FAC-02, RF-FAC-04)', () {
    late RepositorioSesionFalso sesion;
    late RepositorioEnvioFalso envio;

    setUp(() {
      sesion = RepositorioSesionFalso(
        inicial: SesionActiva(usuarioDePrueba(rol: Rol.coordinador)),
      );
      envio = RepositorioEnvioFalso(conteo: 2);
    });
    tearDown(() => sesion.cerrar());

    Future<void> montar(
      WidgetTester tester,
      List<ElementoCatalogo> facultades,
    ) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositorioSesionProvider.overrideWithValue(sesion),
            repositorioEnvioProvider.overrideWithValue(envio),
            fuenteFacultadesProvider.overrideWith(
              (Ref ref, String _) => FuenteCatalogoEnMemoria(facultades),
            ),
          ],
          child: MaterialApp(
            theme: TemaSian.claro(),
            home: const Scaffold(body: SeccionMensajes()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('con una sola facultad activa no se ofrece', (
      WidgetTester tester,
    ) async {
      await montar(tester, <ElementoCatalogo>[_sistemas, _cerrada]);
      expect(find.text(Textos.destinatariosFacultades), findsNothing);
    });

    testWidgets('con dos se ofrece, y el envío va a las facultades elegidas', (
      WidgetTester tester,
    ) async {
      await montar(tester, <ElementoCatalogo>[_sistemas, _derecho, _cerrada]);
      await tester.enterText(
        find.widgetWithText(TextFormField, Textos.etiquetaTituloMensaje),
        'Reunión',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, Textos.etiquetaCuerpoMensaje),
        'Mañana.',
      );
      await tester.tap(find.text(Textos.destinatariosFacultades));
      await tester.pumpAndSettle();
      // Solo las activas.
      expect(find.widgetWithText(FilterChip, 'Cerrada'), findsNothing);

      // Sin ninguna elegida no se envía, y se dice por qué.
      await tester.ensureVisible(find.text(Textos.botonEnviarAhora));
      await tester.tap(find.text(Textos.botonEnviarAhora));
      await tester.pump();
      expect(find.text(Textos.validacionElijeFacultad), findsOneWidget);
      expect(envio.vecesQueConto, 0);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'Derecho'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(Textos.botonEnviarAhora));
      await tester.tap(find.text(Textos.botonEnviarAhora));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final Map<String, Object?> mapa = envio.ultimosDestinatarios!.aMapa();
      expect(mapa['modo'], 'FACULTAD');
      expect(mapa['facultadesIds'], <String>['derecho']);
    });
  });

  group('grupos (RF-FAC-03)', () {
    Future<RepositorioGruposFalso> montarEditor(
      WidgetTester tester,
      List<ElementoCatalogo> facultades,
    ) async {
      final RepositorioGruposFalso grupos = RepositorioGruposFalso(
        personas: const <Elegible>[
          Elegible(uid: 'u1', nombre: 'Ana', correo: 'a@umg.edu.gt'),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositorioGruposProvider.overrideWithValue(grupos),
            fuenteFacultadesProvider.overrideWith(
              (Ref ref, String _) => FuenteCatalogoEnMemoria(facultades),
            ),
          ],
          child: MaterialApp(
            theme: TemaSian.claro(),
            home: const Scaffold(body: EditorGrupo()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return grupos;
    }

    testWidgets('con una facultad el editor no la pregunta', (
      WidgetTester tester,
    ) async {
      await montarEditor(tester, <ElementoCatalogo>[_sistemas]);
      expect(find.text(Textos.grupoFacultad), findsNothing);
    });

    testWidgets('con dos, el grupo se guarda con su facultad', (
      WidgetTester tester,
    ) async {
      final RepositorioGruposFalso grupos = await montarEditor(
        tester,
        <ElementoCatalogo>[_sistemas, _derecho],
      );
      expect(find.text(Textos.grupoFacultad), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, Textos.grupoNombre),
        'Docentes de Derecho',
      );
      await tester.tap(find.text(Textos.grupoSinFacultad));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Derecho').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Textos.grupoGuardar));
      await tester.pumpAndSettle();
      expect(grupos.ultimaFacultadId, 'derecho');
    });
  });

  group('la persona en la sede (RF-FAC-01, RF-SED-05)', () {
    const UsuarioVista vieja = UsuarioVista(
      uid: 'v',
      correo: 'v@umg.edu.gt',
      nombre: 'Vieja',
      rol: 'CATEDRATICO',
      activo: true,
      puedeEmitirUrgentes: false,
      recibeAvisos: true,
      puedeCrearRecurrentes: false,
    );
    const UsuarioVista dosSedes = UsuarioVista(
      uid: 'd',
      correo: 'd@umg.edu.gt',
      nombre: 'Dos',
      rol: 'COORDINADOR',
      activo: true,
      puedeEmitirUrgentes: false,
      recibeAvisos: false,
      puedeCrearRecurrentes: false,
      membresias: <String, Object?>{
        'bdm': <String, Object?>{
          'rol': 'COORDINADOR',
          'facultades': <Object?>['ing-sistemas'],
        },
        'otra': <String, Object?>{
          'rol': 'CATEDRATICO',
          'facultades': <Object?>[],
        },
      },
    );

    test('un perfil de antes de la 2.0 es de bdm con su rol', () {
      expect(vieja.perteneceA('bdm'), isTrue);
      expect(vieja.perteneceA('otra'), isFalse);
      expect(vieja.rolEn('bdm'), 'CATEDRATICO');
      expect(vieja.facultadesEn('bdm'), isEmpty);
    });

    test('con membresías: rol y facultades de cada sede', () {
      expect(dosSedes.perteneceA('otra'), isTrue);
      expect(dosSedes.perteneceA('tercera'), isFalse);
      expect(dosSedes.rolEn('otra'), 'CATEDRATICO');
      expect(dosSedes.rolEn('bdm'), 'COORDINADOR');
      expect(dosSedes.facultadesEn('bdm'), <String>['ing-sistemas']);
    });
  });
}
