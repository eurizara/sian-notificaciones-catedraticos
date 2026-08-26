/// Nota de voz e imagen — RF-MSG-03, 04, 05, 07, 08.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Una nota de voz existe porque escribir con prisa es difícil.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Quien tiene que avisar de una fuga de gas no va a redactar 500 caracteres.
/// De ahí que lo que aquí se prueba no sea «se puede grabar», sino que los
/// límites avisen **mientras** se graba, que el micrófono se suelte siempre, y
/// que un rechazo diga qué hacer en vez de un «no se pudo».
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/core/audio/grabacion.dart';
import 'package:sian/core/plataforma/archivo_elegido.dart';
import 'package:sian/infrastructure/firebase/repositorio_adjuntos.dart';
import 'package:sian/presentation/admin/adjuntos_mensaje.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

/// Grabadora controlable desde la prueba.
class GrabadoraFalsa implements Grabadora {
  GrabadoraFalsa({this.soportada = true, this.fallo, this.resultado});

  @override
  final bool soportada;

  FalloGrabacion? fallo;
  Grabacion? resultado;

  bool _grabando = false;
  int segundosSimulados = 0;
  int vecesQueLibero = 0;
  int vecesQueCancelo = 0;

  @override
  bool get grabando => _grabando;

  @override
  int get segundos => segundosSimulados;

  @override
  Future<FalloGrabacion?> iniciar() async {
    if (fallo != null) {
      return fallo;
    }
    _grabando = true;
    return null;
  }

  @override
  Future<Grabacion?> detener() async {
    _grabando = false;
    return resultado;
  }

  @override
  Future<void> cancelar() async {
    vecesQueCancelo += 1;
    _grabando = false;
  }

  @override
  void liberar() {
    vecesQueLibero += 1;
  }
}

Grabacion grabacion({int segundos = 5, int bytes = 1024}) => Grabacion(
  bytes: Uint8List(bytes),
  tipoMime: 'audio/webm',
  duracionSeg: segundos,
);

/// PNG real de 1×1, no bytes al azar.
///
/// `Image.memory` decodifica de verdad al pintar: unos bytes inventados
/// revientan en la prueba y no dicen nada útil sobre el código.
final Uint8List pngMinimo = Uint8List.fromList(<int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  120,
  218,
  99,
  252,
  207,
  192,
  80,
  15,
  0,
  4,
  133,
  1,
  128,
  132,
  169,
  140,
  33,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
]);

void main() {
  group('límites, comprobados antes de subir', () {
    test('una grabación dentro de los límites es válida', () {
      expect(grabacion().esValida, isTrue);
    });

    test('más de 60 segundos no pasa (RF-MSG-07)', () {
      final Grabacion g = grabacion(segundos: 61);
      expect(g.excedeDuracion, isTrue);
      expect(g.esValida, isFalse);
    });

    test('más de 2 MB tampoco (RF-MSG-07)', () {
      final Grabacion g = grabacion(bytes: 2 * 1024 * 1024 + 1);
      expect(g.excedePeso, isTrue);
      expect(g.esValida, isFalse);
    });

    test('una imagen de más de 5 MB se rechaza (RF-MSG-08)', () {
      // Se comprueba en el cliente para no gastar los datos móviles de nadie
      // en una subida que las reglas de Storage rechazarían igual.
      expect(
        motivoRechazoImagen(bytes: 5 * 1024 * 1024 + 1, tipoMime: 'image/jpeg'),
        'MUY_PESADA',
      );
    });

    test('solo JPEG, PNG y WebP', () {
      for (final String bueno in <String>[
        'image/jpeg',
        'image/png',
        'image/webp',
      ]) {
        expect(motivoRechazoImagen(bytes: 100, tipoMime: bueno), isNull);
      }
      expect(
        motivoRechazoImagen(bytes: 100, tipoMime: 'application/pdf'),
        'FORMATO',
      );
      expect(motivoRechazoImagen(bytes: 100, tipoMime: 'image/gif'), 'FORMATO');
    });

    test('cada rechazo dice qué hacer, no solo que falló', () {
      final Set<String> textos = <String>{
        for (final String m in <String>['VACIA', 'MUY_PESADA', 'FORMATO'])
          Textos.explicarRechazoImagen(m),
      };
      expect(textos.length, 3, reason: 'ninguno repite explicación');
    });

    test('cada fallo de grabación se explica distinto', () {
      // Uno se arregla en los ajustes del navegador y otro conectando un
      // micrófono: mezclarlos en «no se pudo» dejaría a la persona atascada.
      final Set<String> textos = <String>{
        for (final FalloGrabacion f in FalloGrabacion.values)
          Textos.explicarFalloVoz(f),
      };
      expect(textos.length, FalloGrabacion.values.length);
    });
  });

  group('panel de adjuntos', () {
    late GrabadoraFalsa grabadora;
    AdjuntosEnCurso ultimo = const AdjuntosEnCurso();

    setUp(() {
      grabadora = GrabadoraFalsa();
      ultimo = const AdjuntosEnCurso();
    });

    Widget montar({
      AdjuntosEnCurso adjuntos = const AdjuntosEnCurso(),
      Future<ArchivoElegido?> Function()? elegir,
    }) {
      return MaterialApp(
        theme: TemaSian.claro(),
        home: Scaffold(
          body: PanelAdjuntos(
            adjuntos: adjuntos,
            alCambiar: (AdjuntosEnCurso a) => ultimo = a,
            crear: () => grabadora,
            elegir: elegir ?? () async => null,
          ),
        ),
      );
    }

    testWidgets('sin soporte de grabación lo dice, y deja adjuntar imagen', (
      WidgetTester tester,
    ) async {
      // Un botón de grabar que no graba es peor que no ofrecerlo.
      grabadora = GrabadoraFalsa(soportada: false);
      await tester.pumpWidget(montar());
      await tester.pump();

      expect(find.text(Textos.vozSinSoporte), findsOneWidget);
      expect(find.text(Textos.vozGrabar), findsNothing);
      expect(find.text(Textos.imagenElegir), findsOneWidget);
    });

    testWidgets('un permiso denegado explica dónde se arregla', (
      WidgetTester tester,
    ) async {
      grabadora.fallo = FalloGrabacion.permisoDenegado;
      await tester.pumpWidget(montar());
      await tester.pump();

      await tester.tap(find.text(Textos.vozGrabar));
      await tester.pump();

      expect(
        find.text(Textos.explicarFalloVoz(FalloGrabacion.permisoDenegado)),
        findsOneWidget,
      );
    });

    testWidgets('al grabar muestra el tiempo restante', (
      WidgetTester tester,
    ) async {
      // Descubrir a los 70 segundos que el límite eran 60 es perder el mensaje
      // entero. Por eso avisa mientras se graba.
      await tester.pumpWidget(montar());
      await tester.pump();

      await tester.tap(find.text(Textos.vozGrabar));
      await tester.pump();

      expect(find.text(Textos.vozDetener(0)), findsOneWidget);
      expect(
        find.text(Textos.vozRestantes(LimitesVoz.maxSegundos)),
        findsOneWidget,
      );
    });

    testWidgets('detener entrega la grabación', (WidgetTester tester) async {
      grabadora.resultado = grabacion(segundos: 8);
      await tester.pumpWidget(montar());
      await tester.pump();

      await tester.tap(find.text(Textos.vozGrabar));
      await tester.pump();
      await tester.tap(find.text(Textos.vozDetener(0)));
      await tester.pump();

      expect(ultimo.voces, 1);
      expect(ultimo.piezas.whereType<VozEnCurso>().first.grabacion.duracionSeg, 8);
    });

    testWidgets('una grabación vacía se explica y no se adjunta', (
      WidgetTester tester,
    ) async {
      grabadora.resultado = null;
      await tester.pumpWidget(montar());
      await tester.pump();

      await tester.tap(find.text(Textos.vozGrabar));
      await tester.pump();
      await tester.tap(find.text(Textos.vozDetener(0)));
      await tester.pump();

      expect(find.text(Textos.vozSinContenido), findsOneWidget);
      expect(ultimo.voces, 0);
    });

    testWidgets('cerrar la pantalla SUELTA el micrófono', (
      WidgetTester tester,
    ) async {
      // Un flujo abierto deja el indicador de grabación encendido en el
      // teléfono. Que un catedrático crea que le están escuchando no se
      // arregla explicándolo después.
      await tester.pumpWidget(montar());
      await tester.pump();
      await tester.tap(find.text(Textos.vozGrabar));
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(grabadora.vecesQueLibero, 1);
    });

    testWidgets('una imagen válida se adjunta con su vista previa', (
      WidgetTester tester,
    ) async {
      final ArchivoElegido elegida = ArchivoElegido(
        bytes: pngMinimo,
        tipoMime: 'image/png',
        nombre: 'plano.png',
      );

      await tester.pumpWidget(montar(elegir: () async => elegida));
      await tester.pump();

      await tester.tap(find.text(Textos.imagenElegir));
      await tester.pump();

      expect(ultimo.imagenes, 1);
      expect(ultimo.piezas.whereType<ImagenEnCurso>().first.archivo.nombre, 'plano.png');
    });

    testWidgets('una imagen inadmisible se rechaza con su motivo', (
      WidgetTester tester,
    ) async {
      final ArchivoElegido pdf = ArchivoElegido(
        bytes: Uint8List(100),
        tipoMime: 'application/pdf',
        nombre: 'documento.pdf',
      );

      await tester.pumpWidget(montar(elegir: () async => pdf));
      await tester.pump();

      await tester.tap(find.text(Textos.imagenElegir));
      await tester.pump();

      expect(
        find.text(Textos.explicarRechazoImagen('FORMATO')),
        findsOneWidget,
      );
      expect(ultimo.imagenes, 0);
    });

    testWidgets('se puede quitar un adjunto ya puesto', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(adjuntos: AdjuntosEnCurso(<AdjuntoEnCurso>[VozEnCurso(grabacion(segundos: 12))])),
      );
      await tester.pump();

      expect(find.text(Textos.vozAdjunta(12)), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(ultimo.voces, 0);
    });

    testWidgets('voz e imagen pueden ir juntas (RF-MSG-05)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(
          adjuntos: AdjuntosEnCurso(<AdjuntoEnCurso>[
            VozEnCurso(grabacion(segundos: 3)),
            ImagenEnCurso(
              ArchivoElegido(
                bytes: pngMinimo,
                tipoMime: 'image/png',
                nombre: 'ruta.png',
              ),
            ),
          ]),
        ),
      );
      await tester.pump();

      expect(find.text(Textos.vozAdjunta(3)), findsOneWidget);
      expect(find.text('ruta.png'), findsOneWidget);
    });

    // ────────────────────────────────────────────────────────────────────────
    // LOS DOS, PERO PUESTOS DE UNO EN UNO.
    // ────────────────────────────────────────────────────────────────────────
    //
    // La prueba de arriba entrega el panel con las dos cosas ya dentro, y así
    // nunca ejecuta el momento en que se añade la segunda. Es justo ahí donde
    // se puede perder la primera, porque cada camino tiene que acordarse de
    // conservar lo que ya había.
    //
    // Además el panel se monta aquí bajo un padre que le devuelve el valor
    // nuevo, como en la aplicación real. Con `alCambiar` guardando en una
    // variable y nada más, `widget.adjuntos` se queda en el valor inicial y la
    // prueba deja de mirar lo que mira la pantalla.
    group('añadidos de uno en uno', () {
      final ArchivoElegido png = ArchivoElegido(
        bytes: pngMinimo,
        tipoMime: 'image/png',
        nombre: 'plano.png',
      );

      Widget montarConEstado() => MaterialApp(
        theme: TemaSian.claro(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext _, StateSetter poner) => PanelAdjuntos(
              adjuntos: ultimo,
              alCambiar: (AdjuntosEnCurso a) => poner(() => ultimo = a),
              crear: () => grabadora,
              elegir: () async => png,
            ),
          ),
        ),
      );

      testWidgets('imagen primero y voz después: quedan las dos', (
        WidgetTester tester,
      ) async {
        grabadora.resultado = grabacion(segundos: 7);
        await tester.pumpWidget(montarConEstado());
        await tester.pump();

        await tester.tap(find.text(Textos.imagenElegir));
        await tester.pumpAndSettle();

        await tester.tap(find.text(Textos.vozGrabar));
        await tester.pump();
        await tester.tap(find.textContaining(Textos.vozDetener(0).split(' ')[0]));
        await tester.pumpAndSettle();

        expect(ultimo.voces, 1, reason: 'la voz recién grabada');
        expect(ultimo.imagenes, 1, reason: 'la imagen NO se pierde');
      });

      testWidgets('voz primero e imagen después: quedan las dos', (
        WidgetTester tester,
      ) async {
        grabadora.resultado = grabacion(segundos: 7);
        await tester.pumpWidget(montarConEstado());
        await tester.pump();

        await tester.tap(find.text(Textos.vozGrabar));
        await tester.pump();
        await tester.tap(find.textContaining(Textos.vozDetener(0).split(' ')[0]));
        await tester.pumpAndSettle();

        await tester.tap(find.text(Textos.imagenElegir));
        await tester.pumpAndSettle();

        expect(ultimo.imagenes, 1, reason: 'la imagen recién elegida');
        expect(ultimo.voces, 1, reason: 'la voz NO se pierde');
      });
    });
  });

  group('peso legible', () {
    test('se lee en la unidad que corresponde', () {
      expect(Textos.pesoLegible(512), '512 B');
      expect(Textos.pesoLegible(2048), '2 KB');
      expect(Textos.pesoLegible(3 * 1024 * 1024), '3.0 MB');
    });
  });
}
