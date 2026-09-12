/// SIAN — Suscribirse al push con nuestra propia llave (DT-23).
///
/// Tras importación condicional, como el resto de envoltorios: `dart:js_interop`
/// no existe en la máquina virtual donde corren las pruebas.
library;

export 'suscripcion_vm.dart'
    if (dart.library.js_interop) 'suscripcion_web.dart';
