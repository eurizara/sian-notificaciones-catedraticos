/// Insignia numérica sobre el icono de la aplicación instalada.
///
/// Tras importación condicional, como el resto de envoltorios: `dart:js_interop`
/// no existe en la máquina virtual donde corren las pruebas.
library;

export 'insignia_vm.dart' if (dart.library.js_interop) 'insignia_web.dart';
