/// El identificador de instalación — RF-USR-09, DT-18.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Lo único que tiene que cumplir: NO CAMBIAR entre llamadas.
/// ────────────────────────────────────────────────────────────────────────────
///
/// El registro de dispositivos usaba el token de notificaciones como identidad
/// del aparato. En iOS el token se rota, así que cada apertura creaba un
/// dispositivo nuevo: en producción se midieron nueve tokens de un mismo
/// iPhone en dos días. Los viejos quedaban muertos y los avisos de esa persona
/// constaban como no entregados aunque tuviera todo bien configurado.
///
/// Fuera del navegador no hay `localStorage`, así que el sustituto de la
/// máquina virtual guarda el valor en memoria. Basta: lo que está en duda es la
/// estabilidad, no dónde se guarda.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sian/core/plataforma/instalacion_vm.dart';

void main() {
  setUp(olvidarIdentificadorDeInstalacion);

  group('RF-USR-09 · identidad del aparato', () {
    test('dos llamadas seguidas devuelven lo mismo', () {
      expect(identificadorDeInstalacion(), identificadorDeInstalacion());
    });

    test('cien llamadas devuelven un solo valor', () {
      // Es la propiedad que rompía el token: cada apertura daba uno distinto y
      // cada uno creaba un dispositivo.
      final Set<String> vistos = <String>{
        for (int i = 0; i < 100; i++) identificadorDeInstalacion(),
      };
      expect(vistos, hasLength(1));
    });

    test('nunca devuelve vacío', () {
      // Un identificador vacío haría que el servidor cayera al token, que es
      // justo el comportamiento del que se está huyendo.
      expect(identificadorDeInstalacion(), isNotEmpty);
    });
  });
}
