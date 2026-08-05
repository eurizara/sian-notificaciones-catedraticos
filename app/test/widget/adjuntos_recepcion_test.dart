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
    rutaVoz: voz,
    duracionVozSeg: duracion,
    rutaImagen: imagen,
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
      await tester.pump();

      expect(find.byType(NotaDeVoz), findsOneWidget);
      expect(find.text(Textos.vozAdjunta(7)), findsOneWidget);
    });

    testWidgets('una imagen aparece', (WidgetTester tester) async {
      await tester.pumpWidget(
        montar(<MensajeRecibido>[mensaje(imagen: 'mensajes/m1/imagen.jpg')]),
      );
      await tester.pump();

      expect(find.byType(ImagenAdjunta), findsOneWidget);
    });

    testWidgets('un mensaje solo de texto no enseña ningún hueco', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar(<MensajeRecibido>[mensaje()]));
      await tester.pump();

      expect(find.byType(NotaDeVoz), findsNothing);
      expect(find.byType(ImagenAdjunta), findsNothing);
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
