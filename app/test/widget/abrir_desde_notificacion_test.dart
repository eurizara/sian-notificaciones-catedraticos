/// Tocar una notificación lleva a lo que la originó (RF-ENT-07, C-6, DT-35).
///
/// Reportado el 24/09/2026 probando en QA: tocar la notificación de una
/// respuesta dejaba la aplicación en la bandeja, en «Sin leer». Con el aviso
/// ya leído no había forma de llegar a la respuesta. El criterio que fijó el
/// responsable: se llega a ella **sin importar el filtro en que esté el aviso**
/// ni la pantalla en que se haya quedado la aplicación.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_dispositivos.dart';
import 'package:sian/application/proveedores_programacion.dart';
import 'package:sian/application/proveedores_respuestas.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/core/navegador.dart';
import 'package:sian/core/plataforma/apertura.dart';
import 'package:sian/domain/repositorios.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/infrastructure/firebase/repositorio_respuestas.dart';
import 'package:sian/presentation/admin/seccion_respuestas.dart';
import 'package:sian/presentation/docente/bandeja_docente.dart';
import 'package:sian/presentation/shared/apertura.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

MensajeRecibido _aviso(
  String id,
  String titulo, {
  String estado = 'ENTREGADO',
  bool requiereConfirmacion = false,
}) => MensajeRecibido(
  mensajeId: id,
  titulo: titulo,
  cuerpo: 'Cuerpo de $titulo.',
  tipo: 'INFORMATIVO',
  estado: estado,
  requiereConfirmacion: requiereConfirmacion,
  entregadoEn: DateTime.utc(2026, 9, 20, 13),
);

void main() {
  setUp(() {
    parametrosDePrueba = <String, String>{};
    vecesQueSeLimpio = 0;
    aperturaGuardadaDePrueba = null;
  });

  group('DestinoApertura.desde', () {
    test('un aviso', () {
      expect(
        DestinoApertura.desde(<String, String>{'abrir': 'aviso', 'aviso': 'm-1'}),
        const DestinoApertura.aviso('m-1'),
      );
    });

    test('una conversación', () {
      expect(
        DestinoApertura.desde(<String, String>{
          'abrir': 'hilo',
          'aviso': 'm-1',
          'hilo': 'cat-1',
        }),
        const DestinoApertura.hilo('m-1', 'cat-1'),
      );
    });

    test('una conversación sin persona válida se queda en el aviso', () {
      expect(
        DestinoApertura.desde(<String, String>{
          'abrir': 'hilo',
          'aviso': 'm-1',
          'hilo': 'a/b',
        }),
        const DestinoApertura.aviso('m-1'),
      );
    });

    test('lo que no tiene forma de identificador se descarta', () {
      // Estos valores terminan en consultas a Firestore.
      for (final String malo in <String>['', '../x', 'a/b', 'x' * 200]) {
        expect(
          DestinoApertura.desde(<String, String>{'abrir': 'aviso', 'aviso': malo}),
          isNull,
          reason: malo,
        );
      }
      expect(DestinoApertura.desde(<String, String>{'aviso': 'm-1'}), isNull);
      expect(DestinoApertura.desde(const <String, String>{}), isNull);
    });
  });

  group('la dirección con la que arranca', () {
    test('se lee y se borra, para que recargar no lo vuelva a abrir', () {
      parametrosDePrueba = <String, String>{'abrir': 'aviso', 'aviso': 'm-7'};
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);

      expect(c.read(aperturaPendienteProvider), const DestinoApertura.aviso('m-7'));
      expect(vecesQueSeLimpio, 1);
    });

    test('sin destino no se toca la dirección', () {
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(aperturaPendienteProvider), isNull);
      expect(vecesQueSeLimpio, 0);
    });
  });

  group('en la bandeja: el aviso se muestra y se despliega, esté donde esté', () {
    late RepositorioProgramacionFalso programacion;
    setUp(() => programacion = RepositorioProgramacionFalso());

    Future<ProviderContainer> montar(
      WidgetTester tester,
      List<MensajeRecibido> mensajes,
    ) async {
      final ProviderContainer c = ProviderContainer(
        overrides: [
          repositorioSesionProvider.overrideWithValue(RepositorioSesionFalso()),
          repositorioBandejaProvider.overrideWithValue(
            RepositorioBandejaFalso(mensajes),
          ),
          repositorioProgramacionProvider.overrideWithValue(programacion),
        ],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: TemaSian.claro(),
            home: EscuchaDeAperturas(
              child: BandejaDocente(
                usuario: usuarioDePrueba(rol: Rol.catedratico, uid: 'uid-1'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return c;
    }

    final List<MensajeRecibido> tres = <MensajeRecibido>[
      _aviso('m-nuevo', 'Aviso nuevo'),
      _aviso('m-leido', 'Aviso ya leído', estado: 'ABIERTO'),
      _aviso(
        'm-confirmar',
        'Aviso por confirmar',
        estado: 'ABIERTO',
        requiereConfirmacion: true,
      ),
    ];

    testWidgets('uno ya LEÍDO, con la bandeja en «Sin leer»: el caso reportado', (
      WidgetTester tester,
    ) async {
      final ProviderContainer c = await montar(tester, tres);
      // Arranca en «Sin leer»: el leído no se ve.
      expect(find.text('Aviso ya leído'), findsNothing);

      c
          .read(aperturaPendienteProvider.notifier)
          .fijar(const DestinoApertura.aviso('m-leido'));
      await tester.pumpAndSettle();

      expect(find.text('Aviso ya leído'), findsOneWidget);
      expect(find.text('Cuerpo de Aviso ya leído.'), findsOneWidget);
      expect(c.read(aperturaPendienteProvider), isNull, reason: 'queda atendido');
    });

    testWidgets('uno en «Sin confirmar» también', (WidgetTester tester) async {
      final ProviderContainer c = await montar(tester, tres);
      c
          .read(aperturaPendienteProvider.notifier)
          .fijar(const DestinoApertura.aviso('m-confirmar'));
      await tester.pumpAndSettle();

      expect(find.text('Cuerpo de Aviso por confirmar.'), findsOneWidget);
    });

    testWidgets('va PRIMERO en la lista: si no, podría quedar fuera de pantalla', (
      WidgetTester tester,
    ) async {
      final List<MensajeRecibido> muchos = <MensajeRecibido>[
        for (int i = 0; i < 30; i += 1) _aviso('m-$i', 'Aviso $i'),
        _aviso('m-viejo', 'Aviso viejo', estado: 'ABIERTO'),
      ];
      final ProviderContainer c = await montar(tester, muchos);
      c
          .read(aperturaPendienteProvider.notifier)
          .fijar(const DestinoApertura.aviso('m-viejo'));
      await tester.pumpAndSettle();

      final double yViejo = tester.getTopLeft(find.text('Aviso viejo')).dy;
      final double yPrimero = tester.getTopLeft(find.text('Aviso 0')).dy;
      expect(yViejo, lessThan(yPrimero));
      expect(find.text('Cuerpo de Aviso viejo.'), findsOneWidget);
    });

    testWidgets('un aviso sin leer se registra como abierto al desplegarse', (
      WidgetTester tester,
    ) async {
      final ProviderContainer c = await montar(tester, tres);
      c
          .read(aperturaPendienteProvider.notifier)
          .fijar(const DestinoApertura.aviso('m-nuevo'));
      await tester.pumpAndSettle();

      expect(programacion.abiertos, contains('m-nuevo'));
    });

    testWidgets('una búsqueda escrita no lo esconde', (WidgetTester tester) async {
      // El buscador aparece con más de cinco mensajes.
      final ProviderContainer c = await montar(tester, <MensajeRecibido>[
        ...tres,
        for (int i = 0; i < 4; i += 1) _aviso('m-extra-$i', 'Extra $i'),
      ]);
      await tester.enterText(find.byType(TextField).first, 'nada que coincida');
      await tester.pumpAndSettle();

      c
          .read(aperturaPendienteProvider.notifier)
          .fijar(const DestinoApertura.aviso('m-leido'));
      await tester.pumpAndSettle();

      expect(find.text('Cuerpo de Aviso ya leído.'), findsOneWidget);
    });

    testWidgets('con la app abierta, el aviso del worker lleva al aviso', (
      WidgetTester tester,
    ) async {
      final ProviderContainer c = await montar(tester, tres);
      simularAperturaDesdeElWorker(<String, String>{
        'tipo': 'sian:abrir',
        'abrir': 'aviso',
        'aviso': 'm-leido',
        'hilo': '',
      });
      await tester.pumpAndSettle();

      expect(find.text('Cuerpo de Aviso ya leído.'), findsOneWidget);
      expect(c.read(aperturaPendienteProvider), isNull);
    });

    testWidgets('iPhone: al volver al frente se recoge lo que guardó el worker', (
      WidgetTester tester,
    ) async {
      // El caso del 25/09/2026: el mensaje a la app congelada se perdió y la
      // app volvió en «Sin leer». Lo guardado por el worker lo rescata.
      final ProviderContainer c = await montar(tester, tres);
      aperturaGuardadaDePrueba = <String, String>{
        'abrir': 'aviso',
        'aviso': 'm-leido',
        'hilo': '',
      };
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Cuerpo de Aviso ya leído.'), findsOneWidget);
      expect(c.read(aperturaPendienteProvider), isNull);
      expect(aperturaGuardadaDePrueba, isNull, reason: 'se borra al tomarlo');
    });

    testWidgets('el guardado manda sobre el mensaje, y el mismo destino no se abre dos veces', (
      WidgetTester tester,
    ) async {
      final ProviderContainer c = await montar(tester, tres);
      aperturaGuardadaDePrueba = <String, String>{
        'abrir': 'aviso',
        'aviso': 'm-confirmar',
        'hilo': '',
      };
      int fijados = 0;
      c.listen<DestinoApertura?>(aperturaPendienteProvider, (DestinoApertura? _, DestinoApertura? d) {
        if (d != null) {
          fijados += 1;
        }
      });
      // El mensaje dice otra cosa: manda lo guardado, que es lo que se borra.
      simularAperturaDesdeElWorker(<String, String>{
        'abrir': 'aviso',
        'aviso': 'm-confirmar',
        'hilo': '',
      });
      await tester.pumpAndSettle();
      // Y el mismo mensaje, entregado tarde al descongelarse, no reabre.
      simularAperturaDesdeElWorker(<String, String>{
        'abrir': 'aviso',
        'aviso': 'm-confirmar',
        'hilo': '',
      });
      await tester.pumpAndSettle();

      expect(fijados, 1);
      expect(find.text('Cuerpo de Aviso por confirmar.'), findsOneWidget);
    });

    testWidgets('un aviso que no está en la bandeja se descarta sin romper nada', (
      WidgetTester tester,
    ) async {
      final ProviderContainer c = await montar(tester, tres);
      c
          .read(aperturaPendienteProvider.notifier)
          .fijar(const DestinoApertura.aviso('m-inexistente'));
      await tester.pumpAndSettle();

      expect(c.read(aperturaPendienteProvider), isNull);
      expect(find.text('Aviso nuevo'), findsOneWidget);
    });
  });

  group('en Respuestas: se abre ESA conversación', () {
    const String emisor = 'uid-coordinador';
    Hilo hilo(String uid, String nombre) => Hilo(
      mensajeId: 'm-1',
      uid: uid,
      nombre: nombre,
      emisorUid: emisor,
      tituloAviso: 'Reunión del viernes',
      emisorNombre: 'Coordinación',
      sinLeerEmisor: 1,
      sinLeerCatedratico: 0,
      ultimaVista: 'No puedo asistir.',
      actualizadoEn: DateTime(2026, 9, 24, 10),
    );

    testWidgets('la de la persona que respondió, no otra', (
      WidgetTester tester,
    ) async {
      final RepositorioSesionFalso sesion = RepositorioSesionFalso(
        inicial: SesionActiva(
          usuarioDePrueba(rol: Rol.coordinador, uid: emisor).conRecepcion(false),
        ),
      );
      addTearDown(sesion.cerrar);
      final ProviderContainer c = ProviderContainer(
        overrides: [
          repositorioSesionProvider.overrideWithValue(sesion),
          repositorioRespuestasProvider.overrideWithValue(
            RepositorioRespuestasFalso(
              hilosDelEmisor: <Hilo>[hilo('ana', 'Ana López'), hilo('luis', 'Luis Pérez')],
            ),
          ),
          repositorioDispositivosProvider.overrideWithValue(
            RepositorioDispositivosFalso(entorno: EntornoNavegador.desconocido),
          ),
        ],
      );
      addTearDown(c.dispose);
      c
          .read(aperturaPendienteProvider.notifier)
          .fijar(const DestinoApertura.hilo('m-1', 'luis'));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: TemaSian.claro(),
            home: const Scaffold(body: SeccionRespuestas()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final PantallaHilo abierta = tester.widget(find.byType(PantallaHilo));
      expect(abierta.hilo.uid, 'luis');
      expect(c.read(aperturaPendienteProvider), isNull);
      // Volver atrás no la abre otra vez.
      Navigator.of(tester.element(find.byType(PantallaHilo))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(PantallaHilo), findsNothing);
      expect(find.text(Textos.seccionRespuestasTitulo), findsOneWidget);
    });
  });
}
