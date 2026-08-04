/// SIAN — Escritura en la consola del navegador.
///
/// Existe con importación condicional porque `dart:js_interop` **no está
/// disponible en la máquina virtual** donde corren las pruebas unitarias.
/// Sin esta separación, instrumentar el código web rompe `flutter test`, que
/// es exactamente lo que pasó al añadir las trazas de sesión.
library;

export 'consola_vm.dart' if (dart.library.js_interop) 'consola_web.dart';
