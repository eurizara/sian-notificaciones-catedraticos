/// Pedirle al navegador que compruebe si hay un service worker nuevo.
///
/// Tras importación condicional, como el resto de envoltorios.
library;

export 'actualizar_worker_vm.dart'
    if (dart.library.js_interop) 'actualizar_worker_web.dart';
