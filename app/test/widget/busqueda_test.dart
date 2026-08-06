/// Búsqueda y paginación — mejoras de uso sobre listas que crecen.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Se filtra sobre lo ya cargado, y hay que decirlo.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Firestore no sabe buscar texto dentro de un campo, y hacerlo exigiría un
/// índice externo de pago (ADR-008). Filtrar en memoria es exacto sobre lo
/// traído y no cuesta nada, pero tiene un límite honesto: lo que está más atrás
/// no aparece. Por eso el contador dice siempre cuántos se están mirando.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sian/domain/repositorios.dart';
import 'package:sian/presentation/docente/bandeja_docente.dart';
import 'package:sian/presentation/shared/buscador.dart';

MensajeRecibido mensaje(String titulo, String cuerpo) => MensajeRecibido(
  mensajeId: titulo,
  titulo: titulo,
  cuerpo: cuerpo,
  tipo: 'INFORMATIVO',
  estado: 'ENTREGADO',
  requiereConfirmacion: false,
);

void main() {
  group('normalización', () {
    test('ignora acentos: la gente con prisa no los escribe', () {
      expect(normalizar('Evacuación'), 'evacuacion');
      expect(normalizar('MAÑANA'), 'manana');
    });

    test('ignora mayúsculas', () {
      expect(normalizar('Simulacro'), normalizar('SIMULACRO'));
    });
  });

  group('coincidencia', () {
    test('un término vacío no filtra nada', () {
      expect(coincide('', <String>['lo que sea']), isTrue);
      expect(coincide('   ', <String>['lo que sea']), isTrue);
    });

    test('encuentra sin acentos aunque el texto los lleve', () {
      expect(coincide('evacuacion', <String>['Plan de Evacuación']), isTrue);
    });

    test('y al revés: con acentos aunque el texto no los tenga', () {
      expect(coincide('evacuación', <String>['Plan de evacuacion']), isTrue);
    });

    test('todas las palabras deben aparecer, en cualquier orden', () {
      // «simulacro norte» encuentra «Evacuación por la puerta norte —
      // simulacro». Exigir el orden obligaría a recordar cómo se escribió.
      expect(
        coincide('simulacro norte', <String>[
          'Evacuación por la puerta norte',
          'Simulacro del viernes',
        ]),
        isTrue,
      );
    });

    test('si falta una palabra, no coincide', () {
      expect(coincide('simulacro sur', <String>['Simulacro norte']), isFalse);
    });

    test('busca en todos los campos, no solo en el primero', () {
      expect(
        coincide('lluvia', <String>['Aviso', 'Suspendido por lluvia']),
        isTrue,
      );
    });
  });

  group('filtrado de la bandeja', () {
    final List<MensajeRecibido> todos = <MensajeRecibido>[
      mensaje('Simulacro', 'Evacuación por la puerta norte'),
      mensaje('Reunión', 'Claustro del jueves'),
      mensaje('Suspensión', 'Clases suspendidas por lluvia'),
    ];

    test('sin término, devuelve todo', () {
      expect(filtrarMensajes(todos, ''), hasLength(3));
    });

    test('encuentra por el título', () {
      expect(filtrarMensajes(todos, 'reunion'), hasLength(1));
    });

    test('y también por el cuerpo', () {
      // Buscar por el cuerpo es lo natural: se recuerda de qué iba el aviso,
      // no cómo se tituló.
      final List<MensajeRecibido> r = filtrarMensajes(todos, 'lluvia');
      expect(r, hasLength(1));
      expect(r.first.titulo, 'Suspensión');
    });

    test('sin coincidencias devuelve una lista vacía, no todo', () {
      expect(filtrarMensajes(todos, 'inexistente'), isEmpty);
    });
  });
}
