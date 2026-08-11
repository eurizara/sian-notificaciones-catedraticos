/// Capturas para los manuales de usuario.
///
/// ────────────────────────────────────────────────────────────────────────────
/// NO SON PRUEBAS. No afirman nada: dibujan pantallas y las guardan como PNG.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Viven fuera de `test/` a propósito, porque `flutter test` recorre esa
/// carpeta y esto no debe correr en integración continua: sobrescribiría las
/// imágenes en cada rama, y sin las fuentes del SDK a mano las escribiría con
/// el texto convertido en cajas negras.
///
/// Se generan a mano, cuando la interfaz cambia:
///
///     flutter test test_capturas --update-goldens
///
/// Por qué así y no capturando la aplicación de verdad:
///
///   · Sale el widget real, con el tema real y el texto real. No es un dibujo
///     ni una maqueta: es exactamente lo que ve una persona.
///   · Los datos son inventados. Las capturas del panel de verdad llevan
///     nombres y mensajes de personas reales, y este manual se publica abierto.
///   · Se rehacen con un comando cuando la pantalla cambie, en vez de volver a
///     tomar veinte fotos a mano y descubrir a los seis meses que la mitad
///     enseñan una versión que ya no existe.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_dispositivos.dart';
import 'package:sian/application/proveedores_grupos.dart';
import 'package:sian/application/proveedores_programacion.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/core/audio/grabacion.dart';
import 'package:sian/core/navegador.dart';
import 'package:sian/core/plataforma/archivo_elegido.dart';
import 'package:sian/domain/repositorios.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';
import 'package:sian/infrastructure/firebase/repositorio_dispositivos.dart';
import 'package:sian/infrastructure/firebase/repositorio_programacion.dart';
import 'package:sian/presentation/admin/adjuntos_mensaje.dart';
import 'package:sian/presentation/admin/seccion_entregas.dart';
import 'package:sian/presentation/admin/seccion_mensajes.dart';
import 'package:sian/presentation/admin/seccion_programacion.dart';
import 'package:sian/presentation/docente/bandeja_docente.dart';
import 'package:sian/presentation/docente/instructivo_ios.dart';
import 'package:sian/presentation/shared/pantalla_ingreso.dart';
import 'package:sian/presentation/shared/tema.dart';

import '../test/dobles/repositorios_falsos.dart';

/// Dónde se guardan. Es la carpeta que sirve el sitio de manuales.
const String _carpeta = '../web/manuales/img';

/// Tamaños que se corresponden con dispositivos reales.
const Size _escritorio = Size(1280, 800);
const Size _movil = Size(390, 844);

// ─────────────────────────────────────────────────────────────────────────────
// FUENTES REALES.
// ─────────────────────────────────────────────────────────────────────────────
//
// Sin esto, el motor de pruebas dibuja cada carácter como un rectángulo negro:
// las imágenes saldrían con la forma correcta y el texto ilegible, que para un
// manual es peor que no tener imagen. Se cargan las Roboto que el propio SDK
// de Flutter trae consigo.
Future<void> _cargarFuentes() async {
  final List<String> raices = <String>[
    '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts',
    '${Platform.environment['FLUTTER_ROOT'] ?? ''}/bin/cache/artifacts/material_fonts',
  ];
  final String? raiz = raices
      .firstWhere(
        (String r) => r.isNotEmpty && Directory(r).existsSync(),
        orElse: () => '',
      )
      .let((String r) => r.isEmpty ? null : r);

  if (raiz == null) {
    fail(
      'No se encontraron las fuentes del SDK. Sin ellas las capturas saldrían '
      'con el texto en cajas negras. Define FLUTTER_ROOT y vuelve a intentarlo.',
    );
  }

  Future<void> cargar(String familia, List<String> archivos) async {
    final FontLoader cargador = FontLoader(familia);
    for (final String archivo in archivos) {
      final File f = File('$raiz/$archivo');
      if (f.existsSync()) {
        cargador.addFont(
          Future<ByteData>.value(ByteData.view(f.readAsBytesSync().buffer)),
        );
      }
    }
    await cargador.load();
  }

  await cargar('Roboto', <String>[
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]);

  // Sin esta, cada icono sale como un cuadrado vacío. La mitad de lo que una
  // pantalla comunica son sus iconos: el sobre abierto, el sello de
  // confirmado, la campana.
  await cargar('MaterialIcons', <String>['MaterialIcons-Regular.otf']);
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

/// El tema de la aplicación, con la fuente ya cargada.
ThemeData _tema() {
  final ThemeData base = TemaSian.claro();
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
  );
}

/// Deja el lienzo del tamaño de un dispositivo real.
Future<void> _encuadrar(WidgetTester tester, Size tamano) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Dibuja, espera a que todo asiente y guarda.
Future<void> _guardar(WidgetTester tester, String nombre) async {
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('$_carpeta/$nombre.png'),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DATOS INVENTADOS, PERO VEROSÍMILES.
// ─────────────────────────────────────────────────────────────────────────────
//
// Nombres y asuntos que podrían ser los de la sede sin ser los de nadie. Un
// manual ilustrado con «prueba 1, prueba 2» no enseña a leer la pantalla.

DateTime _cuando(int dia, int hora, int minuto) =>
    DateTime(2026, 3, dia, hora, minuto);

final List<MensajeRecibido> _bandeja = <MensajeRecibido>[
  MensajeRecibido(
    mensajeId: 'm1',
    titulo: 'Simulacro de evacuación mañana a las 10:00',
    cuerpo:
        'Mañana se realizará el simulacro anual. Al sonar la alarma, dirija a '
        'sus estudiantes por la salida norte hasta el punto de reunión en el '
        'parqueo. Confirme la lectura de este aviso.',
    tipo: 'URGENTE',
    estado: 'ENTREGADO',
    requiereConfirmacion: true,
    emisor: 'Lucía Marroquín',
    entregadoEn: _cuando(17, 8, 5),
  ),
  MensajeRecibido(
    mensajeId: 'm2',
    titulo: 'Entrega de actas de medio ciclo',
    cuerpo:
        'El plazo para subir las actas vence el viernes 20 a las 17:00. '
        'Recuerde firmar cada una antes de entregarla en coordinación.',
    tipo: 'INFORMATIVO',
    estado: 'ENTREGADO',
    requiereConfirmacion: true,
    emisor: 'Coordinación Académica',
    entregadoEn: _cuando(16, 14, 30),
  ),
  MensajeRecibido(
    mensajeId: 'm3',
    titulo: 'Nuevo parqueo habilitado para catedráticos',
    cuerpo:
        'A partir del lunes queda habilitado el parqueo posterior. El ingreso '
        'es por la garita 2 presentando su carné.',
    tipo: 'INFORMATIVO',
    estado: 'ENTREGADO',
    requiereConfirmacion: false,
    emisor: 'Administración',
    entregadoEn: _cuando(15, 9, 12),
  ),
  MensajeRecibido(
    mensajeId: 'm4',
    titulo: 'Capacitación en evaluación por competencias',
    cuerpo:
        'La capacitación se traslada al sábado 28 en el aula magna, de 8:00 a '
        '12:00. Se entregará constancia.',
    tipo: 'INFORMATIVO',
    estado: 'ABIERTO',
    requiereConfirmacion: false,
    emisor: 'Lucía Marroquín',
    entregadoEn: _cuando(14, 16, 40),
  ),
  MensajeRecibido(
    mensajeId: 'm5',
    titulo: 'Cambio de aula para Programación III',
    cuerpo:
        'El curso pasa del aula 204 al laboratorio 3 a partir de esta semana.',
    tipo: 'INFORMATIVO',
    estado: 'CONFIRMADO',
    requiereConfirmacion: true,
    emisor: 'Coordinación Académica',
    entregadoEn: _cuando(13, 11, 0),
    confirmadoEn: _cuando(13, 11, 22),
  ),
];

final List<MensajeProgramado> _programados = <MensajeProgramado>[
  MensajeProgramado(
    id: 'p1',
    titulo: 'Recordatorio de entrega de actas',
    tipo: 'INFORMATIVO',
    estado: 'PROGRAMADO',
    modo: 'UNICO',
    creadoPor: 'uid-1',
    emisor: 'Lucía Marroquín',
    requiereConfirmacion: true,
    modoDestinatarios: 'TODOS',
    formato: const <String>['TEXTO'],
    proximaOcurrencia: _cuando(20, 7, 0),
    totalDestinatarios: 48,
  ),
  MensajeProgramado(
    id: 'p2',
    titulo: 'Aviso semanal de coordinación',
    tipo: 'INFORMATIVO',
    estado: 'PROGRAMADO',
    modo: 'RECURRENTE',
    creadoPor: 'uid-1',
    emisor: 'Coordinación Académica',
    requiereConfirmacion: false,
    modoDestinatarios: 'GRUPOS',
    nombresGrupos: const <String>['Ingeniería', 'Jornada nocturna'],
    formato: const <String>['TEXTO', 'VOZ'],
    proximaOcurrencia: _cuando(23, 6, 30),
    totalDestinatarios: 31,
  ),
  MensajeProgramado(
    id: 'p3',
    titulo: 'Simulacro de evacuación mañana a las 10:00',
    tipo: 'URGENTE',
    estado: 'ENVIADO',
    modo: 'UNICO',
    creadoPor: 'uid-1',
    emisor: 'Lucía Marroquín',
    requiereConfirmacion: true,
    modoDestinatarios: 'TODOS',
    formato: const <String>['TEXTO', 'VOZ', 'IMAGEN'],
    enviadoEn: _cuando(17, 8, 5),
    totalDestinatarios: 48,
    entregados: 48,
    confirmados: 41,
  ),
];

UsuarioSesion _catedratico() => usuarioDePrueba(
  rol: Rol.catedratico,
  nombre: 'Ana Sofía Ramírez',
  correo: 'aramirez@umg.edu.gt',
);

UsuarioSesion _administradora() => usuarioDePrueba(
  rol: Rol.administradora,
  nombre: 'Lucía Marroquín',
  correo: 'lmarroquin@umg.edu.gt',
  puedeEmitirUrgentes: true,
);

void main() {
  setUpAll(_cargarFuentes);

  late RepositorioSesionFalso sesion;
  late RepositorioDispositivosFalso dispositivos;

  setUp(() {
    sesion = RepositorioSesionFalso();
    // Instalada y con el permiso dado: es el estado en el que está quien ya
    // siguió el manual, y el que deben mostrar las capturas de uso normal.
    dispositivos = RepositorioDispositivosFalso(
      entorno: const EntornoNavegador(
        plataforma: PlataformaWeb.android,
        instalada: true,
        navegador: 'Chrome',
        soportaNotificaciones: true,
        versionIos: null,
      ),
      permiso: EstadoPermiso.concedido,
    );
  });
  tearDown(() async {
    await sesion.cerrar();
    await dispositivos.cerrar();
  });

  Widget envolver(Widget hijo, {List<dynamic> extras = const <dynamic>[]}) =>
      ProviderScope(
        overrides: [
          repositorioSesionProvider.overrideWithValue(sesion),
          repositorioDispositivosProvider.overrideWithValue(dispositivos),
          ...extras.cast(),
        ],
        child: MaterialApp(
          theme: _tema(),
          // El distintivo de «DEBUG» de la esquina no existe en la aplicación
          // publicada; dejarlo haría que las capturas mostraran algo que
          // nadie va a ver nunca.
          debugShowCheckedModeBanner: false,
          home: hijo,
        ),
      );

  // ───────────────────────────── Acceso ─────────────────────────────

  testWidgets('ingreso · escritorio', (WidgetTester tester) async {
    await _encuadrar(tester, _escritorio);
    await tester.pumpWidget(envolver(const PantallaIngreso()));
    await _guardar(tester, 'ingreso-escritorio');
  });

  testWidgets('ingreso · móvil', (WidgetTester tester) async {
    await _encuadrar(tester, _movil);
    await tester.pumpWidget(envolver(const PantallaIngreso()));
    await _guardar(tester, 'ingreso-movil');
  });

  testWidgets('instructivo de instalación en iPhone', (
    WidgetTester tester,
  ) async {
    await _encuadrar(tester, _movil);
    await tester.pumpWidget(
      envolver(
        const InstructivoIos(
          entorno: EntornoNavegador(
            plataforma: PlataformaWeb.ios,
            instalada: false,
            navegador: 'Safari',
            soportaNotificaciones: false,
            versionIos: 18,
            versionIosMenor: 2,
          ),
        ),
      ),
    );
    await _guardar(tester, 'instructivo-ios');
  });

  // ─────────────────────────── Catedrático ───────────────────────────

  testWidgets('bandeja del catedrático · móvil', (WidgetTester tester) async {
    await _encuadrar(tester, _movil);
    await tester.pumpWidget(
      envolver(
        BandejaDocente(usuario: _catedratico()),
        extras: <dynamic>[
          repositorioBandejaProvider.overrideWithValue(
            RepositorioBandejaFalso(_bandeja),
          ),
        ],
      ),
    );
    await _guardar(tester, 'bandeja-movil');
  });

  testWidgets('bandeja del catedrático · escritorio', (
    WidgetTester tester,
  ) async {
    await _encuadrar(tester, _escritorio);
    await tester.pumpWidget(
      envolver(
        BandejaDocente(usuario: _catedratico()),
        extras: <dynamic>[
          repositorioBandejaProvider.overrideWithValue(
            RepositorioBandejaFalso(_bandeja),
          ),
        ],
      ),
    );
    await _guardar(tester, 'bandeja-escritorio');
  });

  testWidgets('un mensaje desplegado, con su botón de confirmar', (
    WidgetTester tester,
  ) async {
    await _encuadrar(tester, _movil);
    await tester.pumpWidget(
      envolver(
        BandejaDocente(usuario: _catedratico()),
        extras: <dynamic>[
          repositorioBandejaProvider.overrideWithValue(
            RepositorioBandejaFalso(_bandeja),
          ),
          repositorioProgramacionProvider.overrideWithValue(
            RepositorioProgramacionFalso(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrega de actas de medio ciclo'));
    await _guardar(tester, 'mensaje-desplegado');
  });

  // ───────────────────── Administrador académico ─────────────────────

  testWidgets('redactar un aviso', (WidgetTester tester) async {
    await _encuadrar(tester, _escritorio);
    sesion.emitir(SesionActiva(_administradora()));
    await tester.pumpWidget(
      envolver(
        Scaffold(
          body: SeccionMensajes(
            // Fuera del navegador no hay micrófono, y sin esto la pantalla
            // diría «este navegador no puede grabar audio»: verdad en una
            // prueba, mentira en el manual.
            crearGrabadora: _GrabadoraQuieta.new,
            elegirImagen: () async => null,
          ),
        ),
        extras: <dynamic>[
          repositorioEnvioProvider.overrideWithValue(RepositorioEnvioFalso()),
          repositorioGruposProvider.overrideWithValue(RepositorioGruposFalso()),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Simulacro de evacuación mañana a las 10:00',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Al sonar la alarma, dirija a sus estudiantes por la salida norte hasta '
      'el punto de reunión en el parqueo.',
    );
    await _guardar(tester, 'redactar');
  });

  testWidgets('el panel de adjuntos, con voz e imagen ya puestas', (
    WidgetTester tester,
  ) async {
    await _encuadrar(tester, const Size(760, 620));
    await tester.pumpWidget(
      MaterialApp(
        theme: _tema(),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: PanelAdjuntos(
              adjuntos: AdjuntosEnCurso(<AdjuntoEnCurso>[
                ImagenEnCurso(
                  ArchivoElegido(
                    bytes: _pngGris,
                    tipoMime: 'image/png',
                    nombre: 'ruta-de-evacuacion.png',
                  ),
                ),
                VozEnCurso(
                  Grabacion(
                    bytes: Uint8List(184320),
                    tipoMime: 'audio/webm',
                    duracionSeg: 24,
                  ),
                ),
              ]),
              alCambiar: (AdjuntosEnCurso _) {},
              crear: _GrabadoraQuieta.new,
              elegir: () async => null,
            ),
          ),
        ),
      ),
    );
    await _guardar(tester, 'adjuntos');
  });

  testWidgets('programados', (WidgetTester tester) async {
    await _encuadrar(tester, _escritorio);
    sesion.emitir(SesionActiva(_administradora()));
    await tester.pumpWidget(
      envolver(
        const Scaffold(body: SeccionProgramacion()),
        extras: <dynamic>[
          repositorioProgramacionProvider.overrideWithValue(
            RepositorioProgramacionFalso(programados: _programados),
          ),
        ],
      ),
    );
    await _guardar(tester, 'programados');
  });

  testWidgets('entregas', (WidgetTester tester) async {
    await _encuadrar(tester, _escritorio);
    sesion.emitir(SesionActiva(_administradora()));
    await tester.pumpWidget(
      envolver(
        const Scaffold(body: SeccionEntregas()),
        extras: <dynamic>[
          repositorioProgramacionProvider.overrideWithValue(
            RepositorioProgramacionFalso(programados: _programados),
          ),
        ],
      ),
    );
    await _guardar(tester, 'entregas');
  });
}

/// Grabadora que no graba: en una captura solo tiene que existir.
class _GrabadoraQuieta implements Grabadora {
  @override
  bool get soportada => true;
  @override
  bool get grabando => false;
  @override
  int get segundos => 0;
  @override
  Future<FalloGrabacion?> iniciar() async => null;
  @override
  Future<Grabacion?> detener() async => null;
  @override
  Future<void> cancelar() async {}
  @override
  void liberar() {}
}

/// PNG gris de 8×8: hace de vista previa sin traer una foto de nadie.
final Uint8List _pngGris = Uint8List.fromList(<int>[
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
  64,
  0,
  0,
  0,
  64,
  8,
  6,
  0,
  0,
  0,
  170,
  105,
  113,
  222,
  0,
  0,
  1,
  50,
  73,
  68,
  65,
  84,
  120,
  156,
  229,
  195,
  135,
  42,
  0,
  0,
  0,
  69,
  209,
  247,
  97,
  146,
  36,
  73,
  146,
  36,
  73,
  146,
  36,
  73,
  178,
  247,
  222,
  123,
  239,
  237,
  218,
  91,
  146,
  36,
  63,
  247,
  124,
  200,
  59,
  117,
  84,
  208,
  137,
  147,
  171,
  176,
  11,
  39,
  87,
  81,
  55,
  78,
  174,
  226,
  30,
  156,
  92,
  37,
  189,
  56,
  185,
  74,
  251,
  112,
  114,
  149,
  245,
  227,
  228,
  42,
  31,
  192,
  201,
  85,
  49,
  136,
  147,
  171,
  114,
  8,
  39,
  87,
  213,
  48,
  78,
  174,
  234,
  17,
  156,
  92,
  53,
  163,
  56,
  185,
  106,
  199,
  112,
  114,
  213,
  141,
  227,
  228,
  170,
  159,
  192,
  201,
  213,
  48,
  137,
  147,
  171,
  113,
  10,
  39,
  87,
  211,
  52,
  78,
  174,
  230,
  25,
  156,
  92,
  45,
  179,
  56,
  185,
  90,
  231,
  112,
  114,
  181,
  205,
  227,
  228,
  106,
  95,
  192,
  201,
  213,
  177,
  136,
  147,
  171,
  115,
  9,
  39,
  87,
  247,
  50,
  78,
  174,
  222,
  21,
  156,
  92,
  253,
  171,
  56,
  185,
  6,
  215,
  112,
  114,
  13,
  175,
  227,
  228,
  26,
  221,
  192,
  201,
  53,
  190,
  137,
  147,
  107,
  114,
  11,
  39,
  215,
  244,
  54,
  78,
  174,
  217,
  29,
  156,
  92,
  243,
  187,
  56,
  185,
  22,
  247,
  112,
  114,
  45,
  239,
  227,
  228,
  90,
  61,
  192,
  201,
  181,
  126,
  136,
  147,
  107,
  243,
  8,
  39,
  215,
  246,
  49,
  78,
  174,
  221,
  19,
  156,
  92,
  251,
  167,
  56,
  185,
  14,
  207,
  112,
  114,
  29,
  159,
  227,
  228,
  58,
  189,
  192,
  201,
  117,
  126,
  137,
  147,
  235,
  242,
  10,
  39,
  23,
  224,
  228,
  186,
  185,
  198,
  201,
  117,
  119,
  131,
  147,
  235,
  225,
  22,
  39,
  215,
  211,
  29,
  78,
  174,
  151,
  123,
  156,
  92,
  111,
  15,
  56,
  185,
  62,
  30,
  113,
  114,
  125,
  62,
  225,
  228,
  250,
  122,
  198,
  201,
  245,
  253,
  130,
  147,
  235,
  231,
  21,
  39,
  215,
  239,
  27,
  78,
  174,
  191,
  119,
  156,
  252,
  31,
  129,
  14,
  122,
  119,
  83,
  147,
  16,
  146,
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
