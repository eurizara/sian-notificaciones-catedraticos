/// SIAN — Configuración del entorno de ejecución.
///
/// Todo lo que cambia entre desarrollo, QA y producción entra por
/// `--dart-define`, nunca por una constante compilada en el código ni por un
/// archivo versionado (RNF-10, RES-10).
///
/// En desarrollo:
///   flutter run -d chrome --dart-define=USE_EMULATOR=true
///
/// En despliegue (documento 06, etapa E.1):
///   flutter build web --release \
///     --dart-define=FIREBASE_VAPID_KEY=$FIREBASE_VAPID_KEY \
///     --dart-define=USE_EMULATOR=false
library;

/// Parámetros del ambiente, resueltos en tiempo de compilación.
abstract final class Entorno {
  /// Apunta la aplicación a los emuladores locales en lugar de a la nube.
  ///
  /// Recuerda la limitación del documento 06, D.5: los emuladores **no**
  /// entregan notificaciones push reales. FCM no tiene emulador.
  static const bool usaEmulador = bool.fromEnvironment('USE_EMULATOR');

  /// Clave pública VAPID para Web Push. Es pública por diseño: viaja al
  /// navegador. Aun así se trata como configuración por ambiente.
  static const String claveVapid = String.fromEnvironment('FIREBASE_VAPID_KEY');

  /// Zona horaria institucional (RF-ADM-01, RN-05).
  ///
  /// Toda fecha se almacena en UTC y se presenta en esta zona. El valor real
  /// lo manda `configuracion/institucional`; este es el respaldo para el
  /// arranque, antes de haber leído Firestore.
  static const String zonaHoraria = String.fromEnvironment(
    'ZONA_HORARIA',
    defaultValue: 'America/Guatemala',
  );

  /// Puertos de los emuladores, según `firebase.json`.
  static const String hostEmulador = 'localhost';
  static const int puertoAuth = 9099;
  static const int puertoFirestore = 8080;
  static const int puertoFunctions = 5001;
  static const int puertoStorage = 9199;

  /// ¿Está completa la configuración necesaria para operar contra la nube?
  ///
  /// Sirve para dar un diagnóstico honesto en pantalla en lugar de fallar con
  /// un error críptico de Firebase a mitad del arranque.
  static bool get configuracionCompleta => usaEmulador || claveVapid.isNotEmpty;
}
