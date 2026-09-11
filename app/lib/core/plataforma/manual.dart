/// SIAN — Abrir el manual (DT-28).
///
/// Tras importación condicional, como el resto de envoltorios: `dart:js_interop`
/// no existe en la máquina virtual donde corren las pruebas.
library;

export 'manual_vm.dart' if (dart.library.js_interop) 'manual_web.dart';
