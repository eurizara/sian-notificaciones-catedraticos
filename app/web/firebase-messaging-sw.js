/* eslint-disable no-undef */
/**
 * SIAN — Service worker de mensajería (RF-ENT-06).
 *
 * ────────────────────────────────────────────────────────────────────────────
 * ESTE ARCHIVO NO SE FUSIONA JAMÁS CON `flutter_service_worker.js`.
 * ────────────────────────────────────────────────────────────────────────────
 *
 * Mezclar la lógica de mensajería dentro del service worker que genera Flutter
 * es el riesgo R-03 del documento 02, sección 13, y la causa más frecuente de
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
 * Pone al día el número pegado al icono de la aplicación instalada.
 *
 * ────────────────────────────────────────────────────────────────────────────
 * Se cuentan las notificaciones que siguen en pantalla, no las que llegaron.
 * ────────────────────────────────────────────────────────────────────────────
 *
 * Aquí no hay forma barata de saber cuántos mensajes tiene la persona sin leer:
 * el worker no está autenticado y no puede consultar Firestore. Lo que sí sabe
 * es cuántas notificaciones suyas siguen sin descartar, y ese número se le
 * parece bastante.
 *
 * Es una aproximación, y se corrige sola: en cuanto la aplicación se abre, la
 * bandeja fija la insignia con el número exacto de mensajes sin leer, que es el
 * mismo que muestra su filtro «Sin leer». El worker mantiene el número vivo
 * mientras la aplicación está cerrada; la aplicación manda cuando está abierta.
 *
 * Los fallos se tragan: pintar un número es un adorno útil, no parte de la
 * entrega. Si esto reventara, se llevaría por delante la notificación misma.
 */
async function actualizarInsignia() {
  if (!self.navigator || !('setAppBadge' in self.navigator)) {
    return;
  }
  try {
    const pendientes = await self.registration.getNotifications();
    if (pendientes.length > 0) {
      await self.navigator.setAppBadge(pendientes.length);
    } else {
      await self.navigator.clearAppBadge();
    }
  } catch (e) {
    trazar('insignia:no-se-pudo', String(e));
  }
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
      /*
        Patrón de vibración: [vibra, pausa, vibra, pausa, …] en milisegundos.

        La INTENSIDAD no se puede elegir desde la web en ninguna plataforma —
        la decide el motor del teléfono—, pero el patrón sí, y es lo que de
        verdad distingue una alerta de un aviso cualquiera: tres pulsos
        largos no se confunden con la vibración de un mensaje de WhatsApp.

        Una urgente insiste seis veces, con pulsos largos. Un informativo da
        uno corto: gastar la insistencia en todo la vuelve ruido, y entonces
        no queda nada con lo que gritar cuando hace falta.

        Android lo respeta. iOS lo IGNORA por completo, incluso instalada:
        Apple no expone control de vibración a la web, y esa es la deuda
        DT-02 — la única salida sería una aplicación nativa.
      */
      vibrate: esUrgente
        ? [400, 150, 400, 150, 400, 150, 400, 150, 400, 150, 400]
        : [200],
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
      await actualizarInsignia();
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
  messaging.onBackgroundMessage(async (carga) => {
    const { titulo, opciones } = componer(carga);
    trazar('fondo', { titulo });
    await self.registration.showNotification(titulo, opciones);
    await actualizarInsignia();
  });
}

/** Abrir la notificación lleva al detalle del mensaje (RF-ENT-07). */
self.addEventListener('notificationclick', (evento) => {
  evento.notification.close();
  // Una notificación menos en pantalla es un número menos en el icono. La
  // bandeja lo corregirá al abrirse, pero mientras tanto el icono no miente.
  evento.waitUntil(actualizarInsignia());
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
