/// SIAN — Selección de una imagen desde el dispositivo (RF-MSG-04).
///
/// Sin dependencias externas: un `<input type="file">` nativo hace exactamente
/// esto, y en móvil abre por sí solo la cámara o la galería. Añadir un paquete
/// para envolverlo traería su propia cadena de dependencias y su propio ritmo
/// de actualizaciones, a cambio de nada.
///
/// Tras importación condicional, como el resto: `dart:js_interop` no existe en
/// la máquina virtual donde corren las pruebas.
library;

export 'archivo_elegido.dart';
export 'selector_archivo_vm.dart'
    if (dart.library.js_interop) 'selector_archivo_web.dart';
