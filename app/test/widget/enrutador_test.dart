/// Pruebas del enrutado por sesión y por rol.
///
/// Es el criterio de salida de la iteración 1.2 (documento 08) expresado como
/// prueba: «cuatro usuarios con roles distintos entran, ven exactamente lo que
/// su rol permite, y un correo no autorizado es rechazado».
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/domain/repositorios.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/presentation/admin/panel_admin.dart';
import 'package:sian/presentation/docente/bandeja_docente.dart';
import 'package:sian/presentation/shared/enrutador.dart';
import 'package:sian/presentation/shared/pantalla_ingreso.dart';
import 'package:sian/presentation/shared/pantalla_rechazo.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

void main() {
  late RepositorioSesionFalso sesionFalsa;
  late RepositorioBandejaFalso bandejaFalsa;

  setUp(() {
    sesionFalsa = RepositorioSesionFalso();
    bandejaFalsa = RepositorioBandejaFalso(const <MensajeRecibido>[]);
  });

  tearDown(() => sesionFalsa.cerrar());

  Widget montar(Sesion sesion) {
    sesionFalsa.emitir(sesion);
    // `pump()` posterior deja que el primer valor del stream llegue.
    return ProviderScope(
      overrides: [
        repositorioSesionProvider.overrideWithValue(sesionFalsa),
        repositorioBandejaProvider.overrideWithValue(bandejaFalsa),
      ],
      child: MaterialApp(theme: TemaSian.claro(), home: const Enrutador()),
    );
  }

  testWidgets('sin sesión muestra el formulario de ingreso', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(montar(const SesionAnonima()));
    await tester.pump();

    expect(find.byType(PantallaIngreso), findsOneWidget);
    expect(find.text(Textos.botonEntrar), findsOneWidget);
  });

  testWidgets('mientras se resuelve el token, no enseña nada más', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(montar(const SesionCargando()));
    await tester.pump();

    expect(find.text(Textos.verificandoSesion), findsOneWidget);
    // Lo importante es lo que NO aparece: nadie debe ver una pantalla de
    // sesión iniciada antes de que se sepa quién es.
    expect(find.byType(PanelAdmin), findsNothing);
    expect(find.byType(BandejaDocente), findsNothing);
    expect(find.byType(PantallaIngreso), findsNothing);
  });

  group('cada rol llega a su pantalla', () {
    testWidgets('el coordinador va al panel', (WidgetTester tester) async {
      await tester.pumpWidget(
        montar(SesionActiva(usuarioDePrueba(rol: Rol.coordinador))),
      );
      await tester.pump();

      expect(find.byType(PanelAdmin), findsOneWidget);
      expect(find.byType(BandejaDocente), findsNothing);
    });

    testWidgets('la administradora va al panel', (WidgetTester tester) async {
      await tester.pumpWidget(
        montar(SesionActiva(usuarioDePrueba(rol: Rol.administradora))),
      );
      await tester.pump();

      expect(find.byType(PanelAdmin), findsOneWidget);
    });

    testWidgets('el auditor va al panel', (WidgetTester tester) async {
      await tester.pumpWidget(
        montar(SesionActiva(usuarioDePrueba(rol: Rol.auditor))),
      );
      await tester.pump();

      expect(find.byType(PanelAdmin), findsOneWidget);
    });

    testWidgets('el catedrático va a su bandeja, no al panel', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(SesionActiva(usuarioDePrueba(rol: Rol.catedratico))),
      );
      await tester.pump();

      expect(find.byType(BandejaDocente), findsOneWidget);
      expect(find.byType(PanelAdmin), findsNothing);
    });
  });

  group('RF-AUT-03 · rechazo explicativo', () {
    testWidgets('correo fuera de la lista blanca', (WidgetTester tester) async {
      await tester.pumpWidget(
        montar(
          const SesionRechazada(
            motivo: MotivoRechazo.fueraDeListaBlanca,
            correo: 'ajeno@gmail.com',
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(PantallaRechazo), findsOneWidget);
      expect(find.text(Textos.rechazoNoAutorizadoTitulo), findsOneWidget);
      // El criterio de aceptación pide un rechazo EXPLICATIVO, no un portazo.
      expect(find.text(Textos.rechazoNoAutorizadoExplicacion), findsOneWidget);
      // Y que se vea con qué correo se intentó, para no adivinar.
      expect(find.text('ajeno@gmail.com'), findsOneWidget);
    });

    testWidgets('cuenta desactivada se distingue de no autorizada', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(
          const SesionRechazada(
            motivo: MotivoRechazo.cuentaDesactivada,
            correo: 'antiguo@umg.edu.gt',
          ),
        ),
      );
      await tester.pump();

      expect(find.text(Textos.rechazoDesactivadaTitulo), findsOneWidget);
      expect(find.text(Textos.rechazoNoAutorizadoTitulo), findsNothing);
    });

    testWidgets('token sin rol propone la salida correcta', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(
          const SesionRechazada(
            motivo: MotivoRechazo.sinRolEnElToken,
            correo: 'nuevo@umg.edu.gt',
          ),
        ),
      );
      await tester.pump();

      expect(find.text(Textos.rechazoSinRolTitulo), findsOneWidget);
      expect(find.text(Textos.rechazoSinRolSalida), findsOneWidget);
    });

    testWidgets('el rechazo SOBREVIVE a que la sesión desaparezca', (
      WidgetTester tester,
    ) async {
      // Regresión del fallo encontrado en la ronda 3.
      //
      // Al rechazar, el servidor BORRA la credencial recién creada para no
      // dejar cuentas huérfanas. Eso hace que el cliente pierda la sesión por
      // su cuenta, y la sesión anónima que llega detrás tapaba el rechazo
      // antes de que nadie lo leyera: parpadeo y vuelta al formulario.
      //
      // RF-AUT-03 exige un rechazo EXPLICATIVO. Si no se ve, no existe.
      await tester.pumpWidget(
        montar(
          const SesionRechazada(
            motivo: MotivoRechazo.fueraDeListaBlanca,
            correo: 'intruso@gmail.com',
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(PantallaRechazo), findsOneWidget);

      // El servidor borró la credencial: llega la sesión anónima.
      sesionFalsa.emitir(const SesionAnonima());
      await tester.pump();

      // Y aun así el aviso sigue en pantalla.
      expect(find.byType(PantallaRechazo), findsOneWidget);
      expect(find.text(Textos.rechazoNoAutorizadoTitulo), findsOneWidget);
      expect(find.byType(PantallaIngreso), findsNothing);
    });

    testWidgets('solo al reconocerlo se vuelve al formulario', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(
          const SesionRechazada(
            motivo: MotivoRechazo.fueraDeListaBlanca,
            correo: 'intruso@gmail.com',
          ),
        ),
      );
      await tester.pump();
      sesionFalsa.emitir(const SesionAnonima());
      await tester.pump();

      await tester.ensureVisible(find.text(Textos.botonVolverAIngreso));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Textos.botonVolverAIngreso));
      await tester.pumpAndSettle();

      expect(find.byType(PantallaIngreso), findsOneWidget);
      expect(find.byType(PantallaRechazo), findsNothing);
    });

    testWidgets('entrar de verdad limpia cualquier rechazo anterior', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(
          const SesionRechazada(
            motivo: MotivoRechazo.fueraDeListaBlanca,
            correo: 'intruso@gmail.com',
          ),
        ),
      );
      await tester.pump();

      sesionFalsa.emitir(SesionActiva(usuarioDePrueba(rol: Rol.coordinador)));
      await tester.pump();

      expect(find.byType(PanelAdmin), findsOneWidget);
      expect(find.byType(PantallaRechazo), findsNothing);
    });

    testWidgets('desde el rechazo se puede cerrar sesión', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(
          const SesionRechazada(
            motivo: MotivoRechazo.fueraDeListaBlanca,
            correo: 'ajeno@gmail.com',
          ),
        ),
      );
      await tester.pump();

      // El botón queda bajo el pliegue en la ventana de prueba: hay que
      // desplazarlo a la vista antes de pulsarlo, como haría una persona.
      await tester.ensureVisible(find.text(Textos.botonVolverAIngreso));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Textos.botonVolverAIngreso));
      await tester.pump();

      expect(sesionFalsa.vecesQueSalio, 1);
    });
  });
}
