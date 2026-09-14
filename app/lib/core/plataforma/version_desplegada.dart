/// SIAN — Qué versión está publicada ahora mismo en el servidor.
///
/// Tras importación condicional, como el resto de envoltorios: `dart:js_interop`
/// no existe en la máquina virtual donde corren las pruebas.
library;

export 'version_desplegada_vm.dart'
    if (dart.library.js_interop) 'version_desplegada_web.dart';
