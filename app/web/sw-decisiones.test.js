/**
 * Pruebas de las decisiones del service worker — DT-17 y DT-26.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Son las primeras pruebas automáticas que tiene esta parte del sistema.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Hasta ahora el worker se probaba con un teléfono en la mano. Salieron de ahí
 * siete defectos de notificación en agosto de 2026, y el contador del icono
 * falló dos veces. Cada caso que falló alguna vez tiene abajo su prueba, con el
 * porqué al lado: son las que impiden que vuelva por tercera vez.
 *
 * Corren con el ejecutor de Node, sin instalar nada:
 *
 *     npm run test:sw
 */

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');

const {
  notificacionesACerrar,
  decidirCuenta,
  esMensajeContable,
  normalizarCuenta,
  etiquetaDeNotificacion,
  direccionDeAcuse,
  cuerpoDeAcuse,
} = require('./sw-decisiones.js');

/** Una notificación como las que devuelve `getNotifications()`. */
const notificacion = (mensajeId) => ({ data: mensajeId ? { mensajeId } : {} });

describe('notificacionesACerrar — DT-26', () => {
  test('con todo leído, cierra todas', () => {
    // El caso reportado: el icono de Android seguía marcado con la bandeja
    // vacía, porque el lanzador cuenta las notificaciones puestas y nadie las
    // retiraba.
    const mostradas = [notificacion('m1'), notificacion('m2')];
    assert.equal(notificacionesACerrar(mostradas, [], 0).length, 2);
  });

  test('cierra solo las de los mensajes ya leídos', () => {
    // Tres notificaciones, se leyeron dos. El icono tiene que decir uno, no
    // tres, y para eso hay que retirar exactamente dos.
    const mostradas = [
      notificacion('m1'),
      notificacion('m2'),
      notificacion('m3'),
    ];
    const aCerrar = notificacionesACerrar(mostradas, ['m2'], 1);
    assert.deepEqual(
      aCerrar.map((n) => n.data.mensajeId),
      ['m1', 'm3'],
    );
  });

  test('no cierra las que siguen sin leer', () => {
    const mostradas = [notificacion('m1')];
    assert.deepEqual(notificacionesACerrar(mostradas, ['m1'], 1), []);
  });

  test('NUNCA cierra la notificación de prueba del registro', () => {
    // No lleva `mensajeId` porque no es un aviso: es la confirmación de que el
    // permiso quedó bien. Cerrarla por sorpresa le quitaría a alguien la única
    // señal de que su dispositivo se registró.
    const mostradas = [notificacion(null), notificacion('m1')];
    const aCerrar = notificacionesACerrar(mostradas, [], 0);
    assert.equal(aCerrar.length, 1);
    assert.equal(aCerrar[0].data.mensajeId, 'm1');
  });

  test('sin la lista de identificadores solo actúa con cero sin leer', () => {
    // Una pestaña abierta de un despliegue anterior manda solo el número. Vale
    // más cerrar de menos que cerrar lo que todavía hace falta.
    const mostradas = [notificacion('m1'), notificacion('m2')];
    assert.equal(notificacionesACerrar(mostradas, undefined, 0).length, 2);
    assert.equal(notificacionesACerrar(mostradas, undefined, 2).length, 0);
    assert.equal(notificacionesACerrar(mostradas, null, 1).length, 0);
  });

  test('aguanta que no haya nada mostrado, que es lo normal en iOS', () => {
    // `getNotifications()` devuelve vacío en iOS para las que muestra el propio
    // worker. Que esto no haga nada es exactamente lo que se busca: allí ya
    // funcionaba y no hay que tocarlo.
    assert.deepEqual(notificacionesACerrar([], ['m1'], 1), []);
    assert.deepEqual(notificacionesACerrar(undefined, [], 0), []);
    assert.deepEqual(notificacionesACerrar(null, [], 0), []);
  });
});

describe('decidirCuenta', () => {
  test('suma uno por mensaje nuevo sobre la base', () => {
    const r = decidirCuenta(2, [], 'm1');
    assert.equal(r.cuenta, 3);
    assert.deepEqual(r.avisados, ['m1']);
  });

  test('el mismo mensaje repetido NO vuelve a sumar', () => {
    // La entrega se reintenta hasta tres veces (RF-ENT-10) y un iPhone acumula
    // varios tokens (riesgo R-01): en producción se midieron cuatro del mismo
    // aparato. Contando llegadas, el icono decía «3» donde había uno.
    const r = decidirCuenta(0, ['m1'], 'm1');
    assert.equal(r.cuenta, null, 'null significa «no pintes nada»');
    assert.deepEqual(r.avisados, ['m1']);
  });

  test('cuatro llegadas del mismo aviso dejan la cuenta en uno', () => {
    let estado = { cuenta: null, avisados: [] };
    for (let i = 0; i < 4; i += 1) {
      const r = decidirCuenta(0, estado.avisados, 'm1');
      estado = { cuenta: r.cuenta ?? estado.cuenta, avisados: r.avisados };
    }
    assert.equal(estado.cuenta, 1);
  });

  test('sin identificador no suma', () => {
    assert.equal(decidirCuenta(0, [], '').cuenta, null);
    assert.equal(decidirCuenta(0, [], undefined).cuenta, null);
  });

  test('una base rara no produce cuentas raras', () => {
    assert.equal(decidirCuenta(-5, [], 'm1').cuenta, 1);
    assert.equal(decidirCuenta(NaN, [], 'm1').cuenta, 1);
    assert.equal(decidirCuenta(undefined, [], 'm1').cuenta, 1);
  });
});

describe('esMensajeContable', () => {
  test('un identificador de mensaje cuenta', () => {
    assert.equal(esMensajeContable('m1'), true);
  });

  test('la notificación de registro NO cuenta', () => {
    // Se vio en producción el 26 de agosto de 2026: activar las notificaciones
    // sumó uno, el primer aviso real sumó otro, y el icono decía «2» con la
    // bandeja diciendo «Sin leer (1)».
    assert.equal(esMensajeContable(undefined), false);
    assert.equal(esMensajeContable(null), false);
    assert.equal(esMensajeContable(''), false);
  });
});

describe('normalizarCuenta', () => {
  test('nunca devuelve negativo ni NaN', () => {
    assert.equal(normalizarCuenta(-3), 0);
    assert.equal(normalizarCuenta('siete'), 0);
    assert.equal(normalizarCuenta(undefined), 0);
    assert.equal(normalizarCuenta(4), 4);
    assert.equal(normalizarCuenta('4'), 4);
  });
});

describe('etiquetaDeNotificacion — DT-27', () => {
  test('un aviso se etiqueta con su identificador, como siempre', () => {
    assert.equal(etiquetaDeNotificacion({ mensajeId: 'm-1' }), 'm-1');
  });

  test('una respuesta usa su etiqueta, una por aviso', () => {
    // Así las respuestas a un mismo aviso se reemplazan en vez de apilarse.
    assert.equal(
      etiquetaDeNotificacion({ tipo: 'RESPUESTA', etiqueta: 'respuestas-m-1' }),
      'respuestas-m-1',
    );
  });

  test('una respuesta NO cuenta para la insignia', () => {
    // Por eso no lleva mensajeId: no es un aviso sin leer de la bandeja.
    assert.equal(esMensajeContable(undefined), false);
  });

  test('sin nada, la etiqueta genérica', () => {
    assert.equal(etiquetaDeNotificacion({}), 'sian');
    assert.equal(etiquetaDeNotificacion(undefined), 'sian');
  });
});

describe('el acuse de que se mostró — DT-31', () => {
  test('la dirección sale del proyecto, así que apunta a su propio ambiente', () => {
    // El worker de desarrollo no puede acusar en producción.
    assert.equal(
      direccionDeAcuse({ projectId: 'sian-umg-bdm-dev' }),
      'https://us-central1-sian-umg-bdm-dev.cloudfunctions.net/acuseDeNotificacion',
    );
  });

  test('sin configuración no se inventa una dirección', () => {
    assert.equal(direccionDeAcuse(undefined), null);
    assert.equal(direccionDeAcuse({}), null);
    assert.equal(direccionDeAcuse({ projectId: 'SIN-CONFIGURAR' }), null);
  });

  test('se acusa lo que trae seña', () => {
    assert.deepEqual(cuerpoDeAcuse({ mensajeId: 'm-1', ac: 'oc-1|uid-1|abcd1234abcd1234' }), {
      mensajeId: 'm-1',
      ac: 'oc-1|uid-1|abcd1234abcd1234',
    });
  });

  test('lo que no la trae, NO se acusa', () => {
    // Los avisos anteriores a DT-31 y la notificación de prueba del registro:
    // de esas no hay entrega que anotar.
    assert.equal(cuerpoDeAcuse({ mensajeId: 'm-1' }), null);
    assert.equal(cuerpoDeAcuse({ ac: 'oc-1|uid-1|abcd1234abcd1234' }), null);
    assert.equal(cuerpoDeAcuse({}), null);
    assert.equal(cuerpoDeAcuse(undefined), null);
  });
});
