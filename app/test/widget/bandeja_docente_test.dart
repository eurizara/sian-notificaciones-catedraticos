/// Pruebas de la bandeja del catedrático — RF-ENT-12, RF-CNF-02, RF-CNF-04.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_programacion.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/domain/repositorios.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/presentation/docente/bandeja_docente.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

void main() {
  MensajeRecibido mensaje({
    String id = 'm-1',
    String titulo = 'Reunión de claustro',
    String tipo = 'INFORMATIVO',
    String estado = 'ENTREGADO',
    bool requiereConfirmacion = false,
  }) {
    return MensajeRecibido(
      mensajeId: id,
      titulo: titulo,
      cuerpo: 'Cuerpo del mensaje.',
      tipo: tipo,
      estado: estado,
      requiereConfirmacion: requiereConfirmacion,
      entregadoEn: DateTime.utc(2026, 8, 3, 13),
    );
  }

  late RepositorioProgramacionFalso programacion;

  setUp(() => programacion = RepositorioProgramacionFalso());

  Widget montar(List<MensajeRecibido> mensajes, {String uid = 'uid-1'}) {
    return ProviderScope(
      overrides: [
        repositorioSesionProvider.overrideWithValue(RepositorioSesionFalso()),
        repositorioBandejaProvider.overrideWithValue(
          RepositorioBandejaFalso(mensajes),
        ),
        repositorioProgramacionProvider.overrideWithValue(programacion),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: BandejaDocente(
          usuario: usuarioDePrueba(rol: Rol.catedratico, uid: uid),
        ),
      ),
    );
  }

  testWidgets('sin mensajes lo dice, no se queda en blanco', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(montar(const <MensajeRecibido>[]));
    await tester.pumpAndSettle();

    expect(find.text(Textos.bandejaVacia), findsOneWidget);
  });

  testWidgets('lista los mensajes recibidos', (WidgetTester tester) async {
    await tester.pumpWidget(
      montar(<MensajeRecibido>[
        mensaje(titulo: 'Reunión de claustro'),
        mensaje(id: 'm-2', titulo: 'Cierre de notas'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reunión de claustro'), findsOneWidget);
    expect(find.text('Cierre de notas'), findsOneWidget);
  });

  testWidgets('RF-ENT-05 · distingue visualmente una alerta urgente', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      montar(<MensajeRecibido>[
        mensaje(titulo: 'Aviso normal'),
        mensaje(id: 'm-2', titulo: 'Simulacro', tipo: 'URGENTE'),
      ]),
    );
    await tester.pumpAndSettle();

    // El distintivo «URGENTE» es la única mitigación disponible en iOS-PWA,
    // donde no se puede definir sonido ni vibración propios (DT-02).
    expect(find.text(Textos.etiquetaUrgente), findsOneWidget);
  });

  testWidgets('RF-CNF-10 · insiste sobre las urgentes sin confirmar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      montar(<MensajeRecibido>[
        mensaje(
          titulo: 'Simulacro',
          tipo: 'URGENTE',
          requiereConfirmacion: true,
          estado: 'ENTREGADO',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text(Textos.bandejaPendienteUno), findsOneWidget);
  });

  testWidgets('una urgente ya confirmada deja de insistir', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      montar(<MensajeRecibido>[
        mensaje(
          titulo: 'Simulacro',
          tipo: 'URGENTE',
          requiereConfirmacion: true,
          estado: 'CONFIRMADO',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    // La bandeja arranca en «Sin leer» y una confirmada no está ahí. Se pasa a
    // «Todos», que es lo que haría cualquiera para repasar el historial.
    await tester.tap(find.text(Textos.filtroBandeja('todos', 1)));
    await tester.pumpAndSettle();

    expect(find.text(Textos.bandejaPendienteUno), findsNothing);
    expect(find.text(Textos.estadoConfirmado), findsOneWidget);
  });

  testWidgets('RF-CNF-04 · confirmar PIDE confirmación antes de escribir', (
    WidgetTester tester,
  ) async {
    // Confirmar es irreversible y con valor probatorio: lo escribe el
    // servidor, nunca el cliente. Un toque accidental no puede producir una
    // evidencia, así que hay un diálogo de por medio que dice justo eso.
    await tester.pumpWidget(
      montar(<MensajeRecibido>[
        mensaje(tipo: 'URGENTE', requiereConfirmacion: true),
      ]),
    );
    await tester.pumpAndSettle();

    final Finder boton = find.widgetWithText(
      FilledButton,
      Textos.botonConfirmarLectura,
    );
    expect(boton, findsOneWidget);
    expect(tester.widget<FilledButton>(boton).onPressed, isNotNull);

    await tester.ensureVisible(boton);
    await tester.pumpAndSettle();
    await tester.tap(boton);
    await tester.pumpAndSettle();

    expect(find.text(Textos.confirmarTitulo), findsOneWidget);
    expect(find.text(Textos.confirmarAviso), findsOneWidget);
    expect(
      programacion.confirmados,
      isEmpty,
      reason: 'todavía no debe escribir',
    );

    await tester.tap(find.text(Textos.confirmarSi));
    await tester.pumpAndSettle();

    expect(programacion.confirmados, <String>['m-1']);
  });

  testWidgets('cancelar en ese diálogo no confirma nada', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      montar(<MensajeRecibido>[
        mensaje(tipo: 'URGENTE', requiereConfirmacion: true),
      ]),
    );
    await tester.pumpAndSettle();

    final Finder boton = find.widgetWithText(
      FilledButton,
      Textos.botonConfirmarLectura,
    );
    await tester.ensureVisible(boton);
    await tester.pumpAndSettle();
    await tester.tap(boton);
    await tester.pumpAndSettle();
    await tester.tap(find.text(Textos.botonCancelar));
    await tester.pumpAndSettle();

    expect(programacion.confirmados, isEmpty);
  });

  testWidgets('RF-CNF-02 · pintar la lista NO marca nada como abierto', (
    WidgetTester tester,
  ) async {
    // ──────────────────────────────────────────────────────────────────────
    // «Abierto» tiene que significar que alguien lo miró.
    // ──────────────────────────────────────────────────────────────────────
    //
    // Antes se marcaba al construir la fila: bastaba con que la bandeja se
    // dibujara para que todo constara como abierto. Eso hacía imposible
    // resaltar lo no leído —nada seguía sin leer más de un instante— y
    // convertía un dato de seguimiento en una casilla que se marca sola.
    await tester.pumpWidget(
      montar(<MensajeRecibido>[mensaje(estado: 'ENTREGADO')]),
    );
    await tester.pumpAndSettle();

    expect(programacion.abiertos, isEmpty);
  });

  testWidgets('RF-CNF-02 · desplegarlo SÍ lo marca como abierto', (
    WidgetTester tester,
  ) async {
    // Es cuando el texto aparece delante de la persona. Sigue sin ser
    // confirmar: abrir dice que lo miró; confirmar, que lo declaró leído.
    await tester.pumpWidget(
      montar(<MensajeRecibido>[mensaje(estado: 'ENTREGADO')]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reunión de claustro'));
    await tester.pumpAndSettle();

    expect(programacion.abiertos, <String>['m-1']);
    expect(programacion.confirmados, isEmpty);
  });

  testWidgets('un urgente sin confirmar nace desplegado, y se abre solo', (
    WidgetTester tester,
  ) async {
    // Su contenido sí está delante de la persona desde el primer momento:
    // esconderlo tras un toque sería al revés de lo que hace falta.
    await tester.pumpWidget(
      montar(<MensajeRecibido>[
        mensaje(
          estado: 'ENTREGADO',
          tipo: 'URGENTE',
          requiereConfirmacion: true,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(programacion.abiertos, <String>['m-1']);
  });

  testWidgets('pide el historial del usuario en sesión, no el de otro', (
    WidgetTester tester,
  ) async {
    final RepositorioBandejaFalso bandeja = RepositorioBandejaFalso(
      const <MensajeRecibido>[],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositorioSesionProvider.overrideWithValue(RepositorioSesionFalso()),
          repositorioBandejaProvider.overrideWithValue(bandeja),
        ],
        child: MaterialApp(
          home: BandejaDocente(
            usuario: usuarioDePrueba(rol: Rol.catedratico, uid: 'uid-mio'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(bandeja.uidsConsultados, <String>['uid-mio']);
  });
}
