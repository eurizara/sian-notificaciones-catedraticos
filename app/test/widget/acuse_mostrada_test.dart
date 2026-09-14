/// «Entregado» no es «se mostró» — DT-31, corrección C-5.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Estas pruebas existen por un caso real que no se pudo contestar con datos.
/// ────────────────────────────────────────────────────────────────────────────
///
/// El 11 de septiembre de 2026 salió un aviso a 23 personas. El reporte dijo
/// 18 entregados, y varias de esas 18 nunca vieron la notificación: se
/// enteraron por WhatsApp y encontraron el aviso al entrar. Con lo que había,
/// «no me avisó» y «sí te llegó» eran dos afirmaciones igual de indemostrables.
///
/// Lo que se fija aquí es la distinción, y sobre todo **cuándo NO se puede
/// afirmar**: de un aviso que salió antes de que existiera el acuse no se puede
/// decir que no se mostró, porque nadie lo estaba midiendo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sian/domain/repositorios.dart';
import 'package:sian/infrastructure/firebase/repositorio_programacion.dart';
import 'package:sian/presentation/admin/seccion_entregas.dart';
import 'package:sian/presentation/docente/aviso_no_mostrado.dart';
import 'package:sian/presentation/shared/textos.dart';

DestinatarioEntrega persona(
  String estado, {
  DateTime? mostradaEn,
  bool sabeAcusar = true,
}) => DestinatarioEntrega(
  uid: 'uid-1',
  nombre: 'Ana López',
  correo: 'ana@umg.edu.gt',
  estado: estado,
  mostradaEn: mostradaEn,
  sabeAcusar: sabeAcusar,
);

MensajeRecibido recibido({
  required String estado,
  bool esperaAcuse = true,
  DateTime? mostradaEn,
  DateTime? entregadoEn,
  bool aparatoSabeAcusar = true,
}) => MensajeRecibido(
  mensajeId: 'm-1',
  titulo: 'Reunión',
  cuerpo: 'A las 10',
  tipo: 'INFORMATIVO',
  estado: estado,
  requiereConfirmacion: false,
  esperaAcuse: esperaAcuse,
  aparatoSabeAcusar: aparatoSabeAcusar,
  mostradaEn: mostradaEn,
  entregadoEn: entregadoEn ?? DateTime(2026, 9, 11, 10),
);

void main() {
  final DateTime ahora = DateTime(2026, 9, 11, 18);

  group('en el reporte del emisor', () {
    test('llegó y el aparato no lo mostró: es su propia situación', () {
      final SituacionEntrega s = situacionDe(
        persona('ENTREGADO'),
        false,
        esperaAcuse: true,
      );
      expect(s.etiqueta, Textos.detalleNoSeMostro);
    });

    test('se distingue de «no lo ha abierto», que se resuelve distinto', () {
      // A quien no lo abrió se le insiste; a este hay que llamarlo y revisar
      // los ajustes de su teléfono, porque le va a volver a pasar.
      final SituacionEntrega noMostro = situacionDe(
        persona('ENTREGADO'),
        false,
        esperaAcuse: true,
      );
      final SituacionEntrega noAbrio = situacionDe(
        persona('ENTREGADO', mostradaEn: ahora),
        false,
        esperaAcuse: true,
      );
      expect(noAbrio.etiqueta, Textos.detalleNoAbrio);
      expect(noMostro.etiqueta, isNot(noAbrio.etiqueta));
      expect(noMostro.color, isNot(noAbrio.color));
    });

    test('de un aviso SIN acuse no se afirma nada', () {
      // Los avisos anteriores a C-5 no lo piden: decir que no se mostraron
      // sería inventar un problema en todo el historial.
      expect(
        situacionDe(persona('ENTREGADO'), false).etiqueta,
        Textos.detalleNoAbrio,
      );
    });

    test('quien lo abrió o lo confirmó no aparece como no mostrado', () {
      // Lo vio, que es lo que se perseguía; cómo se enteró ya da igual.
      for (final String estado in <String>['ABIERTO', 'CONFIRMADO']) {
        expect(
          situacionDe(persona(estado), false, esperaAcuse: true).etiqueta,
          isNot(Textos.detalleNoSeMostro),
        );
      }
    });

    test('a un aparato que NO sabía acusar no se le acusa de nada', () {
      // Pasó media hora después de estrenar el acuse: los teléfonos todavía
      // corrían la versión anterior, no tenían forma de contestar, y el panel
      // dijo «se mostró en 0 de 5». Lo único cierto era que nadie sabía cómo
      // decir que sí.
      expect(
        situacionDe(
          persona('ENTREGADO', sabeAcusar: false),
          false,
          esperaAcuse: true,
        ).etiqueta,
        Textos.detalleNoAbrio,
      );
    });

    test('un fallo de entrega sigue siendo un fallo de entrega', () {
      // Nunca llegó: no es que el teléfono no lo enseñara.
      expect(
        situacionDe(persona('FALLIDO'), false, esperaAcuse: true).etiqueta,
        Textos.estadoNoLeLlego,
      );
    });
  });

  group('el conteo del aviso', () {
    MensajeProgramado aviso({
      int entregados = 10,
      int mostrados = 7,
      bool acuseEsperado = true,
    }) => MensajeProgramado(
      id: 'm-1',
      titulo: 'Reunión',
      tipo: 'INFORMATIVO',
      estado: 'ENVIADO',
      modo: 'INMEDIATO',
      creadoPor: 'uid-emisor',
      requiereConfirmacion: false,
      modoDestinatarios: 'TODOS',
      formato: const <String>['TEXTO'],
      entregados: entregados,
      mostrados: mostrados,
      acuseEsperado: acuseEsperado,
    );

    test('cuenta a cuántos les llegó y su teléfono no lo enseñó', () {
      expect(aviso().entregadosSinMostrar, 3);
    });

    test('sin acuse, la cuenta es cero: no se sabe, no se inventa', () {
      expect(aviso(acuseEsperado: false, mostrados: 0).entregadosSinMostrar, 0);
    });

    test('si se mostró en más aparatos que entregas, no da negativo', () {
      // Una persona con dos teléfonos acusa dos veces; el contador no puede
      // producir «-1 sin mostrar».
      expect(aviso(entregados: 5, mostrados: 8).entregadosSinMostrar, 0);
    });

    test('el texto dice en cuántos de cuántos se mostró', () {
      expect(Textos.seMostroEn(7, 10), 'Se mostró en 7 de 10 aparatos');
      expect(Textos.seMostroEn(10, 10), 'Se mostró en los 10 aparatos');
    });
  });

  group('la tarjeta del catedrático', () {
    test('cuenta los avisos que este aparato no le mostró', () {
      final List<MensajeRecibido> mensajes = <MensajeRecibido>[
        recibido(estado: 'ENTREGADO'),
        recibido(estado: 'CONFIRMADO'),
        recibido(estado: 'ABIERTO', mostradaEn: ahora),
      ];
      expect(avisosQueNoSeMostraron(mensajes, ahora), hasLength(2));
    });

    test('tampoco cuenta si el aparato no sabía acusar', () {
      expect(
        avisosQueNoSeMostraron(<MensajeRecibido>[
          recibido(estado: 'ENTREGADO', aparatoSabeAcusar: false),
        ], ahora),
        isEmpty,
      );
    });

    test('deja de insistir desde que el aparato demostró que sí muestra', () {
      // La notificación de prueba no pertenece a ningún aviso, así que no hay
      // entrega que anotar; pero demuestra que el teléfono las enseña. Sin
      // esto, la tarjeta se quedaba una semana diciendo algo ya resuelto.
      final List<MensajeRecibido> mensajes = <MensajeRecibido>[
        recibido(
          estado: 'ENTREGADO',
          entregadoEn: ahora.subtract(const Duration(hours: 3)),
        ),
      ];
      expect(avisosQueNoSeMostraron(mensajes, ahora), hasLength(1));
      expect(
        avisosQueNoSeMostraron(
          mensajes,
          ahora,
          ultimaVezQueMostro: ahora.subtract(const Duration(minutes: 5)),
        ),
        isEmpty,
      );
    });

    test('pero si después vuelve a no mostrarse, lo vuelve a decir', () {
      expect(
        avisosQueNoSeMostraron(
          <MensajeRecibido>[
            recibido(
              estado: 'ENTREGADO',
              entregadoEn: ahora.subtract(const Duration(minutes: 2)),
            ),
          ],
          ahora,
          ultimaVezQueMostro: ahora.subtract(const Duration(hours: 5)),
        ),
        hasLength(1),
      );
    });

    test('no cuenta los avisos que salieron sin acuse', () {
      expect(
        avisosQueNoSeMostraron(<MensajeRecibido>[
          recibido(estado: 'ENTREGADO', esperaAcuse: false),
        ], ahora),
        isEmpty,
      );
    });

    test('no cuenta lo que nunca llegó', () {
      // Sin entrega no hay nada que el teléfono pudiera enseñar.
      expect(
        avisosQueNoSeMostraron(const <MensajeRecibido>[
          MensajeRecibido(
            mensajeId: 'm-2',
            titulo: 'x',
            cuerpo: 'y',
            tipo: 'INFORMATIVO',
            estado: 'FALLIDO',
            requiereConfirmacion: false,
            esperaAcuse: true,
            aparatoSabeAcusar: true,
          ),
        ], ahora),
        isEmpty,
      );
    });

    test('olvida lo viejo: un ajuste pudo cambiar desde entonces', () {
      expect(
        avisosQueNoSeMostraron(<MensajeRecibido>[
          recibido(
            estado: 'ENTREGADO',
            entregadoEn: ahora.subtract(
              const Duration(days: diasQueSeMiranSinMostrar + 1),
            ),
          ),
        ], ahora),
        isEmpty,
      );
    });

    testWidgets('dice qué pasó y ofrece una prueba', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AvisoNoMostrado(cuantos: 2))),
      );
      await tester.pump();

      expect(find.text(Textos.avisosQueNoSeMostraron(2)), findsOneWidget);
      // Lo importante del texto: el aviso SÍ llegó. Quien lee esto tiene que
      // entender que el sistema no lo dejó fuera.
      expect(Textos.porQueNoSeMostro, contains('sí llegó'));
      expect(
        find.widgetWithText(FilledButton, Textos.botonProbarNotificacion),
        findsOneWidget,
      );
    });
  });
}
