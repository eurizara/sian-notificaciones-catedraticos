/// Identificador estable de esta instalación de la aplicación.
///
/// ────────────────────────────────────────────────────────────────────────────
/// El token de notificaciones NO sirve como identidad del aparato.
/// ────────────────────────────────────────────────────────────────────────────
///
/// El registro de dispositivos usaba el token como identificador del documento,
/// con este razonamiento escrito al lado: «reabrir la aplicación cien veces no
/// crea cien dispositivos, refresca el mismo». Es cierto donde el token es
/// estable. **En iOS no lo es**: Safari lo rota, así que cada apertura escribía
/// un documento nuevo y el anterior se quedaba.
///
/// Medido en producción el 28 de agosto de 2026: **nueve tokens de un mismo
/// iPhone**, de una sola persona, en dos días. Cada aviso se enviaba a los
/// nueve, y como los viejos estaban muertos, sus avisos constaban como no
/// entregados aunque tuviera la aplicación instalada y el permiso concedido.
///
/// Este identificador lo genera la aplicación una sola vez y lo guarda en
/// `localStorage`, que sobrevive a cerrar sesión, a cerrar la aplicación y a
/// reiniciar el teléfono. Solo desaparece si se borran los datos del sitio o se
/// desinstala la aplicación — y en ese caso empezar de cero es lo correcto,
/// porque el navegador ya olvidó todo lo demás.
///
/// No se usa el identificador de instalación de Firebase, que serviría igual,
/// para no depender de otro SDK por un dato que aquí se resuelve en diez
/// líneas.
library;

import 'dart:math';

import 'package:web/web.dart' as web;

const String _clave = 'sian.instalacion';

String? _enMemoria;

/// Devuelve el identificador, creándolo la primera vez.
///
/// Si `localStorage` no estuviera disponible —modo privado, o un navegador que
/// lo bloquee—, se conserva en memoria: dentro de esa sesión el identificador
/// sigue siendo estable, que es lo que evita duplicar el registro en cada
/// apertura. Al cerrar se pierde, y eso es preferible a fallar.
String identificadorDeInstalacion() {
  if (_enMemoria != null) {
    return _enMemoria!;
  }

  try {
    final web.Storage almacen = web.window.localStorage;
    final String? guardado = almacen.getItem(_clave);
    if (guardado != null && guardado.isNotEmpty) {
      return _enMemoria = guardado;
    }
    final String nuevo = _generar();
    almacen.setItem(_clave, nuevo);
    return _enMemoria = nuevo;
  } on Object catch (_) {
    return _enMemoria = _generar();
  }
}

/// Cadena aleatoria suficientemente larga para no repetirse entre aparatos.
///
/// No hace falta que sea imposible de adivinar: no autoriza nada. Solo tiene
/// que ser distinta en cada instalación.
String _generar() {
  final Random azar = Random.secure();
  const String alfabeto = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final String cuerpo = List<String>.generate(
    24,
    (_) => alfabeto[azar.nextInt(alfabeto.length)],
  ).join();
  return 'ins_$cuerpo';
}
