/// La insignia del icono — RF-ENT-06, RF-ENT-12.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Lo que se comprueba es que el número de afuera y el de adentro coincidan.
/// ────────────────────────────────────────────────────────────────────────────
///
/// La persona abre la aplicación porque el icono decía «3». Si la fila de
/// filtros dijera «Sin leer 2», los dos números quedan desmentidos y a partir
/// de ahí ninguno se cree. Por eso la insignia no calcula nada propio: repite
/// el conteo del filtro «Sin leer», y esa igualdad es lo que se prueba.
///
/// Fuera del navegador no hay icono, así que el sustituto de la máquina virtual
/// se limita a anotar lo último que se pidió. Basta: lo que está en duda es la
/// regla, no la llamada del navegador.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sian/core/plataforma/insignia_vm.dart';
import 'package:sian/domain/repositorios.dart';
import 'package:sian/presentation/docente/filtro_bandeja.dart';
import 'package:sian/presentation/docente/insignia_bandeja.dart';

MensajeRecibido msg({
  required String id,
  required String estado,
  bool pideConfirmacion = false,
}) => MensajeRecibido(
  mensajeId: id,
  titulo: 'Aviso $id',
  cuerpo: 'Cuerpo',
  tipo: 'INFORMATIVO',
  estado: estado,
  requiereConfirmacion: pideConfirmacion,
  entregadoEn: DateTime(2026, 3, 17, 8),
);

void main() {
  setUp(() {
    insigniaPedida = null;
    vecesQueSePidioInsignia = 0;
  });

  group('RF-ENT-06 · el número del icono', () {
    test('cuenta los mensajes que no se han abierto', () {
      sincronizarInsignia(<MensajeRecibido>[
        msg(id: 'a', estado: 'ENTREGADO'),
        msg(id: 'b', estado: 'ENTREGADO'),
        msg(id: 'c', estado: 'ABIERTO'),
      ]);

      expect(insigniaPedida, 2);
    });

    test('vale exactamente lo que dice el filtro «Sin leer»', () {
      final List<MensajeRecibido> mezcla = <MensajeRecibido>[
        msg(id: 'a', estado: 'ENTREGADO'),
        msg(id: 'b', estado: 'ENTREGADO', pideConfirmacion: true),
        msg(id: 'c', estado: 'ABIERTO', pideConfirmacion: true),
        msg(id: 'd', estado: 'ABIERTO'),
        msg(id: 'e', estado: 'CONFIRMADO', pideConfirmacion: true),
      ];

      sincronizarInsignia(mezcla);

      // La igualdad es el punto: si alguien cambiara el criterio de la insignia
      // sin cambiar el del filtro, esto se cae.
      expect(insigniaPedida, contarEn(FiltroBandeja.sinLeer, mezcla));
    });

    test('un mensaje abierto pero sin confirmar NO cuenta', () {
      // Sigue pendiente de una acción, y aun así no suma: el filtro «Sin leer»
      // tampoco lo cuenta, y los dos números tienen que decir lo mismo.
      sincronizarInsignia(<MensajeRecibido>[
        msg(id: 'a', estado: 'ABIERTO', pideConfirmacion: true),
      ]);

      expect(insigniaPedida, isNull);
    });

    test('sin nada sin leer, la insignia se retira en vez de mostrar cero', () {
      sincronizarInsignia(<MensajeRecibido>[msg(id: 'a', estado: 'ABIERTO')]);

      // Un icono con un «0» pegado se lee como si algo estuviera pendiente.
      expect(insigniaPedida, isNull);
      expect(vecesQueSePidioInsignia, 1, reason: 'se pidió retirarla');
    });

    test('con la bandeja vacía tampoco se queda un número viejo', () {
      sincronizarInsignia(<MensajeRecibido>[msg(id: 'a', estado: 'ENTREGADO')]);
      expect(insigniaPedida, 1);

      sincronizarInsignia(<MensajeRecibido>[]);
      expect(insigniaPedida, isNull);
    });
  });
}
