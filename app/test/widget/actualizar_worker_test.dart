/// La comprobación de service worker al arrancar — DT-17.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Servir el archivo sin caché no basta: alguien tiene que preguntar.
/// ────────────────────────────────────────────────────────────────────────────
///
/// `firebase.json` sirve el service worker con `no-store`, lo que evita que el
/// navegador se quede con una copia vieja **cuando va a buscarla**. No lo
/// obliga a ir. Una PWA de iOS que se reabre puede seguir ejecutando el worker
/// de hace días.
///
/// Y despista, porque la aplicación sí se renueva: se ve el código nuevo con el
/// worker viejo por debajo. Como es el worker quien muestra las notificaciones
/// y lleva la insignia, los arreglos parecen no haber llegado. Ocurrió el 28 de
/// agosto de 2026: en desarrollo, recién reinstalado, las notificaciones con la
/// aplicación cerrada funcionaban; en producción, con la misma versión
/// desplegada pero sin reinstalar, no.
///
/// Fuera del navegador no hay nada que actualizar, así que el sustituto solo
/// cuenta las veces que se pidió. Basta: lo que está en duda es que se pida.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sian/core/plataforma/actualizar_worker_vm.dart';

void main() {
  setUp(() => vecesQueSePidioActualizar = 0);

  group('DT-17 · la actualización tiene que llegar sin reinstalar', () {
    test('arrancar pide comprobar si hay un worker nuevo', () {
      actualizarWorkers();
      expect(vecesQueSePidioActualizar, 1);
    });

    test('cada arranque vuelve a pedirlo', () {
      // No se memoriza a propósito: si se comprobara una sola vez por
      // instalación, un arreglo publicado después no llegaría nunca, que es
      // justo el defecto que esto viene a cerrar.
      actualizarWorkers();
      actualizarWorkers();
      actualizarWorkers();
      expect(vecesQueSePidioActualizar, 3);
    });
  });
}
