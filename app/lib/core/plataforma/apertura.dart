/// Con qué destino se abrió la aplicación desde una notificación (C-6).
///
/// Tras importación condicional, como el resto: `package:web` no existe en la
/// máquina virtual donde corren las pruebas.
library;

export 'apertura_vm.dart' if (dart.library.js_interop) 'apertura_web.dart';
