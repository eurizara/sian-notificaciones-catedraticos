/// El mensaje abierto se distingue del cerrado — RF-ENT-07.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Abrir un mensaje tiene que NOTARSE.
/// ────────────────────────────────────────────────────────────────────────────
///
/// La cabecera plegada y la desplegada eran idénticas —los mismos datos, el
/// mismo fondo, la misma tipografía— y el cuerpo aparecía debajo sin nada que
/// lo separase. En una lista de cuatro avisos parecidos se perdía cuál se
/// estaba leyendo, que es justo lo que reportó quien la usó.
///
/// Lo que se comprueba aquí es la separación, no el color exacto: que el
/// contenido viva en su propio panel delimitado y que la cabecera se quede
/// fuera de él. Un día se podrá querer otro tono; lo que no se puede volver a
/// perder es la frontera.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/application/proveedores_dispositivos.dart';
import 'package:sian/application/proveedores_sesion.dart';
import 'package:sian/domain/repositorios.dart';
import 'package:sian/core/navegador.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/infrastructure/firebase/repositorio_dispositivos.dart';
import 'package:sian/presentation/docente/bandeja_docente.dart';
import 'package:sian/presentation/shared/tema.dart';

import '../dobles/repositorios_falsos.dart';

const String _titulo = 'Entrega de actas de medio ciclo';
const String _cuerpo = 'El plazo vence el viernes 20 a las 17:00.';

MensajeRecibido _mensajeCon(String estado) => MensajeRecibido(
  mensajeId: 'm1',
  titulo: _titulo,
  cuerpo: _cuerpo,
  tipo: 'INFORMATIVO',
  estado: estado,
  requiereConfirmacion: false,
  emisor: 'Coordinación Académica',
  entregadoEn: DateTime(2026, 3, 16, 14, 30),
);

/// ¿Está [texto] dentro de un contenedor con fondo propio, es decir, la banda?
///
/// Se comprueba que exista un fondo, no cuál es. El tono se podrá querer
/// distinto —más claro, más oscuro, de otro color en modo oscuro— y eso no debe
/// romper nada. Lo que no puede volver a pasar es que la cabecera y el cuerpo
/// compartan superficie, que era el defecto.
bool sobreBanda(WidgetTester tester, String texto) {
  final Iterable<Container> contenedores = tester.widgetList<Container>(
    find.ancestor(of: find.text(texto), matching: find.byType(Container)),
  );
  return contenedores.any((Container c) => c.color != null);
}

void main() {
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

  Widget montar({String estado = 'ENTREGADO'}) => ProviderScope(
    overrides: [
      repositorioSesionProvider.overrideWithValue(sesion),
      repositorioDispositivosProvider.overrideWithValue(dispositivos),
      repositorioBandejaProvider.overrideWithValue(
        RepositorioBandejaFalso(<MensajeRecibido>[_mensajeCon(estado)]),
      ),
    ],
    child: MaterialApp(
      theme: TemaSian.claro(),
      home: BandejaDocente(usuario: usuarioDePrueba(rol: Rol.catedratico)),
    ),
  );

  group('RF-ENT-07 · el detalle de un mensaje', () {
    testWidgets('plegado no enseña el cuerpo', (WidgetTester tester) async {
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      expect(find.text(_titulo), findsOneWidget);
      expect(find.text(_cuerpo), findsNothing);
    });

    testWidgets('al abrirlo, la cabecera se asienta sobre una banda', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      expect(
        sobreBanda(tester, _titulo),
        isFalse,
        reason: 'plegado no lleva banda: ahí se hojea una lista',
      );

      await tester.tap(find.text(_titulo));
      await tester.pumpAndSettle();

      expect(
        sobreBanda(tester, _titulo),
        isTrue,
        reason: 'abierto, el título va sobre la banda de cabecera',
      );
    });

    testWidgets('el cuerpo se queda FUERA de la banda', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      await tester.tap(find.text(_titulo));
      await tester.pumpAndSettle();

      expect(find.text(_cuerpo), findsOneWidget);
      // Si el cuerpo cayera dentro de la misma banda que el título, la
      // frontera no separaría nada y estaríamos como antes.
      expect(
        sobreBanda(tester, _cuerpo),
        isFalse,
        reason: 'el cuerpo es contenido: va debajo de la cabecera, no dentro',
      );
    });

    testWidgets('esto vale también para un mensaje YA LEÍDO', (
      WidgetTester tester,
    ) async {
      // Es el caso donde el primer intento fallaba. La tarjeta de un mensaje
      // leído no lleva tinte, así que el recuadro que se usaba antes quedaba
      // del mismo color que su fondo y no separaba nada — justo en el estado
      // más común de la bandeja.
      await tester.pumpWidget(montar(estado: 'CONFIRMADO'));
      await tester.pumpAndSettle();

      // La bandeja arranca en «Sin leer», y un mensaje confirmado no está ahí.
      await tester.tap(find.textContaining('Todos'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_titulo));
      await tester.pumpAndSettle();

      expect(sobreBanda(tester, _titulo), isTrue);
      expect(sobreBanda(tester, _cuerpo), isFalse);
    });

    testWidgets('quién lo envía sigue viéndose con el mensaje abierto', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      await tester.tap(find.text(_titulo));
      await tester.pumpAndSettle();

      // Separar la cabecera no puede costar la información que lleva.
      expect(find.textContaining('Coordinación Académica'), findsOneWidget);
      expect(find.textContaining('16/03/2026'), findsOneWidget);
    });
  });
}
