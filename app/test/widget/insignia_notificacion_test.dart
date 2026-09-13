/// La insignia de las notificaciones tiene que ser una silueta.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Android pinta el icono pequeño usando SOLO el canal alfa.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Lo opaco se tiñe del color del sistema y lo transparente se deja ver. Los
/// iconos de SIAN son opacos de borde a borde, y usarlos como insignia hacía
/// que Android enseñara un **cuadrado blanco macizo** junto al nombre en cada
/// notificación y junto a la hora en la barra de estado. Reportado en uso real
/// el 12 de septiembre de 2026.
///
/// Nada en la aplicación falla cuando esto se rompe: solo se ve mal, en el
/// teléfono de otra persona. Por eso se prueba.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const String _insignia = 'web/icons/insignia-notificacion.png';

void main() {
  group('la insignia de las notificaciones', () {
    test('el service worker y la aplicación usan la silueta, no el icono', () {
      for (final String ruta in <String>[
        'web/firebase-messaging-sw.js',
        'lib/core/plataforma/notificacion_sistema_web.dart',
      ]) {
        final String codigo = File(ruta).readAsStringSync();
        final Iterable<String> insignias = RegExp(
          r"badge:\s*'([^']+)'",
        ).allMatches(codigo).map((RegExpMatch m) => m.group(1)!);

        expect(insignias, isNotEmpty, reason: '$ruta no define insignia');
        for (final String i in insignias) {
          expect(
            i,
            '/icons/insignia-notificacion.png',
            reason: '$ruta usa «$i» como insignia: Android lo pinta como un cuadrado',
          );
        }
      }
    });

    test('su nombre no empieza por Icon-, para que no la marquen', () {
      // `tenir-iconos-ambiente.py` pone la inicial del ambiente sobre todo lo
      // que empieza por `Icon-`. Una marca de color sobre una silueta la
      // convertiría otra vez en un bloque.
      expect(_insignia.split('/').last.startsWith('Icon-'), isFalse);
    });

    testWidgets('tiene transparencia de verdad', (WidgetTester tester) async {
      final Uint8List bytes = File(_insignia).readAsBytesSync();

      final (int transparentes, int total) = (await tester.runAsync(() async {
        final ui.Codec codec = await ui.instantiateImageCodec(bytes);
        final ui.Image imagen = (await codec.getNextFrame()).image;
        final ByteData datos = (await imagen.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        int t = 0;
        final int n = datos.lengthInBytes ~/ 4;
        for (int i = 0; i < n; i += 1) {
          if (datos.getUint8(i * 4 + 3) < 16) {
            t += 1;
          }
        }
        return (t, n);
      }))!;

      // Una silueta que ocupe el cuadro entero vuelve a ser un cuadrado.
      expect(
        transparentes / total,
        greaterThan(0.3),
        reason: 'la insignia es casi opaca: Android la pintará como un bloque',
      );
      // Y una vacía no enseña nada.
      expect(transparentes / total, lessThan(0.95));
    });
  });
}
