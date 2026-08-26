/// Reproductor de audio nativo del navegador.
///
/// Tras importación condicional: registrar una vista de plataforma exige
/// `dart:ui_web`, que no existe en la máquina virtual de las pruebas.
library;

export 'audio_html_vm.dart' if (dart.library.js_interop) 'audio_html_web.dart';
