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

final MensajeRecibido _mensaje = MensajeRecibido(
  mensajeId: 'm1',
  titulo: _titulo,
  cuerpo: _cuerpo,
  tipo: 'INFORMATIVO',
  estado: 'ENTREGADO',
  requiereConfirmacion: false,
  emisor: 'Coordinación Académica',
  entregadoEn: DateTime(2026, 3, 16, 14, 30),
);

/// ¿Está [texto] dentro de un recuadro con borde propio?
bool enPanelConBorde(WidgetTester tester, String texto) {
  final Iterable<Container> contenedores = tester
      .widgetList<Container>(
        find.ancestor(
          of: find.text(texto),
          matching: find.byType(Container),
        ),
      );
  return contenedores.any((Container c) {
    final Decoration? d = c.decoration;
    return d is BoxDecoration && d.border != null;
  });
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

  Widget montar() => ProviderScope(
    overrides: [
      repositorioSesionProvider.overrideWithValue(sesion),
      repositorioDispositivosProvider.overrideWithValue(dispositivos),
      repositorioBandejaProvider.overrideWithValue(
        RepositorioBandejaFalso(<MensajeRecibido>[_mensaje]),
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

    testWidgets('al abrirlo, el cuerpo aparece en un panel propio', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      await tester.tap(find.text(_titulo));
      await tester.pumpAndSettle();

      expect(find.text(_cuerpo), findsOneWidget);
      expect(
        enPanelConBorde(tester, _cuerpo),
        isTrue,
        reason: 'el contenido tiene que estar delimitado, no suelto',
      );
    });

    testWidgets('la cabecera se queda FUERA de ese panel', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();

      await tester.tap(find.text(_titulo));
      await tester.pumpAndSettle();

      // Si el título cayera dentro del mismo recuadro que el cuerpo, la
      // frontera no separaría nada y estaríamos como antes.
      expect(
        enPanelConBorde(tester, _titulo),
        isFalse,
        reason: 'el título es cabecera: va fuera del panel del contenido',
      );
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
