/// Que nadie vuelva a esperar un service worker que no va a llegar.
///
/// ────────────────────────────────────────────────────────────────────────────
/// El fallo del 12 de septiembre de 2026
/// ────────────────────────────────────────────────────────────────────────────
///
/// `navigator.serviceWorker.ready` no resuelve nunca en esta aplicación: el
/// worker de Flutter se da de baja solo en cuanto se activa, y el nuestro vive
/// en `/firebase-cloud-messaging-push-scope`, que no cubre la página. Una
/// promesa pendiente para siempre no lanza y no se atrapa: quien la espera se
/// queda colgado en silencio.
///
/// Pasó al estrenar la suscripción propia. El registro del dispositivo empezó
/// a esperar `ready` antes de pedir nada, **ningún aparato volvió a
/// registrarse** —ni por la vía nueva ni por FCM—, no hubo un solo error en los
/// registros del servidor, y un iPhone recién abierto con la versión del día se
/// quedó sin recibir el aviso.
///
/// Es un error que no deja rastro, así que el guardián tiene que estar en el
/// código fuente: `ready` no se usa, se usa `registroDelWorker()`, que tiene
/// plazo y devuelve nulo si no hay worker.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('el registro del service worker', () {
    final List<File> fuentes = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();

    test('nadie espera `serviceWorker.ready`', () {
      final List<String> culpables = <String>[];
      for (final File f in fuentes) {
        final String codigo = f.readAsStringSync();
        // Solo el código, no el comentario que explica por qué no se usa.
        final Iterable<String> lineas = codigo
            .split('\n')
            .where((String l) => !l.trimLeft().startsWith('///'))
            .where((String l) => !l.trimLeft().startsWith('//'));
        if (lineas.any((String l) => l.contains('serviceWorker.ready'))) {
          culpables.add(f.path);
        }
      }
      expect(
        culpables,
        isEmpty,
        reason:
            'esperar `serviceWorker.ready` cuelga para siempre: usar '
            '`registroDelWorker()` de registro_worker_web.dart',
      );
    });

    test('el ayudante tiene plazo y admite que no hay worker', () {
      final String codigo = File(
        'lib/core/plataforma/registro_worker_web.dart',
      ).readAsStringSync();

      // Sin plazo se vuelve al fallo que motivó todo esto.
      expect(codigo, contains('.timeout('));
      // Devolver nulo es lo que deja a quien llama seguir por FCM.
      expect(codigo, contains('Future<web.ServiceWorkerRegistration?>'));
      // El alcance tiene que ser el mismo que usa el SDK de Firebase; con otro
      // habría dos registros del mismo guion y dos suscripciones.
      expect(codigo, contains('/firebase-cloud-messaging-push-scope'));
    });

    test('el registro del dispositivo no se queda esperando la suscripción', () {
      // Aunque el ayudante ya tenga plazo: si la vía nueva tarda, el aparato
      // se registra por FCM en vez de quedarse sin ninguna.
      final String codigo = File(
        'lib/infrastructure/firebase/repositorio_dispositivos.dart',
      ).readAsStringSync();
      final int i = codigo.indexOf('suscribirConLlavePropia(');
      expect(i, greaterThan(-1));
      expect(codigo.substring(i, i + 400), contains('.timeout('));
    });
  });
}
