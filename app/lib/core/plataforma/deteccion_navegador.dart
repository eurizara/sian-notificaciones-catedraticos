/// SIAN — Detección del entorno, según dónde corra el código.
library;

export 'deteccion_vm.dart' if (dart.library.js_interop) 'deteccion_web.dart';
