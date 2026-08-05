/// Pruebas de la política de contraseñas del cliente — RF-AUT-06.
///
/// Son el espejo de `functions/test/unidad/politicaContrasena.test.ts`, y ese
/// paralelismo es intencional: mientras no exista la suite de contrato que
/// pide DT-06, tener los mismos casos en ambos lados es lo que evita que
/// diverjan sin que nadie se entere.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sian/domain/politica_contrasena.dart';

void main() {
  const String buena = 'Trueno#Violeta47';

  group('composición mínima', () {
    test('acepta una contraseña que cumple todo', () {
      final ResultadoPolitica r = evaluarContrasena(buena);
      expect(r.valida, isTrue);
      expect(r.incumplimientos, isEmpty);
    });

    test('exige 10 caracteres y no menos', () {
      expect(PoliticaContrasena.longitudMinima, 10);
      expect(
        evaluarContrasena('Corto#1a').incumplimientos,
        contains(IncumplimientoContrasena.longitudMinima),
      );
    });

    test('exige mayúscula, minúscula, dígito y símbolo', () {
      expect(
        evaluarContrasena('trueno#violeta47').incumplimientos,
        contains(IncumplimientoContrasena.faltaMayuscula),
      );
      expect(
        evaluarContrasena('TRUENO#VIOLETA47').incumplimientos,
        contains(IncumplimientoContrasena.faltaMinuscula),
      );
      expect(
        evaluarContrasena('Trueno#Violeta').incumplimientos,
        contains(IncumplimientoContrasena.faltaDigito),
      );
      expect(
        evaluarContrasena('TruenoVioleta47').incumplimientos,
        contains(IncumplimientoContrasena.faltaSimbolo),
      );
    });

    test('cuenta caracteres, no unidades de código', () {
      expect(evaluarContrasena('Ñandú#Café47').valida, isTrue);
    });

    test('informa todos los incumplimientos de una vez', () {
      final ResultadoPolitica r = evaluarContrasena('abc');
      expect(r.incumplimientos.length, greaterThanOrEqualTo(4));
    });
  });

  group('no puede delatar a quien la eligió', () {
    test('rechaza la que contiene el usuario del correo', () {
      expect(
        evaluarContrasena(
          'Perez#Segura47',
          correo: 'ana.perez@umg.edu.gt',
        ).incumplimientos,
        contains(IncumplimientoContrasena.contieneDatosPersonales),
      );
    });

    test('rechaza aunque venga disfrazada con sustituciones', () {
      // `P3r3z` no es más segura que `Perez`.
      expect(
        evaluarContrasena(
          'XY#P3r3z2047',
          correo: 'ana.perez@umg.edu.gt',
        ).incumplimientos,
        contains(IncumplimientoContrasena.contieneDatosPersonales),
      );
    });

    test('rechaza la que contiene el nombre', () {
      expect(
        evaluarContrasena(
          'Lopez#Cielo47',
          nombre: 'Ana Pérez López',
        ).incumplimientos,
        contains(IncumplimientoContrasena.contieneDatosPersonales),
      );
    });

    test('no se confunde con fragmentos demasiado cortos', () {
      expect(
        evaluarContrasena(buena, nombre: 'Ana de la Cruz').incumplimientos,
        isNot(contains(IncumplimientoContrasena.contieneDatosPersonales)),
      );
    });
  });

  group('listas de siempre', () {
    test('rechaza las más probadas del mundo', () {
      for (final String mala in <String>['Password#2047', 'Qwerty#12047']) {
        expect(
          evaluarContrasena(mala).incumplimientos,
          contains(IncumplimientoContrasena.demasiadoComun),
        );
      }
    });

    test('rechaza el nombre del sistema y de la universidad', () {
      for (final String mala in <String>['Sian#Segura47', 'Umg#Guatemala47']) {
        expect(evaluarContrasena(mala).valida, isFalse);
      }
    });

    test('las reconoce disfrazadas', () {
      expect(
        evaluarContrasena('P@ssw0rd#47X').incumplimientos,
        contains(IncumplimientoContrasena.demasiadoComun),
      );
    });
  });

  group('secuencias y repeticiones', () {
    test('rechaza secuencias de abecedario, dígitos y teclado', () {
      for (final String mala in <String>[
        'Xk#Abcdefgh9',
        'Xk#Trueno1234',
        'Xk#Truenoasdf9',
        'Xk#Trueno4321',
      ]) {
        expect(
          evaluarContrasena(mala).incumplimientos,
          contains(IncumplimientoContrasena.secuenciaObvia),
          reason: mala,
        );
      }
    });

    test('rechaza un carácter repetido cuatro veces', () {
      expect(
        evaluarContrasena('Trueno#aaaa47').incumplimientos,
        contains(IncumplimientoContrasena.caracterRepetido),
      );
    });

    test('tolera repeticiones cortas, normales en castellano', () {
      expect(evaluarContrasena('Caballo#Verde47').valida, isTrue);
    });
  });

  group('fuerza orientativa', () {
    test('premia la longitud por encima de la variedad', () {
      expect(
        evaluarContrasena('Trueno#47x').fuerza,
        FuerzaContrasena.aceptable,
      );
      expect(
        evaluarContrasena('Trueno#Violet47').fuerza,
        FuerzaContrasena.buena,
      );
      expect(
        evaluarContrasena('Trueno#Violeta47Nube').fuerza,
        FuerzaContrasena.excelente,
      );
    });

    test('lo que no cumple es insuficiente, sin matices', () {
      expect(evaluarContrasena('abc').fuerza, FuerzaContrasena.insuficiente);
    });
  });

  group('paridad con el servidor (DT-06)', () {
    test('los mismos casos dan el mismo veredicto que en TypeScript', () {
      // Estos son literalmente los casos de politicaContrasena.test.ts. Si
      // alguno diverge, las dos implementaciones se separaron.
      const Map<String, bool> esperado = <String, bool>{
        'Trueno#Violeta47': true,
        'Caballo#Verde47': true,
        'Ñandú#Café47': true,
        'Corto#1a': false,
        'TruenoVioleta47': false,
        'Password#2047': false,
        'P@ssw0rd#47X': false,
        'Xk#Abcdefgh9': false,
        'Trueno#aaaa47': false,
        'Aula#Magna2047': true,
      };

      esperado.forEach((String clave, bool valida) {
        expect(evaluarContrasena(clave).valida, valida, reason: clave);
      });
    });
  });
}
