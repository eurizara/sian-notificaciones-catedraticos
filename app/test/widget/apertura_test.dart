/// Registro de apertura — RF-CNF-02, RF-CNF-06.
///
/// ────────────────────────────────────────────────────────────────────────────
/// «Abrió» es un indicio; «confirmó» es evidencia. No pueden decirse igual.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Abrir dice que la aplicación mostró el mensaje delante de la persona.
/// Confirmar dice que esa persona declaró haberlo leído, con su nombre y la
/// hora. El reporte informa de los dos, y lo que aquí se fija es que no los
/// mezcle: de este detalle salen decisiones sobre personas concretas.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sian/infrastructure/firebase/repositorio_programacion.dart';
import 'package:sian/presentation/admin/seccion_entregas.dart';
import 'package:sian/presentation/shared/textos.dart';

DestinatarioEntrega persona(String estado) => DestinatarioEntrega(
  uid: 'u1',
  nombre: 'Ana Sofía Ramírez',
  correo: 'a@umg.edu.gt',
  estado: estado,
);

MensajeProgramado aviso({
  required bool pideConfirmacion,
  required int total,
  required int entregados,
  required int abiertos,
  required int confirmados,
}) => MensajeProgramado(
  id: 'p1',
  titulo: 'Aviso',
  tipo: 'INFORMATIVO',
  estado: 'ENVIADO',
  modo: 'UNICO',
  creadoPor: 'uid-1',
  requiereConfirmacion: pideConfirmacion,
  modoDestinatarios: 'TODOS',
  formato: const <String>['TEXTO'],
  totalDestinatarios: total,
  entregados: entregados,
  abiertos: abiertos,
  confirmados: confirmados,
);

void main() {
  group('el conteo de aperturas', () {
    test('se mide sobre el total, igual que todo lo demás', () {
      // A quien no le llegó tampoco lo abrió. Cambiar la base según convenga
      // es la forma más fácil de hacer que un reporte diga lo que uno quiere.
      final MensajeProgramado m = aviso(
        pideConfirmacion: false,
        total: 10,
        entregados: 8,
        abiertos: 4,
        confirmados: 0,
      );
      expect(m.porcentajeAbierto, 40);
    });

    test('dice cuántos lo recibieron y no lo han abierto', () {
      final MensajeProgramado m = aviso(
        pideConfirmacion: false,
        total: 10,
        entregados: 8,
        abiertos: 3,
        confirmados: 0,
      );
      expect(m.entregadosSinAbrir, 5);
    });

    test('nunca da un negativo si las cuentas llegan raras', () {
      // Los contadores los lleva el servidor con incrementos; un reintento mal
      // contado no puede acabar mostrando «-2 sin abrir».
      final MensajeProgramado m = aviso(
        pideConfirmacion: false,
        total: 3,
        entregados: 2,
        abiertos: 3,
        confirmados: 0,
      );
      expect(m.entregadosSinAbrir, 0);
    });

    test('un aviso sin destinatarios no inventa un porcentaje', () {
      expect(
        aviso(
          pideConfirmacion: false,
          total: 0,
          entregados: 0,
          abiertos: 0,
          confirmados: 0,
        ).porcentajeAbierto,
        0,
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // CUATRO SITUACIONES, Y CADA UNA SE RESUELVE DISTINTO.
  // ──────────────────────────────────────────────────────────────────────────
  //
  // Antes se decía «Entregado» de todo lo que no estuviera confirmado ni
  // fallido, y ahí caían dos casos que no se parecen: quien lo abrió y no
  // respondió, y quien no lo ha abierto siquiera. Al primero se le insiste; con
  // el segundo hay que averiguar si le llegan las notificaciones.
  group('la situación de cada destinatario', () {
    test('sin confirmación: se distingue quién lo abrió', () {
      expect(
        situacionDe(persona('ABIERTO'), false).etiqueta,
        Textos.detalleAbrio,
      );
      expect(
        situacionDe(persona('ENTREGADO'), false).etiqueta,
        Textos.detalleNoAbrio,
      );
    });

    test('con confirmación: abrir sin confirmar NO es lo mismo que no abrir', () {
      expect(
        situacionDe(persona('ABIERTO'), true).etiqueta,
        Textos.detalleAbrioSinConfirmar,
      );
      expect(
        situacionDe(persona('ENTREGADO'), true).etiqueta,
        Textos.detalleNoAbrio,
      );
    });

    test('confirmado gana a todo lo demás', () {
      for (final bool pide in <bool>[true, false]) {
        expect(
          situacionDe(persona('CONFIRMADO'), pide).etiqueta,
          Textos.estadoConfirmado,
          reason: 'pideConfirmacion=$pide',
        );
      }
    });

    test('un fallo de entrega no se confunde con un descuido', () {
      // Uno se resuelve revisando el dispositivo; el otro, insistiendo a la
      // persona. Pintarlos igual mezclaría dos problemas distintos.
      final SituacionEntrega f = situacionDe(persona('FALLIDO'), false);
      expect(f.etiqueta, Textos.estadoNoLeLlego);
      expect(f.color, isNot(situacionDe(persona('ENTREGADO'), false).color));
    });

    test('cada situación se distingue de las demás', () {
      // Cuatro etiquetas distintas para cuatro casos distintos: si dos
      // coincidieran, el detalle dejaría de servir para decidir a quién
      // escribirle.
      final Set<String> etiquetas = <String>{
        for (final String e in <String>[
          'FALLIDO',
          'ENTREGADO',
          'ABIERTO',
          'CONFIRMADO',
        ])
          situacionDe(persona(e), true).etiqueta,
      };
      expect(etiquetas.length, 4);
    });
  });
}
