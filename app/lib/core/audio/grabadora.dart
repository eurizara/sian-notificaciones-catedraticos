/// Fábrica de la grabadora, tras importación condicional.
///
/// `dart:js_interop` y `package:web` no existen en la máquina virtual donde
/// corren las pruebas. Sin esta separación, instrumentar la grabación rompería
/// `flutter test`.
library;

export 'grabadora_vm.dart' if (dart.library.js_interop) 'grabadora_web.dart';
