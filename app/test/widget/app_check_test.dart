// App Check en modo observación (DT-33): cuándo se enciende en la aplicación.
//
// La aplicación solo pide el token; quien decide si se exige son las funciones
// (`EXIGIR_APP_CHECK`). Aquí se vigila que encenderlo nunca rompa el arranque:
// sin clave o contra los emuladores no se toca, y en la nube se enciende solo
// si el ambiente trae la clave de reCAPTCHA.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sian/infrastructure/firebase/app_check.dart';

void main() {
  group('¿Se enciende App Check?', () {
    test('en la nube y con clave, sí', () {
      expect(
        debeActivarAppCheck(usaEmulador: false, clave: '6Lc-clave'),
        isTrue,
      );
    });

    test('sin clave, no: el ambiente todavía no lo tiene registrado', () {
      expect(debeActivarAppCheck(usaEmulador: false, clave: ''), isFalse);
      expect(debeActivarAppCheck(usaEmulador: false, clave: '   '), isFalse);
    });

    test('contra los emuladores, nunca: no hay reCAPTCHA en localhost', () {
      expect(
        debeActivarAppCheck(usaEmulador: true, clave: '6Lc-clave'),
        isFalse,
      );
    });
  });

  test('un fallo al encenderlo no impide arrancar', () async {
    bool llamado = false;
    final bool encendido = await activarAppCheck(
      clave: '6Lc-clave',
      usaEmulador: false,
      activar: (String _) async {
        llamado = true;
        throw StateError('reCAPTCHA no cargó');
      },
    );
    expect(llamado, isTrue);
    expect(encendido, isFalse);
  });

  test('sin clave ni siquiera se intenta', () async {
    bool llamado = false;
    final bool encendido = await activarAppCheck(
      clave: '',
      usaEmulador: false,
      activar: (String _) async => llamado = true,
    );
    expect(llamado, isFalse);
    expect(encendido, isFalse);
  });

  test('los tres ambientes pasan la clave de App Check al construir', () {
    final String flujo = File(
      '../.github/workflows/deploy.yml',
    ).readAsStringSync();
    final int construcciones = RegExp(
      r'flutter build web',
    ).allMatches(flujo).length;
    final int conClave = RegExp(
      r'--dart-define=SIAN_APP_CHECK=\$\{\{ vars\.\w+_APP_CHECK_KEY \}\}',
    ).allMatches(flujo).length;
    expect(construcciones, 3);
    expect(conClave, construcciones);
  });
}
