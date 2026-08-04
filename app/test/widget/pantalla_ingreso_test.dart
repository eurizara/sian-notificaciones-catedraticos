/// Pruebas del formulario de ingreso — RF-AUT-02.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/presentation/shared/pantalla_ingreso.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

void main() {
  late RepositorioSesionFalso sesion;

  setUp(() => sesion = RepositorioSesionFalso());
  tearDown(() => sesion.cerrar());

  Widget montar() => ProviderScope(
    overrides: [repositorioSesionProvider.overrideWithValue(sesion)],
    child: MaterialApp(
      theme: TemaSian.claro(),
      home: const PantallaIngreso(),
    ),
  );

  Finder campoCorreo() => find.widgetWithText(TextFormField, Textos.etiquetaCorreo);
  Finder campoContrasena() =>
      find.widgetWithText(TextFormField, Textos.etiquetaContrasena);

  testWidgets('el cursor arranca en el correo', (WidgetTester tester) async {
    await tester.pumpWidget(montar());
    await tester.pump();

    final EditableText correo = tester.widget<EditableText>(
      find.descendant(of: campoCorreo(), matching: find.byType(EditableText)),
    );
    expect(correo.focusNode.hasFocus, isTrue);
  });

  testWidgets('valida antes de intentar entrar', (WidgetTester tester) async {
    await tester.pumpWidget(montar());
    await tester.pump();

    // Con el botón de Google la pantalla creció y el de entrar queda bajo el
    // pliegue en la ventana de prueba: hay que desplazarlo, como haría una
    // persona.
    await tester.ensureVisible(find.text(Textos.botonEntrar));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Textos.botonEntrar));
    await tester.pump();

    expect(find.text(Textos.validacionCorreoObligatorio), findsOneWidget);
    expect(find.text(Textos.validacionContrasenaObligatoria), findsOneWidget);
    // No llegó a intentarse nada contra el servidor.
    expect(sesion.correosIntentados, isEmpty);
  });

  group('tras credenciales incorrectas', () {
    Future<void> intentarConMalas(WidgetTester tester) async {
      await tester.pumpWidget(montar());
      await tester.pump();

      await tester.enterText(campoCorreo(), 'alguien@umg.edu.gt');
      await tester.enterText(campoContrasena(), 'ContraseñaMala#1');
      await tester.ensureVisible(find.text(Textos.botonEntrar));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Textos.botonEntrar));
      await tester.pumpAndSettle();
    }

    testWidgets('avisa sin revelar si el correo existe', (
      WidgetTester tester,
    ) async {
      await intentarConMalas(tester);

      // Distinguir «no existe» de «contraseña incorrecta» permitiría averiguar
      // quién tiene cuenta probando correos uno a uno.
      expect(find.textContaining('no existe'), findsNothing);
      expect(find.textContaining('no está registrado'), findsNothing);
    });

    testWidgets('borra los dos campos', (WidgetTester tester) async {
      await intentarConMalas(tester);

      // Los dos, no solo la contraseña: estos equipos son compartidos, y dejar
      // el correo de la persona anterior en pantalla le dice al siguiente
      // quién estuvo ahí.
      final EditableText correo = tester.widget<EditableText>(
        find.descendant(of: campoCorreo(), matching: find.byType(EditableText)),
      );
      final EditableText contrasena = tester.widget<EditableText>(
        find.descendant(of: campoContrasena(), matching: find.byType(EditableText)),
      );

      expect(correo.controller.text, isEmpty);
      expect(contrasena.controller.text, isEmpty);
    });

    testWidgets('devuelve el cursor al correo', (WidgetTester tester) async {
      await intentarConMalas(tester);

      final EditableText correo = tester.widget<EditableText>(
        find.descendant(of: campoCorreo(), matching: find.byType(EditableText)),
      );
      expect(correo.focusNode.hasFocus, isTrue);
    });

    testWidgets('el mensaje de error sigue visible tras limpiar', (
      WidgetTester tester,
    ) async {
      // Limpiar los campos no puede llevarse por delante la explicación: sin
      // ella, la pantalla se vaciaría sin decir por qué.
      await intentarConMalas(tester);
      expect(find.text(Textos.errorInesperado), findsOneWidget);
    });
  });
}
