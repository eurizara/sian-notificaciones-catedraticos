/// SIAN — Aviso de que la suscripción de push rotó (DT-23).
///
/// Tras importación condicional, como el resto de envoltorios: `dart:js_interop`
/// no existe en la máquina virtual donde corren las pruebas.
library;

export 'rotacion_vm.dart' if (dart.library.js_interop) 'rotacion_web.dart';
