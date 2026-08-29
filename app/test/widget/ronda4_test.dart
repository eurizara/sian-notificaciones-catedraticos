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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/core/audio/grabacion.dart';
import 'package:sian/core/plataforma/archivo_elegido.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/infrastructure/firebase/repositorio_adjuntos.dart';
import 'package:sian/infrastructure/firebase/repositorio_envio.dart';
import 'package:sian/presentation/admin/seccion_mensajes.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';
import 'adjuntos_test.dart' show GrabadoraFalsa, grabacion, pngMinimo;

void main() {
  group('matriz de autorización · RF-MSG-02, documento 01 §2.2', () {
    // Fijada como prueba pura porque es la regla, no la pantalla. La fila
    // CREAR_ALERTA_URGENTE da alcance TODO al coordinador y CONDICIONADO a la
    // administradora: la bandera existe para que él decida quién más puede.
    test('el coordinador puede, tenga o no la bandera', () {
      expect(
        Rol.coordinador.puedeEmitirUrgentes(autorizacionFina: false),
        isTrue,
      );
      expect(
        Rol.coordinador.puedeEmitirUrgentes(autorizacionFina: true),
        isTrue,
      );
    });

    test('la administradora depende de la bandera', () {
      expect(
        Rol.administradora.puedeEmitirUrgentes(autorizacionFina: false),
        isFalse,
      );
      expect(
        Rol.administradora.puedeEmitirUrgentes(autorizacionFina: true),
        isTrue,
      );
    });

    test('nadie más puede, ni con la bandera puesta', () {
      for (final Rol rol in <Rol>[Rol.catedratico, Rol.auditor]) {
        expect(
          rol.puedeEmitirUrgentes(autorizacionFina: true),
          isFalse,
          reason: '$rol',
        );
      }
    });

    test('los recurrentes siguen la misma forma', () {
      expect(
        Rol.coordinador.puedeCrearRecurrentes(autorizacionFina: false),
        isTrue,
      );
      expect(
        Rol.administradora.puedeCrearRecurrentes(autorizacionFina: false),
        isFalse,
      );
    });
  });

  late RepositorioSesionFalso sesion;
  late RepositorioEnvioFalso envio;

  setUp(() {
    sesion = RepositorioSesionFalso();
    envio = RepositorioEnvioFalso();
  });
  tearDown(() => sesion.cerrar());

  Widget montar({
    bool puedeUrgentes = true,
    Rol rol = Rol.administradora,
    RepositorioAdjuntosFalso? adjuntos,
    Grabadora Function()? grabadora,
    Future<ArchivoElegido?> Function()? elegir,
  }) {
    sesion.emitir(
      SesionActiva(
        usuarioDePrueba(rol: rol, puedeEmitirUrgentes: puedeUrgentes),
      ),
    );
    return ProviderScope(
      overrides: [
        repositorioSesionProvider.overrideWithValue(sesion),
        repositorioEnvioProvider.overrideWithValue(envio),
        if (adjuntos != null)
          repositorioAdjuntosProvider.overrideWithValue(adjuntos),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: Scaffold(
          body: SeccionMensajes(
            crearGrabadora: grabadora ?? crearGrabadoraReal,
            elegirImagen: elegir ?? elegirImagenReal,
          ),
        ),
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

    testWidgets('el COORDINADOR puede siempre, sin bandera', (
      WidgetTester tester,
    ) async {
      // ────────────────────────────────────────────────────────────────────
      // La bandera fina no aplica a todos los roles.
      // ────────────────────────────────────────────────────────────────────
      //
      // En la matriz del documento 01, `CREAR_ALERTA_URGENTE` es TODO para el
      // coordinador y CONDICIONADO para la administradora: la bandera existe
      // para que ÉL decida quién más puede. Mirar solo la bandera lo dejaba
      // bloqueado en pantalla mientras el servidor se lo habría aceptado.
      await tester.pumpWidget(
        montar(rol: Rol.coordinador, puedeUrgentes: false),
      );
      await asentar(tester);

      final RadioListTile<bool> opcion = tester.widget<RadioListTile<bool>>(
        find.widgetWithText(RadioListTile<bool>, Textos.tipoUrgente),
      );
      expect(opcion.enabled, isTrue);
      expect(find.text(Textos.noPuedeUrgentes), findsNothing);
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

    testWidgets('un envío con fallos TAMBIÉN limpia el formulario', (
      WidgetTester tester,
    ) async {
      // ────────────────────────────────────────────────────────────────────────
      // Esta prueba afirmaba lo contrario, y por eso salieron avisos dobles.
      // ────────────────────────────────────────────────────────────────────────
      //
      // Decía «NO limpia, para poder reintentar», con el argumento de que el
      // emisor no quiere perder el texto recién escrito. Suena razonable y es
      // falso: reintentar es justo lo que no debe hacerse, porque a quien le
      // falló le va a fallar igual y el mensaje ya está enviado y registrado.
      //
      // Lo que producía era una pantalla idéntica a la de antes de pulsar. El 29
      // de agosto de 2026 el coordinador la leyó como «no se envió», volvió a
      // pulsar, y veinte catedráticos recibieron el mismo aviso urgente dos
      // veces. Dos avisos suyos salieron cuatro (DT-24).
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

      // Se dice lo que pasó, con el detalle de a cuántos no llegó.
      expect(find.text(Textos.envioConFallos(35, 40, 5)), findsOneWidget);

      // Y el formulario queda vacío, porque el mensaje se envió.
      final TextFormField campo = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, Textos.etiquetaTituloMensaje),
      );
      expect(campo.controller!.text, isEmpty);
    });

    testWidgets('un envío con fallos no se pinta de rojo', (
      WidgetTester tester,
    ) async {
      // El rojo es el color de lo urgente y de lo que salió mal. Un envío que
      // llegó a 35 de 40 no es ninguna de las dos cosas, y pintarlo de rojo
      // contradecía al texto: ganaba el color (DT-24).
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

      final SnackBar aviso = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(aviso.backgroundColor, isNot(ColoresSian.urgente));
      expect(aviso.backgroundColor, ColoresSian.doradoTexto);
    });

    testWidgets('cada mensaje reserva su propio identificador', (
      WidgetTester tester,
    ) async {
      // La otra mitad de DT-24. Mientras el formulario no se vacíe el
      // identificador es el mismo, así que un segundo envío del mismo texto lo
      // rechaza el servidor con `create`. Al vaciarse se suelta, y el mensaje
      // siguiente —aunque dijera lo mismo— tiene derecho a su propio sitio.
      await tester.pumpWidget(montar());
      await asentar(tester);

      await escribir(tester, 'Primero', 'Cuerpo');
      await pulsarEnviar(tester);
      await tester.tap(find.text(Textos.botonConfirmarEnvio));
      await asentar(tester);

      // El aviso flotante dura seis segundos y tapa el botón. Se deja pasar
      // antes de volver a enviar, que es lo que haría una persona.
      await tester.pump(const Duration(seconds: 7));

      await escribir(tester, 'Segundo', 'Cuerpo');
      await pulsarEnviar(tester);
      await tester.tap(find.text(Textos.botonConfirmarEnvio));
      await asentar(tester);

      expect(envio.idsReservados, hasLength(2));
      expect(envio.idsReservados[0], isNotNull);
      expect(envio.idsReservados[1], isNotNull);
      expect(envio.idsReservados[1], isNot(envio.idsReservados[0]));
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

  // ──────────────────────────────────────────────────────────────────────────
  // RF-MSG-05 · ADJUNTAR Y ENVIAR, EN LA MISMA PRUEBA.
  // ──────────────────────────────────────────────────────────────────────────
  //
  // Que el panel conserve las dos cosas y que el envío sepa mandarlas son
  // afirmaciones distintas, y por separado las dos eran ciertas mientras en la
  // aplicación real solo salía el audio. Lo que faltaba era exactamente esto:
  // adjuntar desde la pantalla de verdad y después pulsar enviar.
  group('RF-MSG-05 · voz e imagen en el mismo envío', () {
    late RepositorioAdjuntosFalso adjuntos;
    late GrabadoraFalsa grabadora;

    final ArchivoElegido png = ArchivoElegido(
      bytes: pngMinimo,
      tipoMime: 'image/png',
      nombre: 'plano.png',
    );

    setUp(() {
      adjuntos = RepositorioAdjuntosFalso();
      grabadora = GrabadoraFalsa()..resultado = grabacion(segundos: 9);
    });

    Future<void> ponerImagen(WidgetTester tester) async {
      await tester.ensureVisible(find.text(Textos.imagenElegir));
      await tester.tap(find.text(Textos.imagenElegir));
      await asentar(tester);
    }

    Future<void> ponerVoz(WidgetTester tester) async {
      await tester.ensureVisible(find.text(Textos.vozGrabar));
      await tester.tap(find.text(Textos.vozGrabar));
      await asentar(tester);
      await tester.tap(find.textContaining(RegExp('^Detener')));
      await asentar(tester);
    }

    // Las cuatro combinaciones que se dan en la práctica. El orden importa
    // porque cada camino tiene que conservar lo que ya estaba puesto, y lo
    // urgente importa porque mete un segundo diálogo entre adjuntar y subir.
    for (final bool urgente in <bool>[false, true]) {
      for (final bool imagenPrimero in <bool>[true, false]) {
        final String caso =
            '${urgente ? 'urgente' : 'informativo'}, '
            '${imagenPrimero ? 'imagen y luego voz' : 'voz y luego imagen'}';

        testWidgets('$caso: se suben las dos y las dos llegan', (
          WidgetTester tester,
        ) async {
          await tester.pumpWidget(
            montar(
              adjuntos: adjuntos,
              grabadora: () => grabadora,
              elegir: () async => png,
            ),
          );
          await asentar(tester);
          await escribir(tester, 'Con adjuntos', 'Cuerpo');

          if (imagenPrimero) {
            await ponerImagen(tester);
            await ponerVoz(tester);
          } else {
            await ponerVoz(tester);
            await ponerImagen(tester);
          }

          if (urgente) {
            final Finder marca = find.text(Textos.tipoUrgente);
            await tester.ensureVisible(marca);
            await asentar(tester);
            await tester.tap(marca);
            await asentar(tester);
          }

          await pulsarEnviar(tester);
          await tester.tap(find.text(Textos.botonConfirmarEnvio));
          await asentar(tester);
          if (urgente) {
            await tester.tap(find.text(Textos.botonConfirmarUrgente));
            await asentar(tester);
          }

          expect(adjuntos.vecesQueSubioVoz, 1, reason: 'la voz se sube');
          expect(adjuntos.vecesQueSubioImagen, 1, reason: 'la imagen TAMBIÉN');
          expect(envio.ultimaVoz, isNotNull);
          expect(envio.ultimaImagen, isNotNull);

          // Las dos contra el mismo identificador reservado: si cada una fuera
          // por su lado, una quedaría en una carpeta sin mensaje.
          expect(adjuntos.idDeLaVoz, adjuntos.idDeLaImagen);
        });
      }
    }

    // ────────────────────────────────────────────────────────────────────────
    // NADA SALE MIENTRAS HAY UN ADJUNTO A MEDIAS.
    // ────────────────────────────────────────────────────────────────────────
    //
    // Una grabación no forma parte del mensaje hasta que se detiene. Enviar
    // antes produce lo peor: el aviso sale SIN la nota de voz, sin error y sin
    // aviso. Quien lo mandó cree que mandó audio; quien lo recibe ve texto
    // suelto. Y RN-03 dice que un mensaje enviado no se edita.
    testWidgets('grabando, el envío está bloqueado y el botón dice por qué', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(
          adjuntos: adjuntos,
          grabadora: () => grabadora,
          elegir: () async => png,
        ),
      );
      await asentar(tester);
      await escribir(tester, 'A medio grabar', 'Cuerpo');

      await tester.ensureVisible(find.text(Textos.vozGrabar));
      await tester.tap(find.text(Textos.vozGrabar));
      await asentar(tester);

      final Finder boton = find.widgetWithText(
        FilledButton,
        Textos.adjuntoAMedias,
      );
      expect(boton, findsOneWidget, reason: 'el botón explica el bloqueo');
      expect(
        tester.widget<FilledButton>(boton).onPressed,
        isNull,
        reason: 'y no se puede pulsar',
      );
      expect(envio.vecesQueConto, 0, reason: 'ni siquiera cuenta');
    });

    testWidgets('al detener la grabación, el envío se desbloquea', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(
          adjuntos: adjuntos,
          grabadora: () => grabadora,
          elegir: () async => png,
        ),
      );
      await asentar(tester);
      await escribir(tester, 'Ya grabado', 'Cuerpo');
      await ponerVoz(tester);

      expect(find.text(Textos.adjuntoAMedias), findsNothing);
      await pulsarEnviar(tester);
      expect(envio.vecesQueConto, 1);
    });

    testWidgets('mientras se lee la imagen elegida, tampoco se puede enviar', (
      WidgetTester tester,
    ) async {
      // El selector del navegador tarda en entregar el archivo. En ese hueco
      // la imagen todavía no es parte del mensaje.
      final Completer<ArchivoElegido?> lectura = Completer<ArchivoElegido?>();

      await tester.pumpWidget(
        montar(
          adjuntos: adjuntos,
          grabadora: () => grabadora,
          elegir: () => lectura.future,
        ),
      );
      await asentar(tester);
      await escribir(tester, 'Con imagen', 'Cuerpo');
      await ponerImagen(tester);

      expect(find.text(Textos.adjuntoAMedias), findsOneWidget);

      lectura.complete(png);
      await asentar(tester);

      expect(find.text(Textos.adjuntoAMedias), findsNothing);
      expect(find.text('plano.png'), findsOneWidget);
    });

    // ────────────────────────────────────────────────────────────────────────
    // EL ORDEN ES DEL EMISOR Y LLEGA INTACTO AL RECEPTOR.
    // ────────────────────────────────────────────────────────────────────────
    //
    // Un plano, después la nota de voz que lo explica, después la foto del
    // punto de reunión. Ese orden dice algo, y si el sistema lo reordena por
    // tipo —o lo deja al azar de la red subiendo en paralelo— lo destruye sin
    // que nadie se dé cuenta.
    testWidgets('varios adjuntos llegan en el orden en que se pusieron', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(
          adjuntos: adjuntos,
          grabadora: () => grabadora,
          elegir: () async => png,
        ),
      );
      await asentar(tester);
      await escribir(tester, 'Evacuación', 'Cuerpo');

      await ponerImagen(tester);
      await ponerVoz(tester);
      await ponerImagen(tester);

      await pulsarEnviar(tester);
      await tester.tap(find.text(Textos.botonConfirmarEnvio));
      await asentar(tester);

      expect(
        envio.ultimosAdjuntos.map((AdjuntoSubido a) => a.tipo).toList(),
        <String>['IMAGEN', 'AUDIO', 'IMAGEN'],
      );
    });

    testWidgets('cada adjunto va a su propia ruta, sin pisarse', (
      WidgetTester tester,
    ) async {
      // Con un nombre fijo el segundo pisaría al primero, y las reglas
      // prohíben sobrescribir (RN-09): la subida fallaría sin explicar nada.
      await tester.pumpWidget(
        montar(
          adjuntos: adjuntos,
          grabadora: () => grabadora,
          elegir: () async => png,
        ),
      );
      await asentar(tester);
      await escribir(tester, 'Dos imágenes', 'Cuerpo');
      await ponerImagen(tester);
      await ponerImagen(tester);

      await pulsarEnviar(tester);
      await tester.tap(find.text(Textos.botonConfirmarEnvio));
      await asentar(tester);

      final List<String> rutas = envio.ultimosAdjuntos
          .map((AdjuntoSubido a) => a.ruta)
          .toList();
      expect(rutas.toSet().length, 2, reason: 'dos rutas distintas');
    });

    testWidgets('al llegar al máximo, el botón se apaga y lo dice', (
      WidgetTester tester,
    ) async {
      // Pulsar y que no pase nada es peor que no ofrecerlo.
      await tester.pumpWidget(
        montar(
          adjuntos: adjuntos,
          grabadora: () => grabadora,
          elegir: () async => png,
        ),
      );
      await asentar(tester);
      await escribir(tester, 'Tres imágenes', 'Cuerpo');

      await ponerImagen(tester);
      await ponerImagen(tester);
      expect(find.text(Textos.imagenAlMaximo), findsNothing);

      await ponerImagen(tester);
      expect(find.text(Textos.imagenAlMaximo), findsOneWidget);
    });

    testWidgets('la confirmación cuenta CUÁNTOS lleva, no solo que lleva', (
      WidgetTester tester,
    ) async {
      // Con varios adjuntos, «va con imagen» no permite notar que falta la
      // segunda, que es justo lo que este resumen existe para evitar.
      await tester.pumpWidget(
        montar(
          adjuntos: adjuntos,
          grabadora: () => grabadora,
          elegir: () async => png,
        ),
      );
      await asentar(tester);
      await escribir(tester, 'Varios', 'Cuerpo');
      await ponerImagen(tester);
      await ponerImagen(tester);
      await ponerVoz(tester);
      await pulsarEnviar(tester);

      expect(
        find.text(Textos.resumenAdjuntos(voces: 1, imagenes: 2)),
        findsOneWidget,
      );
    });

    testWidgets('la confirmación dice qué se lleva el mensaje', (
      WidgetTester tester,
    ) async {
      // Es la última ocasión de ver que falta algo que se creía puesto: una
      // vez enviado, RN-03 dice que no se edita.
      await tester.pumpWidget(
        montar(
          adjuntos: adjuntos,
          grabadora: () => grabadora,
          elegir: () async => png,
        ),
      );
      await asentar(tester);
      await escribir(tester, 'Con adjuntos', 'Cuerpo');
      await ponerImagen(tester);
      await ponerVoz(tester);
      await pulsarEnviar(tester);

      expect(
        find.text(
          Textos.resumenAdjuntos(voces: 1, imagenes: 1),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sin adjuntos también lo dice, para no dar por hecho', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar());
      await asentar(tester);
      await escribir(tester, 'Solo texto', 'Cuerpo');
      await pulsarEnviar(tester);

      expect(find.text(Textos.resumenSinAdjuntos), findsOneWidget);
    });

    testWidgets('si la imagen no sube, NO se envía a medias y se explica', (
      WidgetTester tester,
    ) async {
      // Mandar el aviso sin la imagen que lo explica es peor que no mandarlo:
      // nadie se entera de que falta.
      adjuntos.fallaLaImagen = true;

      await tester.pumpWidget(
        montar(
          adjuntos: adjuntos,
          grabadora: () => grabadora,
          elegir: () async => png,
        ),
      );
      await asentar(tester);
      await escribir(tester, 'Con adjuntos', 'Cuerpo');
      await ponerImagen(tester);
      await ponerVoz(tester);
      await pulsarEnviar(tester);
      await tester.tap(find.text(Textos.botonConfirmarEnvio));
      await asentar(tester);

      expect(envio.vecesQueEnvio, 0, reason: 'no se envía nada');
      expect(find.text(Textos.falloSubidaImagen), findsOneWidget);
    });
  });
}
