/// Sustituto para la máquina virtual: no hay service worker que avise (DT-23).
library;

/// Nadie llama a esto fuera del navegador, así que no hay nada que escuchar.
void escucharRotacionDeSuscripcion(void Function() alRotar) {}

/// Sin navegador no hay marca que leer.
Future<bool> huboRotacionPendiente() async => false;

/// Nadie muestra notificaciones fuera del navegador.
void escucharNotificacionMostrada(
  void Function([Map<String, String>? datos]) alMostrar,
) {}
