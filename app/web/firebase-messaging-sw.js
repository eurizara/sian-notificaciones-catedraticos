/* eslint-disable no-undef */
/**
 * SIAN — Service worker de mensajería (RF-ENT-06).
 *
 * ────────────────────────────────────────────────────────────────────────────
 * ESTE ARCHIVO NO SE FUSIONA JAMÁS CON `flutter_service_worker.js`.
 * ────────────────────────────────────────────────────────────────────────────
 *
 * Mezclar la lógica de mensajería dentro del service worker que genera Flutter
 * es el riesgo R-03 del documento 02, sección 10, y la causa más frecuente de
 * que las notificaciones dejen de llegar tras una actualización, en silencio.
 *
 * `firebase.json` lo sirve con `Cache-Control: no-cache`, porque un navegador
 * que conserve una versión vieja deja de entregar notificaciones sin dar
 * ningún error. Lo mismo aplica a los archivos de entrada de Flutter, lección
 * que costó varias rondas de diagnóstico a ciegas.
 *
 * La configuración llega por `firebase-config.js`, que genera
 * `scripts/generar-firebase-options.sh`: este worker corre **fuera** de la
 * aplicación y no puede leer el archivo de Dart.
 */

importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');
importScripts('/firebase-config.js');

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (evento) => evento.waitUntil(self.clients.claim()));

if (self.SIAN_FIREBASE_CONFIG && self.SIAN_FIREBASE_CONFIG.apiKey !== 'SIN-CONFIGURAR') {
  firebase.initializeApp(self.SIAN_FIREBASE_CONFIG);
  const messaging = firebase.messaging();

  /**
   * Mensajes con la aplicación cerrada o en segundo plano (RF-ENT-06).
   *
   * Es lo que distingue un canal de avisos de una página web que hay que
   * recordar abrir.
   */
  messaging.onBackgroundMessage((carga) => {
    const datos = carga.data || {};
    const esUrgente = datos.tipo === 'URGENTE';

    // El prefijo «URGENTE» en el título no es cosmético: en iOS-PWA no se
    // puede definir sonido ni vibración propios, así que la distinción visible
    // es la única mitigación disponible (deuda DT-02).
    const titulo = esUrgente
      ? `URGENTE · ${datos.titulo || 'Alerta institucional'}`
      : datos.titulo || 'SIAN UMG-BDM';

    return self.registration.showNotification(titulo, {
      body: datos.cuerpo || '',
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      // Agrupa por mensaje: un reintento no genera dos avisos en la pantalla.
      tag: datos.mensajeId || 'sian',
      // Una alerta urgente no se descarta sola: exige un gesto.
      requireInteraction: esUrgente,
      data: { mensajeId: datos.mensajeId || '' },
    });
  });
}

/** Abrir la notificación lleva al detalle del mensaje (RF-ENT-07). */
self.addEventListener('notificationclick', (evento) => {
  evento.notification.close();
  const mensajeId = evento.notification.data && evento.notification.data.mensajeId;
  const destino = mensajeId ? `/mensajes/${mensajeId}` : '/';

  evento.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((ventanas) => {
        // Si la aplicación ya está abierta se reutiliza esa ventana, en lugar
        // de abrir una segunda.
        for (const ventana of ventanas) {
          if ('focus' in ventana) {
            if ('navigate' in ventana) {
              ventana.navigate(destino);
            }
            return ventana.focus();
          }
        }
        return self.clients.openWindow(destino);
      }),
  );
});
