/// SIAN — Filtros de la bandeja.
///
/// ────────────────────────────────────────────────────────────────────────────
/// UN MENSAJE ESTÁ EN UN SOLO SITIO. Las pestañas son etapas, no etiquetas.
/// ────────────────────────────────────────────────────────────────────────────
///
/// La primera versión dejaba que un aviso apareciera en dos pestañas a la vez
/// —«sin leer» y «sin confirmar»— con el argumento de que respondía que sí a
/// las dos preguntas. Sobre el papel se sostenía; en la mano, no: un aviso
/// recién llegado se veía en «Sin leer», desaparecía de ahí al abrirlo y
/// reaparecía en «Leídos» **aunque siguiera pendiente de confirmar**. Quien lo
/// mira no está clasificando: está preguntando *qué me falta*, y esa pregunta
/// solo tiene una respuesta por mensaje.
///
/// Ahora cada aviso recorre una fila de etapas, y está exactamente en una:
///
///     llega  →  SIN LEER  →  ¿pide confirmación?
///                              │  no  →  LEÍDOS
///                              └─ sí  →  SIN CONFIRMAR  →  LEÍDOS
///
/// La consecuencia práctica es que las cuentas cuadran: lo que suman las tres
/// pestañas es lo que hay. Antes no, y un contador que no cuadra es un
/// contador en el que nadie vuelve a confiar.
///
/// Lo urgente queda fuera de este reparto a propósito. Una alerta urgente sin
/// confirmar se anuncia **por encima del filtro**, en la cabecera fija, porque
/// es lo único de esta pantalla que no puede quedar detrás de una pestaña.
library;

import '../../domain/repositorios.dart';

/// La etapa en la que está un mensaje. Excluyentes por construcción.
enum EtapaBandeja {
  /// Llegó y nadie lo ha abierto.
  sinLeer,

  /// Ya se abrió, pedía confirmación y todavía no se ha dado.
  ///
  /// Abrir no es confirmar: mirar un aviso no declara haberlo leído.
  sinConfirmar,

  /// No queda nada por hacer con él: se abrió y no pedía confirmación, o ya
  /// se confirmó.
  leido,

  /// Ni llegó ni se leyó: entregas pendientes o fallidas.
  ///
  /// No se cuenta en ninguna de las tres etapas —no está sin leer, es que no
  /// está— pero sigue apareciendo en «Todos», porque esconderlo del todo
  /// dejaría al catedrático sin saber que existe.
  fueraDelCiclo,
}

/// En qué etapa está este mensaje. **Devuelve una sola.**
EtapaBandeja etapaDe(MensajeRecibido m) {
  // Confirmado primero: es el final del camino, y desde ahí no se vuelve.
  if (m.estaConfirmado) {
    return EtapaBandeja.leido;
  }
  if (m.estado == 'ENTREGADO') {
    return EtapaBandeja.sinLeer;
  }
  if (m.estado == 'ABIERTO') {
    return m.requiereConfirmacion
        ? EtapaBandeja.sinConfirmar
        : EtapaBandeja.leido;
  }
  return EtapaBandeja.fueraDelCiclo;
}

enum FiltroBandeja {
  /// El historial completo, incluido lo que quedó fuera del ciclo.
  todos,

  /// Etapa 1: llegó y nadie lo ha abierto. Es el filtro de partida.
  sinLeer,

  /// Etapa 2: abierto y esperando la confirmación de quien lo leyó.
  sinConfirmar,

  /// Etapa 3: cerrado.
  leidos,
}

/// ¿Este aviso entra en el filtro?
bool entraEn(FiltroBandeja filtro, MensajeRecibido m) => switch (filtro) {
  FiltroBandeja.todos => true,
  FiltroBandeja.sinLeer => etapaDe(m) == EtapaBandeja.sinLeer,
  FiltroBandeja.sinConfirmar => etapaDe(m) == EtapaBandeja.sinConfirmar,
  FiltroBandeja.leidos => etapaDe(m) == EtapaBandeja.leido,
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
