/// Pruebas de la ronda 4 — composición y envío inmediato.
///
/// RF-MSG-01, 02, 06, 12, 13 · RF-USR-07 · RF-PRG-01 · RN-03, RN-06.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Todo lo que se prueba aquí gira en torno a que enviar es irreversible.
/// ────────────────────────────────────────────────────────────────────────────
///
/// RN-03 dice que un mensaje enviado no se edita ni se borra. Así que los
/// casos que importan no son los del camino feliz, sino los que impiden un
/// envío equivocado: el conteo real antes de confirmar, la segunda
/// confirmación de una urgente, y que cancelar no envíe nada.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/infrastructure/firebase/repositorio_envio.dart';
import 'package:sian/presentation/admin/seccion_mensajes.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

void main() {
  late RepositorioSesionFalso sesion;
  late RepositorioEnvioFalso envio;

  setUp(() {
    sesion = RepositorioSesionFalso();
    envio = RepositorioEnvioFalso();
  });
  tearDown(() => sesion.cerrar());

  Widget montar({bool puedeUrgentes = true}) {
    sesion.emitir(
      SesionActiva(
        usuarioDePrueba(
          rol: Rol.administradora,
          puedeEmitirUrgentes: puedeUrgentes,
        ),
      ),
    );
    return ProviderScope(
      overrides: [
        repositorioSesionProvider.overrideWithValue(sesion),
        repositorioEnvioProvider.overrideWithValue(envio),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: const Scaffold(body: SeccionMensajes()),
      ),
    );
  }

  /// Avance acotado en vez de `pumpAndSettle`.
  ///
  /// Mientras hay un diálogo abierto, el botón de enviar sigue mostrando su
  /// indicador de carga —girando para siempre—, así que `pumpAndSettle` no
  /// asienta nunca. Avanzar un tiempo fijo basta para que el diálogo termine
  /// de aparecer.
  Future<void> asentar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> escribir(
    WidgetTester tester,
    String titulo,
    String cuerpo,
  ) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, Textos.etiquetaTituloMensaje),
      titulo,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, Textos.etiquetaCuerpoMensaje),
      cuerpo,
    );
    await tester.pump();
  }

  Future<void> pulsarEnviar(WidgetTester tester) async {
    final Finder boton = find.text(Textos.botonEnviarAhora);
    await tester.ensureVisible(boton);
    await asentar(tester);
    await tester.tap(boton);
    await asentar(tester);
  }

  group('RF-MSG-06 · límites de longitud', () {
    testWidgets('el título no deja pasar de 80 caracteres', (
      WidgetTester tester,
    ) async {
      // Se corta al escribir en vez de rechazar después: descubrir a los 90
      // que sobran 10 es perder trabajo ya hecho.
      await tester.pumpWidget(montar());
      await asentar(tester);

      await escribir(tester, 'x' * 200, 'cuerpo');

      final TextFormField campo = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, Textos.etiquetaTituloMensaje),
      );
      expect(campo.controller!.text.length, Textos.limiteTitulo);
    });

    testWidgets('el cuerpo no deja pasar de 500', (WidgetTester tester) async {
      await tester.pumpWidget(montar());
      await asentar(tester);

      await escribir(tester, 'titulo', 'y' * 900);

      final TextFormField campo = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, Textos.etiquetaCuerpoMensaje),
      );
      expect(campo.controller!.text.length, Textos.limiteCuerpo);
    });

    testWidgets('un formulario vacío no llega ni a contar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar());
      await asentar(tester);
      await pulsarEnviar(tester);

      expect(find.text(Textos.validacionTituloObligatorio), findsOneWidget);
      expect(envio.vecesQueConto, 0);
      expect(envio.vecesQueEnvio, 0);
    });
  });

  group('RF-USR-07 · el conteo se ve antes de confirmar', () {
    testWidgets('muestra cuántos lo recibirán', (WidgetTester tester) async {
      await tester.pumpWidget(montar());
      await asentar(tester);

      await escribir(tester, 'Simulacro', 'A las 10 de la mañana');
      await pulsarEnviar(tester);

      expect(envio.vecesQueConto, 1);
      expect(find.text(Textos.conteoDestinatarios(3)), findsOneWidget);
      // Todavía no se ha enviado nada: hay un diálogo de por medio.
      expect(envio.vecesQueEnvio, 0);
    });

    testWidgets('dice quién queda fuera y por qué', (
      WidgetTester tester,
    ) async {
      // «43 de 45» sin decir el motivo deja al emisor sin saber si eso está
      // bien o es un problema.
      envio.excluidos = 2;
      envio.motivos = <String, int>{'CUENTA_DESACTIVADA': 2};

      await tester.pumpWidget(montar());
      await asentar(tester);
      await escribir(tester, 'Aviso', 'Cuerpo');
      await pulsarEnviar(tester);

      expect(find.text(Textos.conteoExcluidos(2)), findsOneWidget);
      expect(
        find.text('· ${Textos.motivoExclusion('CUENTA_DESACTIVADA', 2)}'),
        findsOneWidget,
      );
    });

    testWidgets('cancelar en el conteo no envía nada', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar());
      await asentar(tester);
      await escribir(tester, 'Aviso', 'Cuerpo');
      await pulsarEnviar(tester);

      await tester.tap(find.text(Textos.botonCancelar));
      await asentar(tester);

      expect(envio.vecesQueEnvio, 0);
    });
  });

  group('RF-MSG-13 · una urgente exige DOS confirmaciones', () {
    Future<void> elegirUrgente(WidgetTester tester) async {
      final Finder urgente = find.text(Textos.tipoUrgente);
      await tester.ensureVisible(urgente);
      await asentar(tester);
      await tester.tap(urgente);
      await asentar(tester);
    }

    testWidgets('el botón de enviar NO cuenta como confirmación', (
      WidgetTester tester,
    ) async {
      // Un pulsar de más en el sitio equivocado no puede hacer sonar el
      // teléfono de doscientas personas.
      await tester.pumpWidget(montar());
      await asentar(tester);
      await escribir(tester, 'Evacuación', 'Salgan por la puerta norte');
      await elegirUrgente(tester);
      await pulsarEnviar(tester);

      // Primer diálogo: el conteo.
      await tester.tap(find.text(Textos.botonConfirmarEnvio));
      await asentar(tester);

      // Segundo diálogo: distinto, con su propia advertencia.
      expect(find.text(Textos.confirmarUrgenteTitulo), findsOneWidget);
      expect(find.text(Textos.urgenteAdvertencia), findsOneWidget);
      expect(envio.vecesQueEnvio, 0, reason: 'todavía no debe haber enviado');
    });

    testWidgets('cancelar en la SEGUNDA confirmación no envía', (
      WidgetTester tester,
    ) async {
      // Es el paso 4.5 del guion: el mensaje queda sin enviar.
      await tester.pumpWidget(montar());
      await asentar(tester);
      await escribir(tester, 'Evacuación', 'Cuerpo');
      await elegirUrgente(tester);
      await pulsarEnviar(tester);

      await tester.tap(find.text(Textos.botonConfirmarEnvio));
      await asentar(tester);
      await tester.tap(find.text(Textos.botonCancelar));
      await asentar(tester);

      expect(envio.vecesQueEnvio, 0);
    });

    testWidgets('pasadas las dos, envía y lo declara al servidor', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar());
      await asentar(tester);
      await escribir(tester, 'Evacuación', 'Cuerpo');
      await elegirUrgente(tester);
      await pulsarEnviar(tester);

      await tester.tap(find.text(Textos.botonConfirmarEnvio));
      await asentar(tester);
      await tester.tap(find.text(Textos.botonConfirmarUrgente));
      await asentar(tester);

      expect(envio.vecesQueEnvio, 1);
      expect(envio.ultimaUrgente, isTrue);
      // Viaja al servidor a propósito: el diálogo de la interfaz no basta
      // como garantía de RN-06.
      expect(envio.ultimaConfirmacionUrgente, isTrue);
    });

    testWidgets('un aviso informativo solo pide UNA confirmación', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar());
      await asentar(tester);
      await escribir(tester, 'Aviso', 'Cuerpo');
      await pulsarEnviar(tester);

      await tester.tap(find.text(Textos.botonConfirmarEnvio));
      await asentar(tester);

      expect(envio.vecesQueEnvio, 1);
      expect(envio.ultimaUrgente, isFalse);
      expect(find.text(Textos.confirmarUrgenteTitulo), findsNothing);
    });
  });

  group('autorización fina sobre las urgentes', () {
    testWidgets('sin autorización, la opción está bloqueada y lo explica', (
      WidgetTester tester,
    ) async {
      // Paso 4.9 del guion. La interfaz lo respeta, y el servidor lo vuelve a
      // exigir: deshabilitar el control no es una medida de seguridad.
      await tester.pumpWidget(montar(puedeUrgentes: false));
      await asentar(tester);

      expect(find.text(Textos.noPuedeUrgentes), findsOneWidget);

      final RadioListTile<bool> opcion = tester.widget<RadioListTile<bool>>(
        find.widgetWithText(RadioListTile<bool>, Textos.tipoUrgente),
      );
      expect(opcion.enabled, isFalse);
    });

    testWidgets('con autorización, se puede elegir', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar());
      await asentar(tester);

      expect(find.text(Textos.tipoUrgenteDetalle), findsOneWidget);

      final RadioListTile<bool> opcion = tester.widget<RadioListTile<bool>>(
        find.widgetWithText(RadioListTile<bool>, Textos.tipoUrgente),
      );
      expect(opcion.enabled, isTrue);
    });
  });

  group('resultado del envío', () {
    testWidgets('un envío completo lo dice y limpia el formulario', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar());
      await asentar(tester);
      await escribir(tester, 'Aviso', 'Cuerpo');
      await pulsarEnviar(tester);
      await tester.tap(find.text(Textos.botonConfirmarEnvio));
      await asentar(tester);

      expect(find.text(Textos.envioCorrecto(3, 3)), findsOneWidget);

      final TextFormField campo = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, Textos.etiquetaTituloMensaje),
      );
      expect(campo.controller!.text, isEmpty);
    });

    testWidgets('un envío con fallos NO limpia, para poder reintentar', (
      WidgetTester tester,
    ) async {
      // Si a 5 de 40 no les llegó, lo último que quiere el emisor es haber
      // perdido el texto que acaba de escribir.
      envio.resultado = const ResultadoEnvio(
        mensajeId: 'm1',
        estado: 'ENVIADO_CON_FALLOS',
        total: 40,
        entregados: 35,
        fallidos: 5,
      );

      await tester.pumpWidget(montar());
      await asentar(tester);
      await escribir(tester, 'Aviso importante', 'Cuerpo');
      await pulsarEnviar(tester);
      await tester.tap(find.text(Textos.botonConfirmarEnvio));
      await asentar(tester);

      expect(find.text(Textos.envioConFallos(35, 40, 5)), findsOneWidget);

      final TextFormField campo = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, Textos.etiquetaTituloMensaje),
      );
      expect(campo.controller!.text, 'Aviso importante');
    });

    testWidgets('sin destinatarios no llega a preguntar nada', (
      WidgetTester tester,
    ) async {
      envio = RepositorioEnvioFalso(conteo: 0);

      await tester.pumpWidget(montar());
      await asentar(tester);
      await escribir(tester, 'Aviso', 'Cuerpo');
      await pulsarEnviar(tester);

      expect(find.text(Textos.envioSinDestinatarios), findsOneWidget);
      expect(envio.vecesQueEnvio, 0);
    });
  });
}
