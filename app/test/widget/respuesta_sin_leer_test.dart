/// Una respuesta nueva devuelve el aviso a «Sin leer» (C-6, 26/09/2026).
///
/// En iPhone, tocar la notificación de una respuesta seguía abriendo la
/// bandeja en «Sin leer», y el aviso respondido —ya leído o confirmado— no
/// estaba ahí: la respuesta se perdía de vista. Ahora, mientras el catedrático
/// tenga respuestas sin leer en la conversación de un aviso, ese aviso está en
/// «Sin leer», sin tocar su lectura ni su confirmación, que tienen valor de
/// constancia. Al leer la respuesta, vuelve a su sitio.
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
import 'package:sian/presentation/docente/filtro_bandeja.dart';
import 'package:sian/presentation/shared/tema.dart';
import 'package:sian/presentation/shared/textos.dart';

import '../dobles/repositorios_falsos.dart';

MensajeRecibido msg(
  String id,
  String estado, {
  bool pideConfirmacion = false,
  int respuestasSinLeer = 0,
}) => MensajeRecibido(
  mensajeId: id,
  titulo: 'Aviso $id',
  cuerpo: 'Cuerpo',
  tipo: 'INFORMATIVO',
  estado: estado,
  requiereConfirmacion: pideConfirmacion,
  entregadoEn: DateTime(2026, 9, 26, 8),
  respuestasSinLeer: respuestasSinLeer,
);

void main() {
  group('etapa', () {
    test('confirmado, con una respuesta sin leer → SIN LEER', () {
      expect(
        etapaDe(
          msg('a', 'CONFIRMADO', pideConfirmacion: true, respuestasSinLeer: 1),
        ),
        EtapaBandeja.sinLeer,
      );
    });

    test(
      'leído sin confirmación que dar, con respuesta sin leer → SIN LEER',
      () {
        expect(
          etapaDe(msg('a', 'ABIERTO', respuestasSinLeer: 2)),
          EtapaBandeja.sinLeer,
        );
      },
    );

    test('leída la respuesta, vuelve a su etapa de siempre', () {
      expect(
        etapaDe(msg('a', 'CONFIRMADO', pideConfirmacion: true)),
        EtapaBandeja.leido,
      );
      expect(
        etapaDe(msg('a', 'ABIERTO', pideConfirmacion: true)),
        EtapaBandeja.sinConfirmar,
      );
    });

    test('lo que no llegó sigue fuera del ciclo aunque tenga respuesta', () {
      expect(
        etapaDe(msg('a', 'FALLIDO', respuestasSinLeer: 1)),
        EtapaBandeja.fueraDelCiclo,
      );
    });
  });

  test(
    'conRespuestasSinLeer pone la cuenta de cada aviso y deja el resto igual',
    () {
      final List<MensajeRecibido> r = conRespuestasSinLeer(
        <MensajeRecibido>[msg('a', 'CONFIRMADO'), msg('b', 'ABIERTO')],
        <String, int>{'a': 3, 'zzz': 1},
      );
      expect(r.map((MensajeRecibido m) => m.respuestasSinLeer), <int>[3, 0]);
      expect(r.first.estado, 'CONFIRMADO', reason: 'la entrega no se toca');
      expect(r.first.titulo, 'Aviso a');
    },
  );

  group('en la bandeja', () {
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

    testWidgets('el aviso respondido aparece en «Sin leer», marcado', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositorioSesionProvider.overrideWithValue(sesion),
            repositorioDispositivosProvider.overrideWithValue(dispositivos),
            repositorioBandejaProvider.overrideWithValue(
              RepositorioBandejaFalso(<MensajeRecibido>[
                msg(
                  'r',
                  'CONFIRMADO',
                  pideConfirmacion: true,
                  respuestasSinLeer: 1,
                ),
                msg('x', 'CONFIRMADO', pideConfirmacion: true),
              ]),
            ),
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

      expect(find.text('Aviso r'), findsOneWidget);
      expect(find.text('Aviso x'), findsNothing);
      expect(find.text(Textos.respuestaNuevaEnAviso(1)), findsOneWidget);
      expect(find.text(Textos.filtroBandeja('sinLeer', 1)), findsOneWidget);
    });
  });
}
