/// Identificador estable de esta instalación de la aplicación.
///
/// Tras importación condicional, como el resto de envoltorios: `package:web`
/// no existe en la máquina virtual donde corren las pruebas.
library;

export 'instalacion_vm.dart'
    if (dart.library.js_interop) 'instalacion_web.dart';
