/// Implementación para navegador.
///
/// Se escribe por el canal de **errores** a propósito: `console.log` lo
/// ocultan varias consolas por omisión, y una traza que no se ve no sirve de
/// nada. Fue lo que costó varias rondas de diagnóstico a ciegas.
///
/// Antes de la fase 2 conviene moverlo detrás de una bandera de compilación:
/// en producción real esto no debe ensuciar el monitoreo de errores.
library;

import 'dart:js_interop';

@JS('console.error')
external void _consoleError(JSAny? mensaje);

void consolaError(String mensaje) => _consoleError(mensaje.toJS);
