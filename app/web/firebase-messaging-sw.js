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
 * El número pegado al icono de la aplicación instalada (RF-ENT-13).
 *
 * ────────────────────────────────────────────────────────────────────────────
 * El worker SUMA. Solo la aplicación abierta puede fijar el número o quitarlo.
 * ────────────────────────────────────────────────────────────────────────────
 *
 * La primera versión contaba `registration.getNotifications()` y, si salía
 * cero, llamaba a `clearAppBadge()`. En Android funcionaba. **En iOS ese método
 * devuelve una lista vacía** para las notificaciones que muestra el propio
 * worker, así que el resultado era el contrario del buscado: llegaba el aviso,
 * se contaban cero notificaciones y se BORRABA la insignia. El número no
 * aparecía nunca, y parecía que la Badging API no estaba soportada.
 *
 * Ahora el worker lleva su propia cuenta en IndexedDB y solo la incrementa. La
 * aplicación, que sí sabe cuántos mensajes hay sin leer porque está
 * autenticada, la fija con el número exacto cada vez que se abre o cambia algo,
 * y es la única que puede bajarla a cero.
 *
 * Los fallos se tragan: pintar un número es un adorno útil, no parte de la
 * entrega. Si esto reventara, se llevaría por delante la notificación misma.
 */

const BD_INSIGNIA = 'sian-insignia';
const ALMACEN = 'estado';
const LLAVE = 'sinLeer';
const LLAVE_AVISADOS = 'avisados';

function _abrirBase() {
  return new Promise((resolver, rechazar) => {
    const solicitud = indexedDB.open(BD_INSIGNIA, 1);
    solicitud.onupgradeneeded = () => solicitud.result.createObjectStore(ALMACEN);
    solicitud.onsuccess = () => resolver(solicitud.result);
    solicitud.onerror = () => rechazar(solicitud.error);
  });
}

function _enBase(modo, operacion) {
  return _abrirBase().then(
    (bd) =>
      new Promise((resolver, rechazar) => {
        const transaccion = bd.transaction(ALMACEN, modo);
        const peticion = operacion(transaccion.objectStore(ALMACEN));
        peticion.onsuccess = () => resolver(peticion.result);
        peticion.onerror = () => rechazar(peticion.error);
      }),
  );
}

const _leer = (llave, siFalta) =>
  _enBase('readonly', (a) => a.get(llave)).then((v) => (v === undefined ? siFalta : v));
const _guardar = (llave, valor) => _enBase('readwrite', (a) => a.put(valor, llave));

/** Lo que la aplicación reportó la última vez que estuvo abierta. */
const leerBase = () => _leer(LLAVE, 0);
const guardarBase = (n) => _guardar(LLAVE, n);

/** Identificadores de mensaje avisados desde entonces, sin repetir. */
const leerAvisados = () => _leer(LLAVE_AVISADOS, []);
const guardarAvisados = (lista) => _guardar(LLAVE_AVISADOS, lista);

/** ¿Sabe este navegador pintar insignias? */
function hayInsignia() {
  return typeof self.navigator !== 'undefined' && 'setAppBadge' in self.navigator;
}

/** Pinta `cuenta`, o retira la insignia si es cero. */
async function pintarInsignia(cuenta) {
  if (!hayInsignia()) {
    trazar('insignia:no-soportada');
    return;
  }
  try {
    if (cuenta > 0) {
      await self.navigator.setAppBadge(cuenta);
    } else {
      await self.navigator.clearAppBadge();
    }
    trazar('insignia:pintada', { cuenta });
  } catch (e) {
    trazar('insignia:no-se-pudo', String(e));
  }
}

/**
 * Un mensaje más sin leer.
 *
 * ────────────────────────────────────────────────────────────────────────────
 * SE CUENTAN MENSAJES DISTINTOS. NADA QUE NO SEA UN MENSAJE CUENTA.
 * ────────────────────────────────────────────────────────────────────────────
 *
 * Esta función lleva dos correcciones, y las dos vinieron de ver el número
 * equivocado en un teléfono de verdad.
 *
 * **Primera: se cuentan mensajes, no `push` recibidos.** El sistema reintenta
 * la entrega hasta tres veces (RF-ENT-10), y además una persona puede tener
 * varios dispositivos registrados: un solo aviso puede llegar aquí tres o
 * cuatro veces. Contando llegadas, el icono decía «3» donde había uno. Por eso
 * se guarda el identificador del mensaje y se cuentan los distintos.
 *
 * **Segunda: no todo lo que llega por push es un mensaje.** Al activar las
 * notificaciones, el servidor manda una de prueba —«tu dispositivo quedó
 * registrado»— que no corresponde a ningún aviso y por lo tanto no lleva
 * `mensajeId`. La versión anterior la contaba igual, con este razonamiento
 * escrito al lado:
 *
 *     «Sin identificador no se puede distinguir un reintento de un mensaje
 *      nuevo. Se cuenta, porque perder un aviso es peor que contar uno de más.»
 *
 * Ese razonamiento estaba mal. La insignia no es un contador de cosas que
 * pasaron: **vale exactamente lo que dice el filtro «Sin leer»**, y algo sin
 * `mensajeId` no puede estar en ese filtro, porque no es un mensaje. Contarlo
 * no es «pecar de prudente»: es garantizar que los dos números discrepen, que
 * es justo el defecto contra el que se diseñó todo esto.
 *
 * Se vio en producción el 26 de agosto de 2026: activar las notificaciones
 * sumó uno, el primer mensaje real sumó otro, y el icono decía «2» con la
 * bandeja diciendo «Sin leer (1)».
 *
 * Lo que no lleva identificador se muestra igual —la notificación de prueba
 * tiene que verse, es la confirmación de que el permiso quedó bien— pero no
 * toca el número.
 */
async function sumarInsignia(mensajeId) {
  if (!mensajeId) {
    trazar('insignia:no-es-un-mensaje');
    return;
  }

  try {
    const avisados = await leerAvisados();
    if (avisados.includes(mensajeId)) {
      trazar('insignia:repetido-ignorado', { mensajeId });
      return;
    }
    avisados.push(mensajeId);
    await guardarAvisados(avisados);

    const cuenta = (await leerBase()) + avisados.length;
    await pintarInsignia(cuenta);
  } catch (e) {
    trazar('insignia:sumar-fallo', String(e));
  }
}

/**
 * El número exacto, que solo la aplicación autenticada conoce.
 *
 * Al fijarlo se olvida la lista de avisados: lo que la bandeja acaba de contar
 * ya incluye todo lo que había llegado.
 */
async function fijarInsignia(cuenta) {
  try {
    const n = Math.max(0, Number(cuenta) || 0);
    await guardarBase(n);
    await guardarAvisados([]);
    await pintarInsignia(n);
  } catch (e) {
    trazar('insignia:fijar-fallo', String(e));
  }
}

/**
 * La bandeja manda su conteo de «Sin leer» cada vez que cambia.
 *
 * Es la vía por la que el worker y la aplicación se mantienen de acuerdo: sin
 * esto, el worker seguiría sumando sobre un número que la persona ya resolvió.
 */
self.addEventListener('message', (evento) => {
  const dato = evento.data || {};
  if (dato.tipo === 'sian:insignia') {
    evento.waitUntil(fijarInsignia(dato.cuenta));
  }
});

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
    await sumarInsignia(opciones.data && opciones.data.mensajeId);
  });
}

/** Abrir la notificación lleva al detalle del mensaje (RF-ENT-07). */
self.addEventListener('notificationclick', (evento) => {
  evento.notification.close();
  // No se toca la insignia aquí. Abrir la notificación lleva a la bandeja, y
  // es la bandeja la que fija el número exacto en cuanto carga. Restarlo aquí
  // solo adelantaría medio segundo un dato que llega bien de todas formas, y a
  // cambio dejaría dos sitios decidiendo lo mismo.
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
