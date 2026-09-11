/**
 * SIAN — Las decisiones del service worker, separadas de sus efectos (DT-17).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * De los siete defectos de notificación, los siete vivían en el worker y
 * ninguno lo encontró una prueba.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * El motivo no era descuido: un service worker no se puede montar en una prueba
 * de Flutter ni en una de Functions. Necesita `self`, `indexedDB`,
 * `registration`, `clients` — un navegador entero. Así que el archivo se
 * probaba de la única forma que quedaba: con un teléfono en la mano, y solo
 * cuando alguien se acordaba de probar en los dos sistemas.
 *
 * Lo que sí se puede probar es **lo que decide**. Aquí viven esas decisiones,
 * como funciones puras: entra un estado, sale una respuesta, sin tocar nada.
 * `firebase-messaging-sw.js` las importa y se queda con los efectos —pintar,
 * guardar, cerrar—, que es lo que de verdad necesita un navegador.
 *
 * La regla para saber qué va aquí: si para probarlo hace falta un navegador, no
 * es una decisión, es un efecto.
 *
 * Se carga con `importScripts('/sw-decisiones.js')` desde el worker y con
 * `require()` desde las pruebas de Node. El envoltorio de abajo es lo único que
 * hace falta para las dos cosas.
 */

(function (global) {
  'use strict';

  /**
   * ¿Cuáles de las notificaciones mostradas hay que cerrar?
   *
   * ───────────────────────────────────────────────────────────────────────────
   * Esta es la corrección de DT-26, y explica por qué fallaba solo en Android.
   * ───────────────────────────────────────────────────────────────────────────
   *
   * Hasta ahora una notificación se cerraba **únicamente al tocarla**. Quien
   * abría la aplicación desde el icono —que es lo normal cuando ya se sabe que
   * hay algo— dejaba las notificaciones puestas en la bandeja del sistema para
   * siempre.
   *
   * En iOS eso no se nota: el número del icono lo pinta solo la Badging API, y
   * la aplicación ya lo ponía en cero al leer. **En Android el lanzador también
   * mira las notificaciones pendientes**, así que el icono seguía marcado aunque
   * `clearAppBadge()` hubiera hecho su trabajo. Dos fuentes decidiendo el mismo
   * número, y solo una se estaba apagando.
   *
   * De ahí la asimetría del reporte: «en Android el contador se queda como si
   * tuviera mensajes sin leer y dentro ya está todo leído; en iOS no pasa».
   *
   * La regla es la misma que rige toda la insignia: **lo que vale es el filtro
   * "Sin leer" de la bandeja**. Si un mensaje ya no está sin leer, su
   * notificación no tiene por qué seguir puesta.
   *
   * @param {Array<{data?: {mensajeId?: string}}>} mostradas lo que devuelve
   *        `registration.getNotifications()`.
   * @param {string[]|null|undefined} idsSinLeer los mensajes que la bandeja
   *        cuenta como sin leer. `null` significa «la aplicación no me lo dijo».
   * @param {number} cuenta el número exacto que mandó la aplicación.
   * @returns {Array} las notificaciones a cerrar.
   */
  function notificacionesACerrar(mostradas, idsSinLeer, cuenta) {
    const lista = Array.isArray(mostradas) ? mostradas : [];

    // Sin la lista de identificadores solo se puede decidir en el caso extremo,
    // que además es el que se reportó: cero sin leer, nada que anunciar.
    //
    // Se conserva este camino porque una versión vieja de la aplicación puede
    // seguir mandando solo el número, y entonces vale más cerrar de menos que
    // cerrar lo que todavía hace falta.
    if (!Array.isArray(idsSinLeer)) {
      return cuenta === 0 ? lista : [];
    }

    const sinLeer = new Set(idsSinLeer);
    return lista.filter((n) => {
      const id = n && n.data && n.data.mensajeId;
      // Lo que no es un mensaje no se toca. La notificación de prueba que
      // confirma el registro del dispositivo no lleva `mensajeId`, y cerrarla
      // por sorpresa sería quitarle a alguien la única señal de que su permiso
      // quedó bien.
      if (!id) {
        return false;
      }
      return !sinLeer.has(id);
    });
  }

  /**
   * ¿Cuánto vale la insignia después de anotar un mensaje?
   *
   * Devuelve `null` cuando el mensaje ya estaba anotado, que es la señal de «no
   * pintes nada»: el mismo aviso llega varias veces porque la entrega se
   * reintenta (RF-ENT-10) y porque un iPhone acumula varios tokens (riesgo
   * R-01). Contando llegadas en vez de mensajes, el icono decía «3» donde había
   * uno.
   *
   * @param {number} base el número exacto que fijó la aplicación la última vez.
   * @param {string[]} avisados los mensajes ya anotados desde entonces.
   * @param {string} mensajeId el que acaba de llegar.
   */
  function decidirCuenta(base, avisados, mensajeId) {
    const yaEstaban = Array.isArray(avisados) ? avisados : [];
    if (!mensajeId || yaEstaban.includes(mensajeId)) {
      return { cuenta: null, avisados: yaEstaban };
    }
    const nuevos = yaEstaban.concat([mensajeId]);
    return {
      cuenta: Math.max(0, Number(base) || 0) + nuevos.length,
      avisados: nuevos,
    };
  }

  /**
   * ¿Cuenta este `push` para la insignia?
   *
   * Solo los mensajes. La notificación de prueba que se manda al registrar un
   * dispositivo no corresponde a ningún aviso y por eso no lleva `mensajeId`:
   * se muestra —es la confirmación de que el permiso quedó bien— pero no suma.
   *
   * Contarla garantizaba que el icono y el filtro «Sin leer» discreparan, que
   * es justo el defecto contra el que se diseñó todo esto.
   */
  function esMensajeContable(mensajeId) {
    return typeof mensajeId === 'string' && mensajeId.length > 0;
  }

  /** El número que hay que pintar, normalizado. Nunca negativo, nunca `NaN`. */
  function normalizarCuenta(valor) {
    return Math.max(0, Number(valor) || 0);
  }

  /**
   * La etiqueta (`tag`) de una notificación: qué otras notificaciones reemplaza.
   *
   * Un aviso se etiqueta con su identificador, como siempre. Una respuesta
   * (DT-27) no lleva `mensajeId` —a propósito: no es un aviso sin leer de la
   * bandeja, y si lo llevara sumaría en la insignia—, así que trae su propia
   * `etiqueta`, una por aviso. Con ella, las respuestas a un mismo aviso se
   * reemplazan entre sí en vez de apilarse. Sin ninguna de las dos, `sian`.
   *
   * @param {{mensajeId?: string, etiqueta?: string}} datos la carga del push.
   */
  function etiquetaDeNotificacion(datos) {
    const d = datos || {};
    if (typeof d.mensajeId === 'string' && d.mensajeId.length > 0) {
      return d.mensajeId;
    }
    if (typeof d.etiqueta === 'string' && d.etiqueta.length > 0) {
      return d.etiqueta;
    }
    return 'sian';
  }

  const api = {
    notificacionesACerrar,
    decidirCuenta,
    esMensajeContable,
    normalizarCuenta,
    etiquetaDeNotificacion,
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  } else {
    global.SianDecisiones = api;
  }
})(typeof self !== 'undefined' ? self : globalThis);
