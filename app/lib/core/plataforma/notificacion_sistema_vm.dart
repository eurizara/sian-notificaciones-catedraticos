/// Implementación para la máquina virtual: pruebas y herramientas.
///
/// Fuera del navegador no hay sistema de notificaciones que invocar. Devuelve
/// `false` en vez de fingir éxito: quien llame tiene que poder distinguir «se
/// mostró en el sistema» de «no se pudo», porque de eso depende si además hace
/// falta enseñar algo dentro de la aplicación.
library;

Future<bool> mostrarNotificacionDelSistema({
  required String titulo,
  required String cuerpo,
  required bool urgente,
  String? etiqueta,
}) async => false;
