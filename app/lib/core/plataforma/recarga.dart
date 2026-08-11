/// Recargar la aplicación, como el F5 del navegador.
///
/// Tras importación condicional, como el resto: `package:web` no existe en la
/// máquina virtual donde corren las pruebas.
library;

export 'recarga_vm.dart' if (dart.library.js_interop) 'recarga_web.dart';
