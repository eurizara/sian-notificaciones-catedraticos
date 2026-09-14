/// Responder a un aviso — DT-27, mejora M-5.
///
/// Lo que se comprueba es lo que hace útil y segura la conversación: que
/// responder no se pueda duplicar con un doble toque (la lección de DT-24),
/// que no se pierda lo escrito si falla, que un aviso propio no se responda,
/// que leer apague lo pendiente —el contador y la notificación—, y que el
/// emisor vea primero lo que tiene sin leer.
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_respuestas.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/core/navegador.dart';
import 'package:sian/core/plataforma/notificacion_sistema.dart';
import 'package:sian/domain/repositorios.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/infrastructure/firebase/repositorio_respuestas.dart';
import 'package:sian/presentation/admin/seccion_respuestas.dart';
import 'package:sian/presentation/docente/respuesta_al_aviso.dart';
import 'package:sian/presentation/docente/tarjeta_notificaciones.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

const String emisorUid = 'uid-coordinador';
const String catedraticoUid = 'uid-catedratico';

MensajeRecibido aviso({String creadoPor = emisorUid}) => MensajeRecibido(
  mensajeId: 'm-1',
  titulo: 'Reunión del viernes',
  cuerpo: 'A las 10 en el salón 3.',
  tipo: 'INFORMATIVO',
  estado: 'ABIERTO',
  requiereConfirmacion: false,
  emisor: 'Coordinación',
  creadoPor: creadoPor,
);

Hilo hilo({
  String mensajeId = 'm-1',
  String uid = catedraticoUid,
  String nombre = 'Ana López',
  String titulo = 'Reunión del viernes',
  int sinLeerEmisor = 0,
  int sinLeerCatedratico = 0,
  DateTime? actualizadoEn,
}) => Hilo(
  mensajeId: mensajeId,
  uid: uid,
  nombre: nombre,
  emisorUid: emisorUid,
  tituloAviso: titulo,
  emisorNombre: 'Coordinación',
  sinLeerEmisor: sinLeerEmisor,
  sinLeerCatedratico: sinLeerCatedratico,
  ultimaVista: 'No puedo asistir.',
  actualizadoEn: actualizadoEn ?? DateTime(2026, 9, 11, 10),
);

void main() {
  setUp(etiquetasCerradas.clear);

  group('agruparPorAviso · lo que tiene algo sin leer va primero', () {
    test('agrupa por aviso y suma lo que falta por leer', () {
      final List<AvisoConRespuestas> avisos = agruparPorAviso(<Hilo>[
        hilo(mensajeId: 'm-1', uid: 'a', sinLeerEmisor: 2),
        hilo(mensajeId: 'm-1', uid: 'b', sinLeerEmisor: 1),
        hilo(mensajeId: 'm-2', uid: 'c', titulo: 'Otro aviso'),
      ]);
      expect(avisos, hasLength(2));
      expect(avisos.first.mensajeId, 'm-1');
      expect(avisos.first.sinLeer, 3);
      expect(avisos.first.hilos, hasLength(2));
    });

    test('un aviso con respuestas sin leer va antes que uno más reciente', () {
      // Es sobre lo que hay que actuar, aunque haya llegado antes.
      final List<AvisoConRespuestas> avisos = agruparPorAviso(<Hilo>[
        hilo(mensajeId: 'reciente', actualizadoEn: DateTime(2026, 9, 11, 12)),
        hilo(
          mensajeId: 'viejo',
          sinLeerEmisor: 1,
          actualizadoEn: DateTime(2026, 9, 10),
        ),
      ]);
      expect(avisos.map((AvisoConRespuestas a) => a.mensajeId), <String>[
        'viejo',
        'reciente',
      ]);
    });

    test(
      'dentro de un aviso, igual: primero lo pendiente, luego lo reciente',
      () {
        final AvisoConRespuestas a = agruparPorAviso(<Hilo>[
          hilo(uid: 'leido-reciente', actualizadoEn: DateTime(2026, 9, 11, 12)),
          hilo(
            uid: 'pendiente',
            sinLeerEmisor: 1,
            actualizadoEn: DateTime(2026, 9, 9),
          ),
          hilo(uid: 'leido-viejo', actualizadoEn: DateTime(2026, 9, 8)),
        ]).single;
        expect(a.hilos.map((Hilo h) => h.uid), <String>[
          'pendiente',
          'leido-reciente',
          'leido-viejo',
        ]);
      },
    );
  });

  group('el catedrático responde dentro del aviso', () {
    late RepositorioSesionFalso sesion;
    late RepositorioRespuestasFalso repo;

    setUp(() {
      sesion = RepositorioSesionFalso(
        inicial: SesionActiva(
          usuarioDePrueba(rol: Rol.catedratico, uid: catedraticoUid),
        ),
      );
      repo = RepositorioRespuestasFalso();
    });
    tearDown(() => sesion.cerrar());

    Future<void> montar(WidgetTester tester, MensajeRecibido m) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositorioSesionProvider.overrideWithValue(sesion),
            repositorioRespuestasProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            theme: TemaSian.claro(),
            home: Scaffold(
              body: SingleChildScrollView(child: RespuestaAlAviso(mensaje: m)),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    Finder botonEnviar() =>
        find.widgetWithText(FilledButton, Textos.botonEnviarRespuesta);

    testWidgets('plegada: un botón que dice a quién se responde', (
      WidgetTester tester,
    ) async {
      await montar(tester, aviso());
      expect(find.text(Textos.botonResponderA('Coordinación')), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('al abrirla dice que solo la verá quien envió el aviso', (
      WidgetTester tester,
    ) async {
      // Se dice antes de escribir: que los compañeros no lo verán es parte de
      // decidir qué escribir.
      await montar(tester, aviso());
      await tester.tap(find.text(Textos.botonResponderA('Coordinación')));
      await tester.pump();
      expect(find.text(Textos.ayudaRespuesta('Coordinación')), findsOneWidget);
    });

    testWidgets('enviar manda a su propio hilo y vacía el cuadro', (
      WidgetTester tester,
    ) async {
      await montar(tester, aviso());
      await tester.tap(find.text(Textos.botonResponderA('Coordinación')));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '  No puedo asistir.  ');
      await tester.pump();
      await tester.tap(botonEnviar());
      await tester.pump();

      expect(repo.enviados, hasLength(1));
      expect(repo.enviados.single.texto, 'No puedo asistir.');
      // El catedrático no elige hilo: su hilo es él. Lo decide el servidor.
      expect(repo.enviados.single.hiloUid, isNull);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('sin texto, el botón de enviar no se puede pulsar', (
      WidgetTester tester,
    ) async {
      await montar(tester, aviso());
      await tester.tap(find.text(Textos.botonResponderA('Coordinación')));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(tester.widget<FilledButton>(botonEnviar()).onPressed, isNull);
    });

    testWidgets(
      'DT-24 · mientras se envía, un segundo toque no envía otra vez',
      (WidgetTester tester) async {
        repo.esperaAlResponder = Completer<void>();
        await montar(tester, aviso());
        await tester.tap(find.text(Textos.botonResponderA('Coordinación')));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'No puedo asistir.');
        await tester.pump();

        await tester.tap(botonEnviar());
        await tester.pump();
        expect(find.text(Textos.enviandoRespuesta), findsOneWidget);
        await tester.tap(find.text(Textos.enviandoRespuesta));
        await tester.pump();

        expect(repo.enviados, hasLength(1));
        repo.esperaAlResponder!.complete();
        await tester.pump();
      },
    );

    testWidgets(
      'si falla, lo escrito se queda y el reintento lleva el MISMO turno',
      (WidgetTester tester) async {
        // Si en realidad sí había llegado, el servidor reconoce el turno y no lo
        // duplica. Un identificador nuevo en cada intento lo duplicaría.
        repo.errorAlResponder = FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Sin conexión',
        );
        await montar(tester, aviso());
        await tester.tap(find.text(Textos.botonResponderA('Coordinación')));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'No puedo asistir.');
        await tester.pump();

        await tester.tap(botonEnviar());
        await tester.pump();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'No puedo asistir.',
        );

        await tester.pump(const Duration(seconds: 5));
        await tester.tap(botonEnviar());
        await tester.pump();
        expect(repo.enviados, hasLength(2));
        expect(repo.enviados[1].turnoId, repo.enviados[0].turnoId);
      },
    );

    testWidgets('si cambia el texto tras un fallo, el turno es otro', (
      WidgetTester tester,
    ) async {
      // Reutilizarlo descartaría en silencio lo nuevo si el primero sí llegó.
      repo.errorAlResponder = FirebaseFunctionsException(
        code: 'unavailable',
        message: 'Sin conexión',
      );
      await montar(tester, aviso());
      await tester.tap(find.text(Textos.botonResponderA('Coordinación')));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'No puedo.');
      await tester.pump();
      await tester.tap(botonEnviar());
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));
      await tester.enterText(
        find.byType(TextField),
        'No puedo asistir el viernes.',
      );
      await tester.pump();
      await tester.tap(botonEnviar());
      await tester.pump();

      expect(repo.enviados[1].turnoId, isNot(repo.enviados[0].turnoId));
    });

    testWidgets('un aviso propio no se responde', (WidgetTester tester) async {
      await montar(tester, aviso(creadoPor: catedraticoUid));
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets(
      'con una respuesta sin leer, se marca leída y se cierra su notificación',
      (WidgetTester tester) async {
        repo = RepositorioRespuestasFalso(
          hilosPorMensaje: <String, Hilo>{'m-1': hilo(sinLeerCatedratico: 1)},
        );
        await montar(tester, aviso());

        expect(repo.leidos.single.mensajeId, 'm-1');
        // En Android una notificación olvidada deja el icono marcado (DT-26).
        expect(etiquetasCerradas, contains('respuesta-m-1'));
      },
    );
  });

  group('el emisor ve las respuestas en su panel', () {
    late RepositorioSesionFalso sesion;
    late RepositorioRespuestasFalso repo;

    Future<void> montar(
      WidgetTester tester, {
      List<Hilo> hilos = const <Hilo>[],
      bool recibeAvisos = true,
    }) async {
      sesion = RepositorioSesionFalso(
        inicial: SesionActiva(
          usuarioDePrueba(
            rol: Rol.coordinador,
            uid: emisorUid,
          ).conRecepcion(recibeAvisos),
        ),
      );
      addTearDown(sesion.cerrar);
      repo = RepositorioRespuestasFalso(hilosDelEmisor: hilos);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositorioSesionProvider.overrideWithValue(sesion),
            repositorioRespuestasProvider.overrideWithValue(repo),
            repositorioDispositivosProvider.overrideWithValue(
              RepositorioDispositivosFalso(
                entorno: EntornoNavegador.desconocido,
              ),
            ),
          ],
          child: MaterialApp(
            theme: TemaSian.claro(),
            home: const Scaffold(body: SeccionRespuestas()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('sin respuestas, lo dice', (WidgetTester tester) async {
      await montar(tester);
      expect(find.text(Textos.respuestasVacio), findsOneWidget);
    });

    testWidgets(
      'cada aviso con sus conversaciones, y cuántas faltan por leer',
      (WidgetTester tester) async {
        await montar(
          tester,
          hilos: <Hilo>[
            hilo(uid: 'a', nombre: 'Ana López', sinLeerEmisor: 1),
            hilo(uid: 'b', nombre: 'Luis Pérez'),
          ],
        );
        expect(find.text('Reunión del viernes'), findsOneWidget);
        expect(
          find.text('${Textos.conversaciones(2)} · ${Textos.sinLeer(1)}'),
          findsOneWidget,
        );
        expect(find.text('Ana López'), findsOneWidget);
        expect(find.text('Luis Pérez'), findsOneWidget);
      },
    );

    testWidgets(
      'abrir una conversación la marca leída y cierra su notificación',
      (WidgetTester tester) async {
        await montar(tester, hilos: <Hilo>[hilo(sinLeerEmisor: 1)]);
        await tester.tap(find.text('Ana López'));
        await tester.pumpAndSettle();

        expect(find.byType(PantallaHilo), findsOneWidget);
        expect(repo.leidos.single.hiloUid, catedraticoUid);
        expect(etiquetasCerradas, contains('respuestas-m-1'));
      },
    );

    testWidgets('contestar va al hilo de esa persona', (
      WidgetTester tester,
    ) async {
      // El emisor sí dice en qué hilo escribe: tiene uno por persona.
      await montar(tester, hilos: <Hilo>[hilo()]);
      await tester.tap(find.text('Ana López'));
      await tester.pumpAndSettle();

      expect(find.text(Textos.ayudaContestar('Ana López')), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Gracias por avisar.');
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, Textos.botonEnviarRespuesta),
      );
      await tester.pump();

      expect(repo.enviados.single.hiloUid, catedraticoUid);
    });

    testWidgets(
      'quien no recibe avisos tiene aquí dónde activar notificaciones',
      (WidgetTester tester) async {
        // Sin «Mis mensajes» no tiene otra tarjeta, y sin notificaciones solo se
        // entera de una respuesta al abrir el panel.
        await montar(tester, recibeAvisos: false);
        expect(find.byType(TarjetaNotificaciones), findsOneWidget);
      },
    );

    testWidgets('quien ya recibe avisos no la ve repetida', (
      WidgetTester tester,
    ) async {
      await montar(tester);
      expect(find.byType(TarjetaNotificaciones), findsNothing);
    });
  });

  group('el número junto a la sección', () {
    test('suma lo que el emisor no ha leído', () async {
      final RepositorioSesionFalso sesion = RepositorioSesionFalso(
        inicial: SesionActiva(
          usuarioDePrueba(rol: Rol.coordinador, uid: emisorUid),
        ),
      );
      final ProviderContainer c = ProviderContainer(
        overrides: [
          repositorioSesionProvider.overrideWithValue(sesion),
          repositorioRespuestasProvider.overrideWithValue(
            RepositorioRespuestasFalso(
              hilosDelEmisor: <Hilo>[
                hilo(uid: 'a', sinLeerEmisor: 2),
                hilo(uid: 'b', mensajeId: 'm-2', sinLeerEmisor: 1),
                hilo(uid: 'c'),
              ],
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(sesion.cerrar);

      c.listen(avisosConRespuestasProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(respuestasSinLeerProvider), 3);
    });

    test('para un catedrático es cero, sin consultar nada', () async {
      final RepositorioSesionFalso sesion = RepositorioSesionFalso(
        inicial: SesionActiva(usuarioDePrueba(rol: Rol.catedratico)),
      );
      final ProviderContainer c = ProviderContainer(
        overrides: [
          repositorioSesionProvider.overrideWithValue(sesion),
          repositorioRespuestasProvider.overrideWithValue(
            RepositorioRespuestasFalso(
              hilosDelEmisor: <Hilo>[hilo(sinLeerEmisor: 5)],
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(sesion.cerrar);

      c.listen(avisosConRespuestasProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(c.read(respuestasSinLeerProvider), 0);
    });
  });
}
