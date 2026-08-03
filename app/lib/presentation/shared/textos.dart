/// SIAN — Textos de la interfaz.
///
/// RNF-21: la interfaz está en español, y los textos residen en archivos de
/// recursos, **nunca incrustados en el código**. Que hoy solo exista un idioma
/// no cambia la regla: agregar otro debe ser añadir un archivo, no refactorizar
/// la aplicación (deuda DT-09, en estado mitigado precisamente por esto).
library;

abstract final class Textos {
  // --- Identidad -----------------------------------------------------------
  static const String nombreApp = 'SIAN';
  static const String nombreCompleto =
      'Sistema Institucional de Avisos y Notificaciones';
  static const String institucionMarcador = 'Universidad Mariano Gálvez';

  // --- Estado del arranque -------------------------------------------------
  static const String tituloEstado = 'Estado del sistema';
  static const String subtituloEstado =
      'Iteración 1.1 completada. La autenticación llega en la 1.2.';

  static const String cimientosListos = 'Cimientos';
  static const String cimientosDetalle =
      'Dominio, reglas de seguridad e integración continua';

  static const String flutterListo = 'Aplicación Flutter';
  static const String flutterDetalle = 'Compila y sirve como PWA instalable';

  static const String firebasePendiente = 'Firebase';
  static const String firebaseDetalleEmulador =
      'Apuntando a los emuladores locales';
  static const String firebaseDetalleNube = 'Apuntando al proyecto en la nube';
  static const String firebaseDetallePendiente =
      'Sin configurar: falta ejecutar flutterfire configure';

  static const String autenticacionPendiente = 'Autenticación';
  static const String autenticacionDetalle =
      'Google y correo/contraseña — iteración 1.2';

  static const String notificacionesPendiente = 'Notificaciones';
  static const String notificacionesDetalle =
      'Envío inmediato y recepción — iteración 1.3';

  static const String programacionPendiente = 'Programación y recurrencia';
  static const String programacionDetalle =
      'Despachador y confirmación de lectura — iteración 1.4';

  // --- Etiquetas de estado -------------------------------------------------
  static const String listo = 'Listo';
  static const String pendiente = 'Pendiente';
  static const String enCurso = 'En curso';

  // --- Avisos --------------------------------------------------------------
  static const String avisoEmuladorSinPush =
      'Los emuladores no entregan notificaciones push reales. FCM no tiene '
      'emulador: la llegada al dispositivo solo se verifica desplegando.';
}
