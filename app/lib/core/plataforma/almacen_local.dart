/// SIAN — Preferencias que se guardan en este navegador (DT-21).
///
/// Tras importación condicional, como el resto de envoltorios: `dart:js_interop`
/// no existe en la máquina virtual donde corren las pruebas.
///
/// Es para preferencias de este dispositivo —la apariencia—, no para datos: lo
/// que hay aquí se pierde al borrar los datos del navegador, y no pasa nada.
library;

export 'almacen_local_vm.dart'
    if (dart.library.js_interop) 'almacen_local_web.dart';
