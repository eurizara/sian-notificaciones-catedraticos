/// Guardar en el aparato una imagen de un aviso (U-3).
///
/// Tras importación condicional, como el resto: `package:web` no existe en la
/// máquina virtual donde corren las pruebas.
library;

export 'descarga_vm.dart' if (dart.library.js_interop) 'descarga_web.dart';
