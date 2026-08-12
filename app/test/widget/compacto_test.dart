/// Lo que se ve sin abrir nada, y lo que sobrevive a girar el teléfono.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Tres cosas que solo se notan usando la aplicación de verdad.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Un trozo del cuerpo cortado a media frase ocupaba el sitio de otro aviso sin
/// ayudar a decidir cuál abrir. Un aviso sin confirmación quedaba «incompleto»
/// para siempre por no haber hecho algo que nunca se le pidió. Y girar el
/// aparato borraba el mensaje que se estaba escribiendo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/domain/repositorios.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/infrastructure/firebase/repositorio_dispositivos.dart';
import 'package:sian/infrastructure/firebase/repositorio_programacion.dart';
import 'package:sian/core/navegador.dart';
import 'package:sian/application/proveedores_dispositivos.dart';
import 'package:sian/application/proveedores_grupos.dart';
import 'package:sian/application/proveedores_programacion.dart';
import 'package:sian/presentation/admin/panel_admin.dart';
import 'package:sian/presentation/admin/seccion_mensajes.dart';
import 'package:sian/presentation/docente/bandeja_docente.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

MensajeProgramado reporte({
  required bool pideConfirmacion,
  required int total,
  required int entregados,
  required int confirmados,
}) => MensajeProgramado(
  id: 'p1',
  titulo: 'Aviso',
  tipo: 'INFORMATIVO',
  estado: 'ENVIADO',
  modo: 'UNICO',
  creadoPor: 'uid-1',
  requiereConfirmacion: pideConfirmacion,
  modoDestinatarios: 'TODOS',
  formato: const <String>['TEXTO'],
  totalDestinatarios: total,
  entregados: entregados,
  confirmados: confirmados,
);

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // «COMPLETO» NO SIGNIFICA LO MISMO PARA TODOS LOS AVISOS.
  // ──────────────────────────────────────────────────────────────────────────
  //
  // Si el aviso pedía confirmación, está cerrado cuando la dieron todos. Si no
  // la pedía, nadie iba a confirmar nunca: lo único que cabía esperar es que
  // llegara. Medirlos con la misma vara dejaría a la mitad eternamente
  // pendientes por no haber hecho algo que jamás se les pidió.
  group('cuándo un reporte está completo', () {
    test('con confirmación: lo está cuando confirmaron todos', () {
      expect(
        reporte(
          pideConfirmacion: true,
          total: 5,
          entregados: 5,
          confirmados: 4,
        ).estaCompleto,
        isFalse,
      );
      expect(
        reporte(
          pideConfirmacion: true,
          total: 5,
          entregados: 5,
          confirmados: 5,
        ).estaCompleto,
        isTrue,
      );
    });

    test('sin confirmación: basta con que les llegara', () {
      expect(
        reporte(
          pideConfirmacion: false,
          total: 5,
          entregados: 5,
          confirmados: 0,
        ).estaCompleto,
        isTrue,
        reason: 'nadie tenía que confirmar nada',
      );
      expect(
        reporte(
          pideConfirmacion: false,
          total: 5,
          entregados: 3,
          confirmados: 0,
        ).estaCompleto,
        isFalse,
      );
    });

    test('sin destinatarios no está completo, está vacío', () {
      expect(
        reporte(
          pideConfirmacion: false,
          total: 0,
          entregados: 0,
          confirmados: 0,
        ).estaCompleto,
        isFalse,
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // LA FILA PLEGADA.
  // ──────────────────────────────────────────────────────────────────────────
  group('lo que se ve sin desplegar un mensaje', () {
    late RepositorioSesionFalso sesion;
    late RepositorioDispositivosFalso dispositivos;

    setUp(() {
      sesion = RepositorioSesionFalso();
      dispositivos = RepositorioDispositivosFalso(
        entorno: EntornoNavegador.desconocido,
        permiso: EstadoPermiso.concedido,
      );
    });
    tearDown(() async {
      await sesion.cerrar();
      await dispositivos.cerrar();
    });

    Widget montar(List<MensajeRecibido> mensajes) => ProviderScope(
      overrides: [
        repositorioSesionProvider.overrideWithValue(sesion),
        repositorioDispositivosProvider.overrideWithValue(dispositivos),
        repositorioBandejaProvider.overrideWithValue(
          RepositorioBandejaFalso(mensajes),
        ),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: BandejaDocente(usuario: usuarioDePrueba(rol: Rol.catedratico)),
      ),
    );

    const MensajeRecibido conVoz = MensajeRecibido(
      mensajeId: 'm1',
      titulo: 'Simulacro de evacuación',
      cuerpo: 'Este cuerpo NO debe aparecer mientras esté plegado.',
      tipo: 'INFORMATIVO',
      estado: 'ENTREGADO',
      requiereConfirmacion: false,
      adjuntos: <AdjuntoRecibido>[
        AdjuntoRecibido(tipo: 'AUDIO', ruta: 'm/1-voz.webm', duracionSeg: 12),
      ],
    );

    testWidgets('el cuerpo NO se asoma: solo el título', (
      WidgetTester tester,
    ) async {
      // Una línea cortada a media frase casi nunca resume el aviso, y ocupa el
      // sitio de otro mensaje en la pantalla.
      await tester.pumpWidget(montar(<MensajeRecibido>[conVoz]));
      await tester.pumpAndSettle();

      expect(find.text('Simulacro de evacuación'), findsOneWidget);
      expect(
        find.textContaining('NO debe aparecer'),
        findsNothing,
        reason: 'plegado no se enseña el cuerpo',
      );
    });

    testWidgets('sí dice que trae una nota de voz', (
      WidgetTester tester,
    ) async {
      // Saber que hay audio es lo que ayuda a decidir cuál abrir primero: en
      // una alerta puede ser lo único que importe.
      await tester.pumpWidget(montar(<MensajeRecibido>[conVoz]));
      await tester.pumpAndSettle();

      expect(find.text(Textos.traeVoz), findsOneWidget);
      expect(find.text(Textos.traeImagen), findsNothing);
    });

    testWidgets('al desplegarlo aparece el cuerpo y desaparece la señal', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(<MensajeRecibido>[conVoz]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simulacro de evacuación'));
      await tester.pumpAndSettle();

      expect(find.textContaining('NO debe aparecer'), findsOneWidget);
      expect(find.text(Textos.traeVoz), findsNothing, reason: 'ya se ve solo');
    });

    testWidgets('un aviso de solo texto no anuncia adjuntos', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(<MensajeRecibido>[
          const MensajeRecibido(
            mensajeId: 'm2',
            titulo: 'Cambio de aula',
            cuerpo: 'Cuerpo',
            tipo: 'INFORMATIVO',
            estado: 'ENTREGADO',
            requiereConfirmacion: false,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text(Textos.traeVoz), findsNothing);
      expect(find.text(Textos.traeImagen), findsNothing);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // GIRAR EL TELÉFONO NO PUEDE BORRAR LO QUE SE ESTABA ESCRIBIENDO.
  // ──────────────────────────────────────────────────────────────────────────
  //
  // El panel se dibuja de dos formas según el ancho, y girar cruza ese umbral.
  // Sin una llave global, el contenido cambiaba de sitio en el árbol y Flutter
  // lo daba por muerto: título, mensaje y adjuntos desaparecían de golpe.
  testWidgets('girar la pantalla conserva el mensaje a medio escribir', (
    WidgetTester tester,
  ) async {
    final RepositorioSesionFalso sesion = RepositorioSesionFalso();
    addTearDown(sesion.cerrar);
    final RepositorioDispositivosFalso dispositivos =
        RepositorioDispositivosFalso(
          entorno: EntornoNavegador.desconocido,
          permiso: EstadoPermiso.concedido,
        );
    addTearDown(dispositivos.cerrar);

    final UsuarioSesion coordinador = usuarioDePrueba(rol: Rol.coordinador);
    sesion.emitir(SesionActiva(coordinador));

    // Vertical: por debajo del umbral, el menú es un cajón.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositorioSesionProvider.overrideWithValue(sesion),
          repositorioDispositivosProvider.overrideWithValue(dispositivos),
          repositorioEnvioProvider.overrideWithValue(RepositorioEnvioFalso()),
          repositorioGruposProvider.overrideWithValue(RepositorioGruposFalso()),
          repositorioProgramacionProvider.overrideWithValue(
            RepositorioProgramacionFalso(),
          ),
          repositorioBandejaProvider.overrideWithValue(
            RepositorioBandejaFalso(const <MensajeRecibido>[]),
          ),
        ],
        child: MaterialApp(
          theme: TemaSian.claro(),
          home: PanelAdmin(usuario: coordinador),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, Textos.etiquetaTituloMensaje),
      'Fuga de gas en el edificio B',
    );
    await tester.pumpAndSettle();

    // Horizontal: cruza el umbral y el contenido cambia de sitio en el árbol.
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();

    expect(
      find.text('Fuga de gas en el edificio B'),
      findsOneWidget,
      reason: 'girar no puede borrar una alerta a medio redactar',
    );
  });
}
