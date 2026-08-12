/// SIAN — Filtros de la bandeja.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Tres preguntas distintas, no tres cajones excluyentes.
/// ────────────────────────────────────────────────────────────────────────────
///
/// «Sin leer» y «Sin confirmar» se solapan a propósito: un aviso que llegó,
/// nadie abrió y además pedía confirmación está en los dos, porque responde
/// que sí a las dos preguntas. Repartirlos en cajones excluyentes obligaría a
/// decidir en cuál de los dos «pertenece», y esa decisión sería arbitraria
/// justo con los avisos que más importan.
///
/// La regla vive aquí, fuera de la pantalla, porque es lo que decide qué ve un
/// catedrático al abrir la aplicación. Algo así no puede existir solo dentro de
/// un `build`, donde no se puede comprobar.
library;

import '../../domain/repositorios.dart';

enum FiltroBandeja {
  /// El historial completo.
  todos,

  /// Llegó y nadie lo ha abierto todavía.
  ///
  /// Es el filtro de partida: al abrir la aplicación, lo que se quiere saber
  /// es qué hay de nuevo, no repasar lo de la semana pasada.
  sinLeer,

  /// Pedía confirmación de lectura y aún no se ha dado.
  ///
  /// Da igual si ya se abrió: abrir no es confirmar. Mientras no se confirme,
  /// sigue habiendo algo que hacer.
  sinConfirmar,

  /// Ya se abrió o ya se confirmó. No queda nada pendiente con él.
  leidos,
}

/// ¿Este aviso entra en el filtro?
bool entraEn(FiltroBandeja filtro, MensajeRecibido m) => switch (filtro) {
  FiltroBandeja.todos => true,
  // ENTREGADO significa exactamente «llegó y nadie lo ha abierto». Un aviso
  // que no llegó no está sin leer: no está.
  FiltroBandeja.sinLeer => m.estado == 'ENTREGADO',
  FiltroBandeja.sinConfirmar => m.requiereConfirmacion && !m.estaConfirmado,
  FiltroBandeja.leidos => m.estado == 'ABIERTO' || m.estaConfirmado,
};

List<MensajeRecibido> aplicarFiltro(
  FiltroBandeja filtro,
  List<MensajeRecibido> mensajes,
) => mensajes.where((MensajeRecibido m) => entraEn(filtro, m)).toList();

/// Cuántos hay en cada filtro. Va en la propia pestaña.
///
/// Un filtro sin número obliga a entrar para descubrir que está vacío, y eso
/// es exactamente lo que un contador evita.
int contarEn(FiltroBandeja filtro, List<MensajeRecibido> mensajes) =>
    mensajes.where((MensajeRecibido m) => entraEn(filtro, m)).length;
