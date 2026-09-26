/// Abrir un enlace del texto de un aviso (U-2).
///
/// Tras importación condicional, como el resto: `package:web` no existe en la
/// máquina virtual donde corren las pruebas.
library;

export 'enlace_vm.dart' if (dart.library.js_interop) 'enlace_web.dart';
