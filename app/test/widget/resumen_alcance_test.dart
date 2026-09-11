/// El resumen de la pantalla de Alcance — DT-22.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Estas pruebas existen porque el resumen se leyó AL REVÉS.
/// ────────────────────────────────────────────────────────────────────────────
///
/// La primera versión decía «Los 1 catedráticos pueden recibir avisos» cuando
/// había un solo destinatario y todo estaba bien. El coordinador lo entendió
/// como «1 catedrático no puede recibir» — exactamente lo contrario.
///
/// La concordancia rota fue lo que lo provocó: «Los 1» obliga a releer, y al
/// releer se busca sentido en las palabras sueltas antes que en la frase.
///
/// Un resumen que se puede entender del revés no informa: da una impresión, y
/// la impresión puede ser la contraria del dato. Por eso cada combinación de
/// singular y plural tiene aquí su caso.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sian/presentation/shared/textos.dart';

void main() {
  group('canalResumen · concordancia', () {
    test('con UNA persona y todo bien, no dice «Los 1»', () {
      final String texto = Textos.canalResumen(0, 1);

      expect(texto, isNot(contains('Los 1')));
      expect(texto, 'La única persona que recibe avisos está al día.');
    });

    test('con UNA persona sin recibir, el verbo va en singular', () {
      expect(Textos.canalResumen(1, 7), '1 de 7 no recibiría un aviso enviado ahora.');
    });

    test('con varias sin recibir, el verbo va en plural', () {
      expect(Textos.canalResumen(3, 7), '3 de 7 no recibirían un aviso enviado ahora.');
    });

    test('con varias personas y todo bien, plural correcto', () {
      expect(Textos.canalResumen(0, 22), 'Las 22 personas que reciben avisos están al día.');
    });

    test('sin nadie configurado lo dice, en vez de contar cero', () {
      // «Las 0 personas que reciben avisos están al día» sería cierto y absurdo.
      expect(Textos.canalResumen(0, 0), contains('Todavía no hay nadie'));
    });
  });

  group('canalResumen · no se puede leer del revés', () {
    test('cuando todo está bien, NO aparece la palabra «no»', () {
      // Es la comprobación que habría atrapado el defecto original: el texto de
      // «todo bien» no debe contener ninguna negación que, leída de un vistazo,
      // sugiera lo contrario.
      for (final int total in <int>[1, 2, 7, 22]) {
        final String texto = Textos.canalResumen(0, total).toLowerCase();
        expect(texto, isNot(contains(' no ')), reason: 'total=$total');
        expect(texto, contains('al día'), reason: 'total=$total');
      }
    });

    test('cuando hay problemas, lo dice sin ambigüedad', () {
      for (final int cuantos in <int>[1, 2, 5]) {
        final String texto = Textos.canalResumen(cuantos, 7).toLowerCase();
        expect(texto, contains('no recibir'), reason: 'cuantos=$cuantos');
        expect(texto, isNot(contains('al día')), reason: 'cuantos=$cuantos');
      }
    });

    test('los dos mensajes no se parecen entre sí', () {
      // Si el de «todo bien» y el de «hay problemas» compartieran estructura, un
      // vistazo rápido podría confundirlos. Que empiecen distinto es parte de
      // que se distingan sin leerlos enteros.
      final String bien = Textos.canalResumen(0, 7);
      final String mal = Textos.canalResumen(2, 7);
      expect(bien.substring(0, 3), isNot(mal.substring(0, 3)));
    });
  });

  group('canalResumen · dice «personas», no «catedráticos»', () {
    test('porque quien recibe no siempre es catedrático', () {
      // La bandera `recibeAvisos` es por persona, con el rol solo como valor por
      // omisión: un coordinador que además da clases entra en la cuenta.
      // Llamarlos a todos catedráticos era la misma inexactitud que ya hizo que
      // esta pantalla contara sobre la población equivocada.
      expect(Textos.canalResumen(0, 22), isNot(contains('catedrático')));
      expect(Textos.canalResumen(3, 22), isNot(contains('catedrático')));
    });
  });
}
