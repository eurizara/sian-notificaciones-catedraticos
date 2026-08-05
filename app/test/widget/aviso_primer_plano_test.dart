/// Avisos que llegan con la aplicación abierta (RF-ENT-06, DT-02).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Este es el hueco que dejó la ronda 3 sin que ninguna prueba se enterara.
/// ────────────────────────────────────────────────────────────────────────────
///
/// El servidor enviaba la notificación de prueba, FCM la aceptaba y el
/// dispositivo la recibía. Pero con la pestaña en primer plano el service
/// worker no interviene, el navegador entrega el mensaje a la aplicación y se
/// desentiende de mostrarlo. El método que exponía esos mensajes existía, con
/// un comentario que explicaba exactamente por qué hacía falta, y **nadie lo
/// llamaba**. El resultado era un canal que parecía roto sin estarlo.
library;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_dispositivos.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/core/navegador.dart';
import 'package:sian/domain/repositorios.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/infrastructure/firebase/repositorio_dispositivos.dart';
import 'package:sian/presentation/docente/aviso_en_primer_plano.dart';
import 'package:sian/presentation/docente/bandeja_docente.dart';
import 'package:sian/presentation/shared/tema.dart';

import '../dobles/repositorios_falsos.dart';

/// Construye un mensaje como los que manda el servidor: solo datos.
RemoteMessage mensaje({
  String tipo = 'PRUEBA_REGISTRO',
  String titulo = 'SIAN UMG-BDM',
  String cuerpo = 'Tu dispositivo quedó registrado.',
}) {
  return RemoteMessage(
    data: <String, dynamic>{'tipo': tipo, 'titulo': titulo, 'cuerpo': cuerpo},
  );
}

void main() {
  group('lectura del mensaje', () {
    test('lee título y cuerpo de los datos', () {
      // El servidor manda solo datos, para decidir aquí el prefijo «URGENTE» y
      // no dejárselo al navegador.
      final aviso = leerAviso(mensaje(titulo: 'Simulacro', cuerpo: 'A las 10'));
      expect(aviso.titulo, 'Simulacro');
      expect(aviso.cuerpo, 'A las 10');
      expect(aviso.urgente, isFalse);
    });

    test('un urgente lleva el prefijo visible', () {
      // En iOS-PWA no se puede definir sonido ni vibración propios: el prefijo
      // en el título es la única distinción disponible (DT-02).
      final aviso = leerAviso(mensaje(tipo: 'URGENTE', titulo: 'Evacuación'));
      expect(aviso.titulo, 'URGENTE · Evacuación');
      expect(aviso.urgente, isTrue);
    });

    test('también entiende un bloque de notificación', () {
      // El desajuste de nombres entre lo que se enviaba y lo que se leía dejó
      // el cuerpo vacío durante toda la ronda 3. Leer ambos evita repetirlo.
      final aviso = leerAviso(
        const RemoteMessage(
          notification: RemoteNotification(title: 'Aviso', body: 'Contenido'),
        ),
      );
      expect(aviso.titulo, 'Aviso');
      expect(aviso.cuerpo, 'Contenido');
    });
  });

  group('RF-ENT-06 · se hace visible con la aplicación abierta', () {
    late RepositorioSesionFalso sesion;
    late RepositorioBandejaFalso bandeja;
    late RepositorioDispositivosFalso dispositivos;

    setUp(() {
      sesion = RepositorioSesionFalso();
      bandeja = RepositorioBandejaFalso(const <MensajeRecibido>[]);
      dispositivos = RepositorioDispositivosFalso(
        entorno: EntornoNavegador.desconocido,
        permiso: EstadoPermiso.concedido,
      );
    });

    tearDown(() {
      sesion.cerrar();
      dispositivos.cerrar();
    });

    Widget montar() => ProviderScope(
      overrides: [
        repositorioSesionProvider.overrideWithValue(sesion),
        repositorioBandejaProvider.overrideWithValue(bandeja),
        repositorioDispositivosProvider.overrideWithValue(dispositivos),
      ],
      child: MaterialApp(
        theme: TemaSian.claro(),
        home: BandejaDocente(usuario: usuarioDePrueba(rol: Rol.catedratico)),
      ),
    );

    testWidgets('un aviso que llega se muestra en pantalla', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      dispositivos.mensajes.add(
        mensaje(titulo: 'Suspensión de clases', cuerpo: 'Por lluvia'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Suspensión de clases'), findsOneWidget);
      expect(find.text('Por lluvia'), findsOneWidget);
    });

    testWidgets('un urgente se distingue del resto', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      dispositivos.mensajes.add(
        mensaje(tipo: 'URGENTE', titulo: 'Evacuación', cuerpo: 'Salgan ya'),
      );
      await tester.pumpAndSettle();

      expect(find.text('URGENTE · Evacuación'), findsOneWidget);
    });

    testWidgets('la notificación de prueba del registro se ve', (
      WidgetTester tester,
    ) async {
      // Es la que se perdía: el catedrático activaba las notificaciones, se
      // quedaba mirando la pantalla, y no veía nada.
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      dispositivos.mensajes.add(mensaje());
      await tester.pumpAndSettle();

      expect(find.text('Tu dispositivo quedó registrado.'), findsOneWidget);
    });

    testWidgets('se puede cerrar', (WidgetTester tester) async {
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      dispositivos.mensajes.add(mensaje(titulo: 'Aviso'));
      await tester.pumpAndSettle();
      expect(find.text('Aviso'), findsOneWidget);

      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();

      expect(find.text('Aviso'), findsNothing);
    });

    testWidgets('un aviso nuevo reemplaza al anterior, no se apilan', (
      WidgetTester tester,
    ) async {
      // Tres avisos seguidos no pueden dejar la pantalla tapada de banderas.
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      dispositivos.mensajes.add(mensaje(titulo: 'Primero'));
      await tester.pumpAndSettle();
      dispositivos.mensajes.add(mensaje(titulo: 'Segundo'));
      await tester.pumpAndSettle();

      expect(find.text('Primero'), findsNothing);
      expect(find.text('Segundo'), findsOneWidget);
    });
  });
}
