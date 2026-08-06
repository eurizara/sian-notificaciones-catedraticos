/// Cuánta atención pide cada mensaje — RF-CNF-02, RF-CNF-10.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Si todo se ve igual, nada destaca. Y aquí destacar es la función.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Un catedrático abre la bandeja para saber qué le falta por atender, no para
/// leerla entera. Lo que se prueba aquí no son colores: es que la jerarquía sea
/// EXCLUYENTE y esté bien ordenada. Un mensaje recibe un solo nivel, el más
/// alto que le corresponda — pintar dos señales a la vez devolvería la bandeja
/// al punto de partida, con todo llamando la atención y nada destacando.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sian/domain/repositorios.dart';
import 'package:sian/presentation/docente/realce_mensaje.dart';

MensajeRecibido mensaje({
  String estado = 'ENTREGADO',
  String tipo = 'INFORMATIVO',
  bool requiereConfirmacion = false,
}) {
  return MensajeRecibido(
    mensajeId: 'm1',
    titulo: 'Aviso',
    cuerpo: 'Cuerpo',
    tipo: tipo,
    estado: estado,
    requiereConfirmacion: requiereConfirmacion,
  );
}

void main() {
  group('la jerarquía está ordenada', () {
    test('un urgente sin confirmar es lo que más pide', () {
      // Es lo único que puede tener consecuencias reales si se pasa por alto.
      final Realce r = realceDe(
        mensaje(tipo: 'URGENTE', requiereConfirmacion: true, estado: 'ABIERTO'),
      );
      expect(r.nivel, NivelAtencion.urgentePendiente);
    });

    test('uno informativo que pide confirmación va después', () {
      final Realce r = realceDe(
        mensaje(requiereConfirmacion: true, estado: 'ABIERTO'),
      );
      expect(r.nivel, NivelAtencion.esperaConfirmacion);
    });

    test('sin leer va el último: informa, no reclama', () {
      expect(realceDe(mensaje()).nivel, NivelAtencion.sinLeer);
    });

    test('leído y sin nada pendiente no destaca', () {
      expect(realceDe(mensaje(estado: 'ABIERTO')).nivel, NivelAtencion.ninguno);
    });
  });

  group('confirmar apaga la señal', () {
    test('un urgente confirmado deja de reclamar', () {
      // Confirmado es el final del camino: ya no hay nada que hacer con él,
      // por urgente que fuera.
      final Realce r = realceDe(
        mensaje(
          tipo: 'URGENTE',
          requiereConfirmacion: true,
          estado: 'CONFIRMADO',
        ),
      );
      expect(r.nivel, NivelAtencion.ninguno);
      expect(r.destaca, isFalse);
      expect(r.franja, isNull);
    });
  });

  group('cada nivel se distingue del anterior', () {
    test('los tres que destacan usan colores distintos', () {
      // Dos niveles del mismo color serían dos niveles indistinguibles, y
      // entonces la jerarquía existiría solo en el código.
      final Set<int> colores = <int>{
        realceDe(
          mensaje(tipo: 'URGENTE', requiereConfirmacion: true),
        ).franja!.toARGB32(),
        realceDe(mensaje(requiereConfirmacion: true)).franja!.toARGB32(),
        realceDe(mensaje()).franja!.toARGB32(),
      };
      expect(colores.length, 3);
    });

    test('lo que no destaca no lleva franja ni fondo', () {
      final Realce r = realceDe(mensaje(estado: 'ABIERTO'));
      expect(r.franja, isNull);
      expect(r.fondo, isNull);
      expect(r.tituloEnNegrita, isFalse);
    });

    test('todo lo que destaca lleva el título en negrita', () {
      // El color solo no basta: hay quien no lo distingue.
      for (final MensajeRecibido m in <MensajeRecibido>[
        mensaje(tipo: 'URGENTE', requiereConfirmacion: true),
        mensaje(requiereConfirmacion: true),
        mensaje(),
      ]) {
        expect(realceDe(m).tituloEnNegrita, isTrue);
      }
    });
  });

  group('un mensaje sin entregar todavía', () {
    test('no se marca como sin leer: aún no llegó', () {
      expect(
        realceDe(mensaje(estado: 'PENDIENTE')).nivel,
        NivelAtencion.ninguno,
      );
    });

    test('uno fallido tampoco', () {
      expect(realceDe(mensaje(estado: 'FALLIDO')).nivel, NivelAtencion.ninguno);
    });
  });
}
