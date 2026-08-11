/// SIAN — Lo que hay que saber del navegador donde corre la aplicación.
///
/// Tres preguntas, y las tres tienen consecuencias reales:
///
///   · **¿Es iOS?** Porque ahí las notificaciones solo existen si la PWA está
///     instalada en la pantalla de inicio (RES-05).
///   · **¿Está instalada?** Misma razón, y además determina si hay que mostrar
///     el instructivo (riesgo R-02).
///   · **¿Qué navegador es?** Para poder explicar cómo revertir un permiso
///     denegado, que se hace en sitios distintos en cada uno (RES-07).
library;

import 'plataforma/deteccion_navegador.dart';

enum PlataformaWeb { android, ios, escritorio }

class EntornoNavegador {
  const EntornoNavegador({
    required this.plataforma,
    required this.instalada,
    required this.navegador,
    required this.soportaNotificaciones,
    required this.versionIos,
    this.versionIosMenor,
  });

  final PlataformaWeb plataforma;

  /// La aplicación corre instalada en la pantalla de inicio, no en una pestaña.
  final bool instalada;

  /// Nombre y versión, para las instrucciones de permisos.
  final String navegador;

  /// El navegador expone la API de notificaciones.
  final bool soportaNotificaciones;

  /// Versión mayor de iOS, o `null` si no es iOS o no se pudo determinar.
  final int? versionIos;

  /// Versión menor de iOS. Hace falta para distinguir 16.3 de 16.4.
  final int? versionIosMenor;

  /// Valor que se guarda en `dispositivos.plataforma` (documento 05, 2.2).
  String get plataformaPersistida => switch (plataforma) {
    PlataformaWeb.android => 'WEB_ANDROID',
    PlataformaWeb.ios => 'WEB_IOS',
    PlataformaWeb.escritorio => 'WEB_ESCRITORIO',
  };

  /// RES-05: en iOS las notificaciones web exigen 16.4 o superior.
  ///
  /// ──────────────────────────────────────────────────────────────────────────
  /// El 4 de «16.4» importa: iOS 16.0 a 16.3 no las tienen.
  /// ──────────────────────────────────────────────────────────────────────────
  ///
  /// Antes se comparaba solo la versión mayor, así que un iPhone con 16.1
  /// pasaba por bueno y luego se quedaba mudo sin que nada lo explicara.
  ///
  /// Si no se pudo leer la versión NO se acusa al teléfono de viejo: decirle a
  /// alguien con un iPhone recién comprado que su iOS es antiguo lo manda a
  /// buscar una actualización que no existe. Sin dato, no hay afirmación.
  bool get iosDemasiadoAntiguo {
    if (plataforma != PlataformaWeb.ios || versionIos == null) {
      return false;
    }
    if (versionIos! < 16) {
      return true;
    }
    return versionIos == 16 && (versionIosMenor ?? 4) < 4;
  }

  /// ¿Hay que mostrar el instructivo de instalación?
  ///
  /// Solo en iOS y solo si no está instalada. En Android y escritorio las
  /// notificaciones funcionan en pestaña, así que insistir sería estorbar.
  bool get necesitaInstructivoInstalacion =>
      plataforma == PlataformaWeb.ios && !instalada;

  /// Detecta el entorno real.
  ///
  /// La implementación vive tras una importación condicional: `dart:js_interop`
  /// y `package:web` no existen en la máquina virtual donde corren las
  /// pruebas, y sin esta separación instrumentar el código web rompería
  /// `flutter test`.
  static EntornoNavegador detectar() => detectarEntorno();

  /// Entorno de escritorio, sin notificaciones. Es lo que se asume fuera del
  /// navegador — es decir, en las pruebas.
  static const EntornoNavegador desconocido = EntornoNavegador(
    plataforma: PlataformaWeb.escritorio,
    instalada: false,
    navegador: 'Pruebas',
    soportaNotificaciones: false,
    versionIos: null,
  );
}
