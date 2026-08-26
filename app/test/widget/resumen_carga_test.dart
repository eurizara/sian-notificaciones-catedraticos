/// Lo que se le dice a quien acaba de cargar una lista — RF-USR-01.
///
/// ────────────────────────────────────────────────────────────────────────────
/// El resumen tiene que decir QUÉ CAMBIÓ, no cuántas líneas se leyeron.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Antes decía «N invitaciones creadas» con el total de líneas válidas. Volver
/// a cargar una lista de doscientos correos anunciaba doscientas altas aunque
/// ciento noventa ya estuvieran, y quien la cargó se quedaba creyendo que
/// acababa de dar de alta a doscientas personas.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sian/presentation/shared/textos.dart';

void main() {
  group('RF-USR-01 · el resumen de una carga', () {
    test('una carga limpia cuenta solo lo nuevo', () {
      expect(
        Textos.resumenCarga(
          creadas: 17,
          actualizadas: 0,
          yaEntraron: 0,
          rechazadas: 0,
        ),
        '17 invitaciones nuevas.',
      );
    });

    test('recargar la misma lista NO anuncia altas', () {
      // El caso concreto que se reportó: se vuelve a cargar el archivo entero
      // y el mensaje anterior decía «17 invitaciones creadas».
      expect(
        Textos.resumenCarga(
          creadas: 0,
          actualizadas: 16,
          yaEntraron: 1,
          rechazadas: 0,
        ),
        '16 actualizadas · 1 sin tocar porque ya entró.',
      );
    });

    test('cada grupo se nombra por separado', () {
      expect(
        Textos.resumenCarga(
          creadas: 3,
          actualizadas: 2,
          yaEntraron: 4,
          rechazadas: 1,
        ),
        '3 invitaciones nuevas · 2 actualizadas · '
        '4 sin tocar porque ya entraron · 1 rechazada.',
      );
    });

    test('el singular se escribe en singular', () {
      expect(
        Textos.resumenCarga(
          creadas: 1,
          actualizadas: 0,
          yaEntraron: 0,
          rechazadas: 0,
        ),
        '1 invitación nueva.',
      );
    });

    test('un archivo que no cambió nada lo dice, en vez de callar', () {
      expect(
        Textos.resumenCarga(
          creadas: 0,
          actualizadas: 0,
          yaEntraron: 0,
          rechazadas: 0,
        ),
        'No había nada que cargar.',
      );
    });
  });
}
