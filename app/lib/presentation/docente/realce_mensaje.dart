/// SIAN — Cuánta atención pide cada mensaje de la bandeja.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Si todo se ve igual, nada destaca. Y aquí destacar es la función.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Un catedrático abre la bandeja para saber **qué le falta por atender**, no
/// para leerla entera. Con todas las tarjetas idénticas, encontrarlo exige leer
/// título por título, y en un simulacro eso es tiempo que no hay.
///
/// La jerarquía está ordenada a propósito y es excluyente: cada mensaje recibe
/// **un solo** nivel, el más alto que le corresponda. Pintar dos señales a la
/// vez —urgente y sin leer, por ejemplo— produciría una bandeja de colores
/// donde otra vez nada destaca, que es el problema de partida.
library;

import 'package:flutter/material.dart';

import '../../domain/repositorios.dart';
import '../shared/tema.dart';

/// Niveles de atención, de más a menos.
enum NivelAtencion {
  /// Urgente que exige confirmación y sigue sin confirmar. Lo único que puede
  /// tener consecuencias reales si se pasa por alto.
  urgentePendiente,

  /// Pide confirmación y no se ha dado. Hay una acción pendiente de la persona.
  esperaConfirmacion,

  /// Todavía no se ha abierto. Informa, no reclama.
  sinLeer,

  /// Leído, o confirmado, o sin nada que hacer. Ninguno.
  ninguno,
}

/// Cómo se pinta un mensaje según lo que pida.
class Realce {
  const Realce({
    required this.nivel,
    required this.franja,
    required this.fondo,
    required this.tituloEnNegrita,
  });

  final NivelAtencion nivel;

  /// Color de la franja lateral. Nulo cuando no hay nada que señalar.
  final Color? franja;

  /// Tinte del fondo. Muy tenue: lo que distingue es la franja, no el relleno.
  final Color? fondo;

  final bool tituloEnNegrita;

  bool get destaca => nivel != NivelAtencion.ninguno;
}

/// Decide el realce de un mensaje.
///
/// Expuesta aparte de la pantalla para poder probar la jerarquía sin montar
/// nada: el orden entre niveles es la regla, y una regla que solo existe
/// dentro de un `build` no se puede verificar.
Realce realceDe(MensajeRecibido m) {
  // Confirmado es el final del camino: no reclama nada aunque sea urgente.
  if (m.estaConfirmado) {
    return const Realce(
      nivel: NivelAtencion.ninguno,
      franja: null,
      fondo: null,
      tituloEnNegrita: false,
    );
  }

  final bool faltaConfirmar = m.requiereConfirmacion;

  if (faltaConfirmar && m.esUrgente) {
    return Realce(
      nivel: NivelAtencion.urgentePendiente,
      franja: ColoresSian.urgente,
      fondo: ColoresSian.urgente.withValues(alpha: 0.07),
      tituloEnNegrita: true,
    );
  }

  if (faltaConfirmar) {
    return Realce(
      nivel: NivelAtencion.esperaConfirmacion,
      franja: ColoresSian.dorado,
      fondo: ColoresSian.dorado.withValues(alpha: 0.09),
      tituloEnNegrita: true,
    );
  }

  // Sin leer: se marca, pero sin gritar. Es información, no una tarea.
  if (m.estado == 'ENTREGADO') {
    return Realce(
      nivel: NivelAtencion.sinLeer,
      franja: ColoresSian.primario,
      fondo: ColoresSian.primario.withValues(alpha: 0.06),
      tituloEnNegrita: true,
    );
  }

  return const Realce(
    nivel: NivelAtencion.ninguno,
    franja: null,
    fondo: null,
    tituloEnNegrita: false,
  );
}
