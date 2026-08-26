/// SIAN — Notificación del sistema operativo pedida desde la aplicación.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Con la pestaña en primer plano nadie pinta la notificación del sistema.
/// ────────────────────────────────────────────────────────────────────────────
///
/// El service worker solo interviene cuando la aplicación está en segundo plano
/// o cerrada. En primer plano el mensaje llega a la aplicación y ahí se acaba:
/// no hay banner, ni sonido, ni vibración, porque nadie se lo pidió al sistema.
///
/// Esto lo pide. La aplicación usa el **mismo** registro de service worker, así
/// que la notificación es indistinguible de la que llega con la aplicación
/// cerrada: la muestra el sistema operativo, no una tarjeta dentro de la web.
///
/// Va tras importación condicional porque `dart:js_interop` no existe en la
/// máquina virtual donde corren las pruebas.
library;

export 'notificacion_sistema_vm.dart'
    if (dart.library.js_interop) 'notificacion_sistema_web.dart';
