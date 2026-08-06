/// Grupos de destinatarios — RF-USR-03, RF-USR-04, DT-08.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Un grupo decide a quién le llega una alerta de emergencia.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Por eso lo que aquí se prueba no es «se puede crear un grupo», sino lo que
/// impide un envío equivocado: que el número de miembros esté siempre a la
/// vista, que no se pueda guardar un grupo vacío, que desactivar no borre, y
/// que un grupo desactivado desaparezca de la lista al redactar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_grupos.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/infrastructure/firebase/repositorio_administracion.dart';
import 'package:sian/infrastructure/firebase/repositorio_grupos.dart';
import 'package:sian/presentation/admin/seccion_grupos.dart';
import 'package:sian/presentation/admin/seccion_mensajes.dart';
import 'package:sian/presentation/admin/seccion_usuarios.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

GrupoDetalle grupo({
  String id = 'g1',
  String nombre = 'Ingeniería',
  String descripcion = '',
  int miembros = 3,
  bool activo = true,
}) {
  return GrupoDetalle(
    id: id,
    nombre: nombre,
    descripcion: descripcion,
    miembros: List<String>.generate(miembros, (int i) => 'uid-$i'),
    activo: activo,
  );
}

UsuarioVista persona(
  String uid, {
  bool activo = true,
  String rol = 'CATEDRATICO',
  bool? recibeAvisos,
}) {
  return UsuarioVista(
    uid: uid,
    correo: '$uid@umg.edu.gt',
    nombre: 'Persona $uid',
    rol: rol,
    activo: activo,
    puedeEmitirUrgentes: false,
    puedeCrearRecurrentes: false,
    recibeAvisos: recibeAvisos ?? rol == 'CATEDRATICO',
  );
}

void main() {
  late RepositorioGruposFalso grupos;
  late RepositorioAdminFalso admin;

  setUp(() {
    grupos = RepositorioGruposFalso();
    admin = RepositorioAdminFalso();
  });

  Widget montarSeccion() => ProviderScope(
    overrides: [
      repositorioGruposProvider.overrideWithValue(grupos),
      repositorioAdminProvider.overrideWithValue(admin),
    ],
    child: MaterialApp(theme: TemaSian.claro(), home: const SeccionGrupos()),
  );

  group('lista de grupos', () {
    testWidgets('sin grupos explica para qué sirven', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montarSeccion());
      await tester.pump();

      expect(find.text(Textos.grupoNinguno), findsOneWidget);
    });

    testWidgets('el número de miembros está siempre a la vista', (
      WidgetTester tester,
    ) async {
      // Es el dato que evita enviar a veinte creyendo que van cuarenta y
      // cinco. Esconderlo tras un clic sería esconder justo lo que importa.
      grupos = RepositorioGruposFalso(
        grupos: <GrupoDetalle>[grupo(nombre: 'Ingeniería', miembros: 12)],
      );
      await tester.pumpWidget(montarSeccion());
      await tester.pump();

      expect(find.text('12'), findsOneWidget);
      expect(find.text(Textos.grupoMiembros(12)), findsOneWidget);
    });

    testWidgets('un grupo desactivado se ve, tachado y con su estado', (
      WidgetTester tester,
    ) async {
      // No se esconde: sigue existiendo para el historial, y ocultarlo haría
      // creer que se borró.
      grupos = RepositorioGruposFalso(
        grupos: <GrupoDetalle>[grupo(nombre: 'Antiguo', activo: false)],
      );
      await tester.pumpWidget(montarSeccion());
      await tester.pump();

      expect(find.text('Antiguo'), findsOneWidget);
      expect(find.text(Textos.grupoInactivo(3)), findsOneWidget);
    });

    testWidgets('avisa cuando un grupo roza el límite de DT-08', (
      WidgetTester tester,
    ) async {
      // Llegar a 200 y descubrirlo el día que hace falta agregar a alguien es
      // peor que saberlo con 50 de margen.
      grupos = RepositorioGruposFalso(
        grupos: <GrupoDetalle>[grupo(miembros: LimitesGrupo.umbralAviso)],
      );
      await tester.pumpWidget(montarSeccion());
      await tester.pump();

      expect(
        find.text(Textos.grupoRozaElLimite(LimitesGrupo.maxMiembros)),
        findsOneWidget,
      );
    });
  });

  group('RF-USR-04 · desactivar NO es borrar', () {
    testWidgets('pide confirmación y explica que se conserva', (
      WidgetTester tester,
    ) async {
      grupos = RepositorioGruposFalso(
        grupos: <GrupoDetalle>[grupo(nombre: 'Ingeniería')],
      );
      await tester.pumpWidget(montarSeccion());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.block));
      await tester.pumpAndSettle();

      expect(find.text(Textos.grupoDesactivarTitulo), findsOneWidget);
      expect(
        find.text(Textos.grupoDesactivarAviso('Ingeniería')),
        findsOneWidget,
      );
      expect(grupos.cambiosDeEstado, isEmpty);
    });

    testWidgets('cancelar no cambia nada', (WidgetTester tester) async {
      grupos = RepositorioGruposFalso(grupos: <GrupoDetalle>[grupo()]);
      await tester.pumpWidget(montarSeccion());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.block));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Textos.botonCancelar));
      await tester.pumpAndSettle();

      expect(grupos.cambiosDeEstado, isEmpty);
    });

    testWidgets('confirmar desactiva', (WidgetTester tester) async {
      grupos = RepositorioGruposFalso(grupos: <GrupoDetalle>[grupo(id: 'g7')]);
      await tester.pumpWidget(montarSeccion());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.block));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, Textos.grupoDesactivar),
      );
      await tester.pumpAndSettle();

      expect(grupos.cambiosDeEstado, <({String grupoId, bool activo})>[
        (grupoId: 'g7', activo: false),
      ]);
    });

    testWidgets('reactivar no pide confirmación: no destruye nada', (
      WidgetTester tester,
    ) async {
      grupos = RepositorioGruposFalso(
        grupos: <GrupoDetalle>[grupo(id: 'g7', activo: false)],
      );
      await tester.pumpWidget(montarSeccion());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();

      expect(grupos.cambiosDeEstado, <({String grupoId, bool activo})>[
        (grupoId: 'g7', activo: true),
      ]);
    });
  });

  group('RF-USR-03 · editor', () {
    Widget montarEditor({GrupoDetalle? existente}) => ProviderScope(
      overrides: [
        repositorioGruposProvider.overrideWithValue(grupos),
        repositorioAdminProvider.overrideWithValue(admin),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: Scaffold(body: EditorGrupo(grupo: existente)),
      ),
    );

    testWidgets('un grupo sin nombre no se guarda', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montarEditor());
      await tester.pumpAndSettle();

      await tester.tap(find.text(Textos.grupoGuardar));
      await tester.pumpAndSettle();

      expect(find.text(Textos.grupoValidacionNombre), findsOneWidget);
      expect(grupos.vecesQueGuardo, 0);
    });

    testWidgets('un grupo VACÍO tampoco', (WidgetTester tester) async {
      // No es un error de sintaxis, es una trampa: al redactar mostraría
      // «llegará a 0 personas» y el envío se rechazaría.
      admin = RepositorioAdminFalso(usuarios: <UsuarioVista>[persona('a')]);
      await tester.pumpWidget(montarEditor());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, Textos.grupoNombre),
        'Ingeniería',
      );
      await tester.tap(find.text(Textos.grupoGuardar));
      await tester.pumpAndSettle();

      expect(find.text(Textos.grupoValidacionSinMiembros), findsOneWidget);
      expect(grupos.vecesQueGuardo, 0);
    });

    testWidgets('con nombre y gente, guarda', (WidgetTester tester) async {
      admin = RepositorioAdminFalso(
        usuarios: <UsuarioVista>[persona('a'), persona('b')],
      );
      await tester.pumpWidget(montarEditor());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, Textos.grupoNombre),
        'Ingeniería',
      );
      await tester.tap(find.text('Persona a'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Textos.grupoGuardar));
      await tester.pumpAndSettle();

      expect(grupos.vecesQueGuardo, 1);
      expect(grupos.ultimoNombre, 'Ingeniería');
      expect(grupos.ultimosMiembros, <String>['a']);
      // Sin identificador: es un grupo nuevo, no una modificación.
      expect(grupos.ultimoGrupoId, isNull);
    });

    testWidgets('editar uno existente conserva su identificador', (
      WidgetTester tester,
    ) async {
      admin = RepositorioAdminFalso(usuarios: <UsuarioVista>[persona('a')]);
      await tester.pumpWidget(
        montarEditor(
          existente: const GrupoDetalle(
            id: 'g9',
            nombre: 'Antiguo',
            descripcion: '',
            miembros: <String>['a'],
            activo: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(Textos.grupoGuardar));
      await tester.pumpAndSettle();

      expect(grupos.ultimoGrupoId, 'g9');
    });

    testWidgets('no se puede agrupar a una cuenta desactivada', (
      WidgetTester tester,
    ) async {
      // Meterla no daría error, pero al enviar quedaría excluida y el conteo
      // no cuadraría con lo que la lista prometía.
      admin = RepositorioAdminFalso(
        usuarios: <UsuarioVista>[persona('a'), persona('b', activo: false)],
      );
      await tester.pumpWidget(montarEditor());
      await tester.pumpAndSettle();

      expect(find.text('Persona a'), findsOneWidget);
      expect(find.text('Persona b'), findsNothing);
    });

    testWidgets('el auditor tampoco es agrupable: no recibe mensajes', (
      WidgetTester tester,
    ) async {
      admin = RepositorioAdminFalso(
        usuarios: <UsuarioVista>[
          persona('a'),
          persona('z', rol: 'AUDITOR'),
        ],
      );
      await tester.pumpWidget(montarEditor());
      await tester.pumpAndSettle();

      expect(find.text('Persona z'), findsNothing);
    });

    testWidgets('la búsqueda filtra por nombre y correo', (
      WidgetTester tester,
    ) async {
      admin = RepositorioAdminFalso(
        usuarios: <UsuarioVista>[persona('ana'), persona('beto')],
      );
      await tester.pumpWidget(montarEditor());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, Textos.grupoBuscar),
        'beto',
      );
      await tester.pumpAndSettle();

      expect(find.text('Persona beto'), findsOneWidget);
      expect(find.text('Persona ana'), findsNothing);
    });
  });

  group('al redactar solo se ofrecen los grupos ACTIVOS', () {
    testWidgets('un grupo desactivado no aparece como destinatario', (
      WidgetTester tester,
    ) async {
      // Ofrecerlo sería tender la trampa: el servidor rechaza el envío a un
      // grupo inactivo.
      final RepositorioSesionFalso sesion = RepositorioSesionFalso();
      addTearDown(sesion.cerrar);
      sesion.emitir(SesionActiva(usuarioDePrueba(rol: Rol.coordinador)));

      grupos = RepositorioGruposFalso(
        grupos: <GrupoDetalle>[
          grupo(id: 'vivo', nombre: 'Vigente'),
          grupo(id: 'muerto', nombre: 'Retirado', activo: false),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositorioSesionProvider.overrideWithValue(sesion),
            repositorioGruposProvider.overrideWithValue(grupos),
            repositorioEnvioProvider.overrideWithValue(RepositorioEnvioFalso()),
          ],
          child: MaterialApp(
            theme: TemaSian.claro(),
            home: const Scaffold(body: SeccionMensajes()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder opcion = find.text(Textos.destinatariosGrupos);
      await tester.ensureVisible(opcion);
      await tester.pumpAndSettle();
      await tester.tap(opcion);
      await tester.pumpAndSettle();

      expect(find.textContaining('Vigente'), findsOneWidget);
      expect(find.textContaining('Retirado'), findsNothing);
    });
  });
}
