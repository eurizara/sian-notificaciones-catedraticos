/// SIAN — Manda un reporte de fallo (DT-34).
///
/// Con importación condicional por lo de siempre: `package:web` no existe en
/// la máquina virtual de las pruebas.
library;

export 'envio_reporte_vm.dart'
    if (dart.library.js_interop) 'envio_reporte_web.dart';
