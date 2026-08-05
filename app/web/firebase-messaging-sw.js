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

/** Traza visible en la consola del navegador. Diagnosticar a ciegas ya costó caro. */
function trazar(paso, extra) {
  console.error(`SIAN.sw ${paso}`, extra === undefined ? '' : JSON.stringify(extra));
}

/**
 * Compone la notificación a partir de lo que venga.
 *
 * El servidor manda solo datos —para que el prefijo «URGENTE» y el
 * `requireInteraction` los decidamos aquí y no el navegador—, pero se acepta
 * también un bloque `notification`: una notificación sin cuerpo por un
 * desajuste de nombres es un fallo mudo, y ya costó una ronda de pruebas.
 */
function componer(carga) {
  const datos = (carga && carga.data) || {};
  const deNotificacion = (carga && carga.notification) || {};
  const esUrgente = datos.tipo === 'URGENTE';

  // El prefijo «URGENTE» en el título no es cosmético: en iOS-PWA no se puede
  // definir sonido ni vibración propios, así que la distinción visible es la
  // única mitigación disponible (deuda DT-02).
  const base = datos.titulo || deNotificacion.title || 'SIAN UMG-BDM';

  return {
    titulo: esUrgente ? `URGENTE · ${base}` : base,
    opciones: {
      body: datos.cuerpo || deNotificacion.body || '',
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      // Agrupa por mensaje. Sirve además para que las dos rutas que pueden
      // mostrar el mismo aviso —esta y la de la aplicación— se reemplacen en
      // vez de duplicarse.
      tag: datos.mensajeId || 'sian',
      // Una alerta urgente no se descarta sola: exige un gesto.
      requireInteraction: esUrgente,
      // Android la usa; iOS la ignora sin quejarse (DT-02).
      vibrate: esUrgente ? [200, 100, 200, 100, 200] : [200],
      data: { mensajeId: datos.mensajeId || '' },
    },
  };
}

/**
 * ────────────────────────────────────────────────────────────────────────────
 * Con la aplicación ABIERTA, el SDK de Firebase no muestra nada.
 * ────────────────────────────────────────────────────────────────────────────
 *
 * Cuando hay una ventana visible, el SDK entrega el mensaje a la página y no
 * llama a `onBackgroundMessage`. Es razonable como valor por omisión —una web
 * cualquiera no quiere notificar lo que ya estás viendo—, pero aquí sí: un
 * aviso de emergencia tiene que sonar aunque tuvieras la aplicación delante.
 *
 * Se atiende el evento `push` en crudo y se muestra la notificación **desde el
 * service worker**. En iOS es además la única vía admitida: Apple solo entrega
 * notificaciones originadas en el manejador de `push`, y pedirlas desde la
 * página no basta.
 *
 * Solo actúa si hay ventana visible. Con la aplicación cerrada o en segundo
 * plano se calla y deja trabajar a `onBackgroundMessage`, para no mostrar dos.
 */
self.addEventListener('push', (evento) => {
  evento.waitUntil(
    (async () => {
      const ventanas = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      });
      const hayVisible = ventanas.some((v) => v.visibilityState === 'visible');

      if (!hayVisible) {
        trazar('push:segundo-plano', { ventanas: ventanas.length });
        return;
      }

      let carga = {};
      try {
        carga = evento.data ? evento.data.json() : {};
      } catch (e) {
        trazar('push:carga-ilegible', String(e));
      }

      const { titulo, opciones } = componer(carga);
      trazar('push:primer-plano', { titulo });
      await self.registration.showNotification(titulo, opciones);
    })(),
  );
});

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
    const { titulo, opciones } = componer(carga);
    trazar('fondo', { titulo });
    return self.registration.showNotification(titulo, opciones);
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
