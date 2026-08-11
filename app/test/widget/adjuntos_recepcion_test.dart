/// Recepción de adjuntos y compacidad de la tarjeta de notificaciones.
///
/// RF-ENT-08, RF-ENT-09 · RF-USR-09.
///
/// ────────────────────────────────────────────────────────────────────────────
/// El adjunto llegó, se guardó bien, y aun así no se veía.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Firestore entrega el documento como `Map<String, dynamic>`, pero lo que hay
/// dentro pasa por la conversión desde JavaScript y puede llegar con otro tipo
/// de claves. Un `as Map<String, dynamic>` sobre un mapa anidado es la clase de
/// suposición que solo falla en producción, sobre el dispositivo de otra
/// persona, y sin dejar rastro.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_dispositivos.dart';
import 'package:sian/application/proveedores_programacion.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/core/navegador.dart';
import 'package:sian/domain/repositorios.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/infrastructure/firebase/repositorio_dispositivos.dart';
import 'package:sian/presentation/docente/bandeja_docente.dart';
import 'package:sian/presentation/docente/reproductor_adjuntos.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

/// Entorno que sí puede notificar. El valor por omisión de la máquina virtual
/// declara que NO soporta notificaciones, y con eso la tarjeta muestra otro
/// estado —el de «este navegador no puede notificarte»— que no es el que aquí
/// se prueba.
const EntornoNavegador entornoConNotificaciones = EntornoNavegador(
  plataforma: PlataformaWeb.escritorio,
  instalada: false,
  navegador: 'Chrome',
  soportaNotificaciones: true,
  versionIos: null,
);

MensajeRecibido mensaje({String? voz, String? imagen, int? duracion}) {
  return MensajeRecibido(
    mensajeId: 'm1',
    titulo: 'Prueba',
    cuerpo: 'Cuerpo',
    tipo: 'INFORMATIVO',
    estado: 'ENTREGADO',
    requiereConfirmacion: false,
    adjuntos: <AdjuntoRecibido>[
      if (voz != null)
        AdjuntoRecibido(tipo: 'AUDIO', ruta: voz, duracionSeg: duracion),
      if (imagen != null) AdjuntoRecibido(tipo: 'IMAGEN', ruta: imagen),
    ],
  );
}

void main() {
  group('el mensaje sabe qué adjuntos lleva', () {
    test('sin rutas, no lleva nada', () {
      final MensajeRecibido m = mensaje();
      expect(m.llevaVoz, isFalse);
      expect(m.llevaImagen, isFalse);
      expect(m.llevaAdjuntos, isFalse);
    });

    test('con ruta de voz, la lleva', () {
      final MensajeRecibido m = mensaje(
        voz: 'mensajes/m1/voz.webm',
        duracion: 4,
      );
      expect(m.llevaVoz, isTrue);
      expect(m.llevaAdjuntos, isTrue);
    });

    test('voz e imagen a la vez (RF-MSG-05)', () {
      final MensajeRecibido m = mensaje(
        voz: 'mensajes/m1/voz.webm',
        imagen: 'mensajes/m1/imagen.jpg',
      );
      expect(m.llevaVoz, isTrue);
      expect(m.llevaImagen, isTrue);
    });
  });

  group('la bandeja los muestra', () {
    late RepositorioSesionFalso sesion;

    setUp(() => sesion = RepositorioSesionFalso());
    tearDown(() => sesion.cerrar());

    Widget montar(List<MensajeRecibido> mensajes) => ProviderScope(
      overrides: [
        repositorioSesionProvider.overrideWithValue(sesion),
        repositorioBandejaProvider.overrideWithValue(
          RepositorioBandejaFalso(mensajes),
        ),
        repositorioDispositivosProvider.overrideWithValue(
          RepositorioDispositivosFalso(
            entorno: EntornoNavegador.desconocido,
            permiso: EstadoPermiso.concedido,
          ),
        ),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: BandejaDocente(usuario: usuarioDePrueba(rol: Rol.catedratico)),
      ),
    );

    // ────────────────────────────────────────────────────────────────────────
    // QUIÉN LO MANDA, SIN TENER QUE ABRIRLO.
    // ────────────────────────────────────────────────────────────────────────
    //
    // Ante un aviso que pide salir del edificio, saber quién lo firma es parte
    // de decidir si obedecerlo. El nombre viaja con el mensaje porque el
    // receptor no puede leer `usuarios`.
    testWidgets('el nombre de quien envía se ve sin desplegar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(<MensajeRecibido>[
          const MensajeRecibido(
            mensajeId: 'm1',
            titulo: 'Simulacro',
            cuerpo: 'Cuerpo',
            tipo: 'INFORMATIVO',
            estado: 'ENTREGADO',
            requiereConfirmacion: false,
            emisor: 'Lucía Araujo',
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text(Textos.enviadoPor('Lucía Araujo')), findsOneWidget);
    });

    testWidgets('un mensaje antiguo, sin ese dato, no inventa un emisor', (
      WidgetTester tester,
    ) async {
      // Los mensajes anteriores a que esto se guardara no tienen el nombre.
      // Poner «Sistema» donde no consta quién firmó sería peor que callar.
      await tester.pumpWidget(
        montar(<MensajeRecibido>[mensaje()]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('De '), findsNothing);
      expect(find.text('Prueba'), findsOneWidget);
    });

    // ────────────────────────────────────────────────────────────────────────
    // EL ORDEN DEL EMISOR SOBREVIVE HASTA AQUÍ.
    // ────────────────────────────────────────────────────────────────────────
    //
    // Un plano, después la nota de voz que lo explica, después la foto del
    // punto de reunión. Agruparlos por tipo al mostrarlos destruiría ese orden
    // sin que nadie se diera cuenta: los adjuntos seguirían todos ahí.
    testWidgets('se muestran en el orden en que se adjuntaron', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        montar(<MensajeRecibido>[
          const MensajeRecibido(
            mensajeId: 'm1',
            titulo: 'Prueba',
            cuerpo: 'Cuerpo',
            tipo: 'INFORMATIVO',
            estado: 'ENTREGADO',
            requiereConfirmacion: false,
            adjuntos: <AdjuntoRecibido>[
              AdjuntoRecibido(tipo: 'IMAGEN', ruta: 'mensajes/m1/1-plano.png'),
              AdjuntoRecibido(
                tipo: 'AUDIO',
                ruta: 'mensajes/m1/2-voz.webm',
                duracionSeg: 8,
              ),
              AdjuntoRecibido(tipo: 'IMAGEN', ruta: 'mensajes/m1/3-punto.png'),
            ],
          ),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prueba'));
      await tester.pumpAndSettle();

      final double yPrimera = tester
          .getTopLeft(find.byType(ImagenAdjunta).first)
          .dy;
      final double yVoz = tester.getTopLeft(find.byType(NotaDeVoz)).dy;
      final double ySegunda = tester
          .getTopLeft(find.byType(ImagenAdjunta).last)
          .dy;

      expect(yPrimera, lessThan(yVoz), reason: 'la imagen iba primero');
      expect(yVoz, lessThan(ySegunda), reason: 'la voz iba antes de la 2.ª');
      expect(find.byType(ImagenAdjunta), findsNWidgets(2));
    });

    testWidgets('una nota de voz aparece bajo el texto', (
      WidgetTester tester,
    ) async {
      // Bajo el texto y no tras un botón: una nota de voz que hay que buscar
      // es una nota de voz que no se escucha.
      await tester.pumpWidget(
        montar(<MensajeRecibido>[
          mensaje(voz: 'mensajes/m1/voz.webm', duracion: 7),
        ]),
      );
      await tester.pumpAndSettle();

      // Los mensajes nacen plegados: se hojea la lista y se abre lo que
      // interese. Los adjuntos están dentro del detalle.
      await tester.tap(find.text('Prueba'));
      await tester.pumpAndSettle();

      expect(find.byType(NotaDeVoz), findsOneWidget);
      expect(find.text(Textos.vozAdjunta(7)), findsOneWidget);
    });

    testWidgets('una imagen aparece', (WidgetTester tester) async {
      await tester.pumpWidget(
        montar(<MensajeRecibido>[mensaje(imagen: 'mensajes/m1/imagen.jpg')]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Prueba'));
      await tester.pumpAndSettle();

      expect(find.byType(ImagenAdjunta), findsOneWidget);
      // Y no se descarga hasta que se pide: lo que urge de un aviso es el
      // texto, no cinco megas de imagen al abrir la pantalla.
      expect(find.text(Textos.imagenTocarParaVer), findsOneWidget);
    });

    testWidgets('un mensaje solo de texto no enseña ningún hueco', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(<MensajeRecibido>[mensaje()]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prueba'));
      await tester.pumpAndSettle();

      expect(find.byType(NotaDeVoz), findsNothing);
      expect(find.byType(ImagenAdjunta), findsNothing);
    });
  });

  group('los adjuntos NO cambian de alto al cargar', () {
    // ──────────────────────────────────────────────────────────────────────
    // Es lo que rompía el desplazamiento hacia arriba.
    // ──────────────────────────────────────────────────────────────────────
    //
    // Una imagen sin alto declarado mide lo que mida el archivo, y eso no se
    // sabe hasta descargarlo. Al subir por la lista, lo que quedó por encima
    // se reconstruye: cada imagen nace midiendo cero, salta a su alto real,
    // todo lo de abajo se corre y la vista vuelve donde estaba. El dedo sube
    // y la pantalla no.
    //
    // Hacia abajo no se nota, porque lo que crece está fuera de la vista. Por
    // eso el fallo parecía caprichoso.
    late RepositorioSesionFalso sesion;

    setUp(() => sesion = RepositorioSesionFalso());
    tearDown(() => sesion.cerrar());

    Widget montar(MensajeRecibido m) => ProviderScope(
      overrides: [
        repositorioSesionProvider.overrideWithValue(sesion),
        repositorioBandejaProvider.overrideWithValue(
          RepositorioBandejaFalso(<MensajeRecibido>[m]),
        ),
        repositorioDispositivosProvider.overrideWithValue(
          RepositorioDispositivosFalso(entorno: EntornoNavegador.desconocido),
        ),
        repositorioProgramacionProvider.overrideWithValue(
          RepositorioProgramacionFalso(),
        ),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: BandejaDocente(usuario: usuarioDePrueba(rol: Rol.catedratico)),
      ),
    );

    testWidgets('la imagen reserva su hueco desde el primer momento', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(mensaje(imagen: 'mensajes/m1/i.jpg')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prueba'));
      await tester.pumpAndSettle();

      // Antes de pedirla, el hueco ya mide lo que medirá después.
      final double antes = tester.getSize(find.byType(ImagenAdjunta)).height;

      await tester.tap(find.text(Textos.imagenTocarParaVer));
      await tester.pumpAndSettle();

      final double despues = tester.getSize(find.byType(ImagenAdjunta)).height;

      expect(despues, antes, reason: 'la fila no puede cambiar de alto');
    });

    testWidgets('la nota de voz también', (WidgetTester tester) async {
      await tester.pumpWidget(
        montar(mensaje(voz: 'mensajes/m1/v.webm', duracion: 5)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prueba'));
      await tester.pumpAndSettle();

      final double alto = tester.getSize(find.byType(NotaDeVoz)).height;
      // Un alto plausible: si fuera cero, la tarjeta crecería al cargar.
      expect(alto, greaterThan(56));
    });
  });

  group('los mensajes se pliegan', () {
    // ──────────────────────────────────────────────────────────────────────
    // Una bandeja se hojea; un mensaje se lee.
    // ──────────────────────────────────────────────────────────────────────
    //
    // Con todo desplegado, tres avisos con imagen llenan la pantalla y hay
    // que desplazarse mucho para saber si hay algo nuevo.
    late RepositorioSesionFalso sesion;

    setUp(() => sesion = RepositorioSesionFalso());
    tearDown(() => sesion.cerrar());

    Widget montar(List<MensajeRecibido> mensajes) => ProviderScope(
      overrides: [
        repositorioSesionProvider.overrideWithValue(sesion),
        repositorioBandejaProvider.overrideWithValue(
          RepositorioBandejaFalso(mensajes),
        ),
        repositorioDispositivosProvider.overrideWithValue(
          RepositorioDispositivosFalso(entorno: EntornoNavegador.desconocido),
        ),
        repositorioProgramacionProvider.overrideWithValue(
          RepositorioProgramacionFalso(),
        ),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: BandejaDocente(usuario: usuarioDePrueba(rol: Rol.catedratico)),
      ),
    );

    testWidgets('nacen plegados: solo título y una línea', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(<MensajeRecibido>[mensaje()]));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsNothing);
    });

    testWidgets('tocar el mensaje lo abre', (WidgetTester tester) async {
      await tester.pumpWidget(montar(<MensajeRecibido>[mensaje()]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Prueba'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_less), findsOneWidget);
    });

    testWidgets('un urgente sin confirmar nace ABIERTO', (
      WidgetTester tester,
    ) async {
      // Esconder tras un toque justo lo que hay que atender sería exactamente
      // al revés de lo que hace falta.
      await tester.pumpWidget(
        montar(<MensajeRecibido>[
          const MensajeRecibido(
            mensajeId: 'm1',
            titulo: 'Evacuación',
            cuerpo: 'Salgan ya',
            tipo: 'URGENTE',
            estado: 'ENTREGADO',
            requiereConfirmacion: true,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.text(Textos.botonConfirmarLectura), findsOneWidget);
    });

    testWidgets('el estado y la fecha se ven aunque esté plegado', (
      WidgetTester tester,
    ) async {
      // Son lo que se hojea. Esconderlos obligaría a abrir cada mensaje solo
      // para saber cuál falta por confirmar.
      await tester.pumpWidget(
        montar(<MensajeRecibido>[
          MensajeRecibido(
            mensajeId: 'm1',
            titulo: 'Prueba',
            cuerpo: 'Cuerpo',
            tipo: 'INFORMATIVO',
            estado: 'CONFIRMADO',
            requiereConfirmacion: false,
            entregadoEn: DateTime(2026, 8, 5, 14, 30),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text(Textos.estadoConfirmado), findsOneWidget);
      expect(find.text('05/08/2026 · 14:30'), findsOneWidget);
    });
  });

  group('RF-USR-09 · la tarjeta no estorba cuando todo va bien', () {
    late RepositorioSesionFalso sesion;

    setUp(() => sesion = RepositorioSesionFalso());
    tearDown(() => sesion.cerrar());

    Widget montar(EstadoPermiso permiso) => ProviderScope(
      overrides: [
        repositorioSesionProvider.overrideWithValue(sesion),
        repositorioBandejaProvider.overrideWithValue(
          RepositorioBandejaFalso(const <MensajeRecibido>[]),
        ),
        repositorioDispositivosProvider.overrideWithValue(
          RepositorioDispositivosFalso(
            entorno: entornoConNotificaciones,
            permiso: permiso,
          ),
        ),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: BandejaDocente(usuario: usuarioDePrueba(rol: Rol.catedratico)),
      ),
    );

    testWidgets('con notificaciones activas se pliega a una línea', (
      WidgetTester tester,
    ) async {
      // Su trabajo es avisar de que un aviso NO va a llegar. Con todo
      // resuelto, ocupar el primer tercio de la bandeja empuja hacia abajo lo
      // que la persona vino a leer.
      await tester.pumpWidget(montar(EstadoPermiso.concedido));
      await tester.pumpAndSettle();

      expect(find.text(Textos.notifActivasTitulo), findsOneWidget);
      // El detalle largo queda plegado.
      expect(find.text(Textos.notifActivasDetalle('Chrome')), findsNothing);
    });

    testWidgets('se despliega al tocarla: comprobar sigue siendo posible', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(EstadoPermiso.concedido));
      await tester.pumpAndSettle();

      await tester.tap(find.text(Textos.notifActivasTitulo));
      await tester.pumpAndSettle();

      expect(find.text(Textos.notifActivasDetalle('Chrome')), findsOneWidget);
    });

    testWidgets('volver a construirla NO vuelve a registrar el dispositivo', (
      WidgetTester tester,
    ) async {
      // ──────────────────────────────────────────────────────────────────
      // Refrescar es «una vez por apertura», no «una vez por widget».
      // ──────────────────────────────────────────────────────────────────
      //
      // La tarjeta vive dentro de la lista de mensajes, así que se destruye
      // al salir de la vista y se reconstruye al volver. Con el refresco
      // atado a su ciclo de vida, bastaba desplazarse abajo y volver arriba
      // para que llegara otra notificación de «dispositivo registrado».
      final RepositorioDispositivosFalso dispositivos =
          RepositorioDispositivosFalso(
            entorno: entornoConNotificaciones,
            permiso: EstadoPermiso.concedido,
          );

      Widget conEseDoble() => ProviderScope(
        overrides: [
          repositorioSesionProvider.overrideWithValue(sesion),
          repositorioBandejaProvider.overrideWithValue(
            RepositorioBandejaFalso(const <MensajeRecibido>[]),
          ),
          repositorioDispositivosProvider.overrideWithValue(dispositivos),
        ],
        child: MaterialApp(
          theme: TemaSian.claro(),
          home: BandejaDocente(usuario: usuarioDePrueba(rol: Rol.catedratico)),
        ),
      );

      await tester.pumpWidget(conEseDoble());
      await tester.pumpAndSettle();
      expect(dispositivos.vecesQuePidioPermiso, 1);

      // Se destruye y se vuelve a construir, como al desplazar la lista.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(conEseDoble());
      await tester.pumpAndSettle();

      expect(dispositivos.vecesQuePidioPermiso, 1);
    });

    testWidgets('el refresco automático NO pide notificación de prueba', (
      WidgetTester tester,
    ) async {
      // La prueba confirma que el canal funciona cuando alguien acaba de
      // pulsar «Activar». En el refresco silencioso es ruido.
      final RepositorioDispositivosFalso dispositivos =
          RepositorioDispositivosFalso(
            entorno: entornoConNotificaciones,
            permiso: EstadoPermiso.concedido,
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositorioSesionProvider.overrideWithValue(sesion),
            repositorioBandejaProvider.overrideWithValue(
              RepositorioBandejaFalso(const <MensajeRecibido>[]),
            ),
            repositorioDispositivosProvider.overrideWithValue(dispositivos),
          ],
          child: MaterialApp(
            theme: TemaSian.claro(),
            home: BandejaDocente(
              usuario: usuarioDePrueba(rol: Rol.catedratico),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(dispositivos.vecesQuePidioPermiso, 1);
      expect(dispositivos.vecesConPrueba, 0);
    });

    testWidgets('si hay algo que hacer, la tarjeta sigue completa', (
      WidgetTester tester,
    ) async {
      // Aquí sí tiene que ocupar sitio: sin permiso no llega ningún aviso.
      await tester.pumpWidget(montar(EstadoPermiso.pendiente));
      await tester.pumpAndSettle();

      expect(find.text(Textos.notifPendientesTitulo), findsOneWidget);
      expect(find.text(Textos.notifPendientesDetalle), findsOneWidget);
      expect(find.text(Textos.botonActivarNotificaciones), findsOneWidget);
    });
  });
}
