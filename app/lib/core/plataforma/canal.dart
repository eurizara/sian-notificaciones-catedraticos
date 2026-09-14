/// SIAN — Lo que la aplicación le deja dicho al service worker (DT-23).
///
/// Tras importación condicional, como el resto de envoltorios: `dart:js_interop`
/// no existe en la máquina virtual donde corren las pruebas.
library;

export 'canal_vm.dart' if (dart.library.js_interop) 'canal_web.dart';
