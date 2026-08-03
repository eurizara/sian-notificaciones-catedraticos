/* eslint-disable no-undef */
/**
 * SIAN — Service worker de mensajería (RF-ENT-06).
 *
 * ────────────────────────────────────────────────────────────────────────────
 * ESTE ARCHIVO NO SE FUSIONA JAMÁS CON `flutter_service_worker.js`.
 * ────────────────────────────────────────────────────────────────────────────
 *
 * Flutter Web genera su propio service worker para el almacenamiento en caché
 * de la aplicación. Mezclar la lógica de mensajería dentro de aquel archivo es
 * el riesgo R-03 del documento 02, sección 10, y la causa más frecuente de que
 * las notificaciones dejen de llegar tras una actualización, sin ningún error
 * visible.
 *
 * `firebase.json` sirve este archivo con `Cache-Control: no-cache`, porque un
 * navegador que conserve una versión vieja deja de entregar notificaciones en
 * silencio (documento 06, etapa E.2).
 *
 * Estado: iteración 1.1 — la estructura está puesta; el manejador de segundo
 * plano se completa en la iteración 1.3, cuando exista el envío real.
 */

importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

// La configuración la inyecta el proceso de compilación. Los valores de web
// son públicos por diseño (viajan al navegador), pero siguen siendo
// configuración por ambiente: nunca se escriben a mano aquí.
// PENDIENTE iteración 1.2: sustituir por la configuración real generada.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (evento) => evento.waitUntil(self.clients.claim()));

/**
 * Manejador de segundo plano — RF-ENT-06.
 *
 * Es lo que hace que la notificación llegue con la aplicación cerrada. Sin
 * esto, las notificaciones solo aparecen con la pestaña abierta, que es
 * exactamente el fallo descrito en el anexo del documento 06.
 *
 * Se activará en la iteración 1.3:
 *
 *   firebase.initializeApp(configuracion);
 *   const messaging = firebase.messaging();
 *   messaging.onBackgroundMessage((carga) => {
 *     const esUrgente = carga.data?.tipo === 'URGENTE';
 *     self.registration.showNotification(
 *       esUrgente ? `URGENTE · ${carga.data.titulo}` : carga.data.titulo,
 *       {
 *         body: carga.data.cuerpo,
 *         icon: '/icons/Icon-192.png',
 *         badge: '/icons/Icon-192.png',
 *         tag: carga.data.mensajeId,
 *         requireInteraction: esUrgente,
 *         data: { mensajeId: carga.data.mensajeId },
 *       },
 *     );
 *   });
 *
 * El prefijo «URGENTE» en el título no es cosmético: en iOS-PWA no se puede
 * definir sonido ni vibración propios, así que la distinción visible es la
 * única mitigación disponible (deuda DT-02).
 */

/** Abrir la notificación lleva al detalle del mensaje (RF-ENT-07). */
self.addEventListener('notificationclick', (evento) => {
  evento.notification.close();
  const mensajeId = evento.notification.data && evento.notification.data.mensajeId;
  const destino = mensajeId ? `/mensajes/${mensajeId}` : '/';

  evento.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((ventanas) => {
        // Si la aplicación ya está abierta, se reutiliza esa ventana en lugar
        // de abrir una segunda.
        for (const ventana of ventanas) {
          if ('focus' in ventana) {
            ventana.navigate(destino);
            return ventana.focus();
          }
        }
        return self.clients.openWindow(destino);
      }),
  );
});
