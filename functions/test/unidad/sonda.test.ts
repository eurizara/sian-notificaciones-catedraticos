/**
 * Pruebas de la sonda de canal — DT-22, DT-18.
 *
 * Lo que se decide aquí es a quién se le retira un dispositivo y a quién hay que
 * ir a buscar. Las dos cosas pueden dejar a alguien sin recibir avisos si se
 * equivocan, así que cada regla tiene su caso escrito.
 */

import { recibeAvisos } from '../../src/domain/autorizacion';
import { resolverDestinatarios } from '../../src/application/resolverDestinatarios';
import type { Rol } from '../../src/domain/tipos';
import {
  DIAS_PARA_RETIRO_POR_INACTIVIDAD,
  decidirSobreDispositivo,
  estadoDeCanal,
  GRAVEDAD_DE_CANAL,
  type DispositivoAEvaluar,
  type DispositivoDeCanal,
} from '../../src/domain/dispositivo';

const AHORA = new Date('2026-09-09T12:00:00Z');
const haceDias = (n: number) => new Date(AHORA.getTime() - n * 86_400_000);

const dispositivo = (ultimaActividad: Date | null): DispositivoAEvaluar => ({
  uid: 'u1',
  id: 'ins_abc',
  tokenFCM: 'token-suficientemente-largo-para-ser-plausible',
  ultimaActividad,
});

describe('decidirSobreDispositivo', () => {
  it('retira lo que FCM rechaza, por reciente que sea', () => {
    // Un token muerto no sirve aunque se haya registrado hace un minuto.
    expect(decidirSobreDispositivo(dispositivo(AHORA), false, AHORA)).toBe(
      'retirar-por-muerto',
    );
  });

  it('conserva lo vivo y con actividad reciente', () => {
    expect(decidirSobreDispositivo(dispositivo(haceDias(3)), true, AHORA)).toBe('conservar');
  });

  it('retira lo vivo pero abandonado hace más de sesenta días', () => {
    expect(decidirSobreDispositivo(dispositivo(haceDias(61)), true, AHORA)).toBe(
      'retirar-por-inactivo',
    );
  });

  it('en el umbral exacto todavía NO retira', () => {
    // Se retira pasados los sesenta, no al cumplirlos. Es la diferencia entre
    // «lleva dos meses sin abrirla» y «hoy hace dos meses».
    expect(
      decidirSobreDispositivo(dispositivo(haceDias(DIAS_PARA_RETIRO_POR_INACTIVIDAD)), true, AHORA),
    ).toBe('conservar');
  });

  it('SIN fecha de actividad no retira nada', () => {
    // Un campo que falta es una incógnita, no una prueba de abandono. Borrar
    // por una incógnita es lo que dejó a gente sin avisos en agosto de 2026.
    expect(decidirSobreDispositivo(dispositivo(null), true, AHORA)).toBe('conservar');
  });

  it('sin fecha pero muerto sí se retira: manda FCM', () => {
    expect(decidirSobreDispositivo(dispositivo(null), false, AHORA)).toBe('retirar-por-muerto');
  });
});

describe('estadoDeCanal', () => {
  const disp = (
    esPWAInstalada: boolean,
    permisoNotificacion: string,
    ultimaActividad: Date | null = AHORA,
    tokenVivo?: boolean,
  ): DispositivoDeCanal => ({
    esPWAInstalada,
    permisoNotificacion,
    ultimaActividad,
    tokenVivo,
  });

  it('sin dispositivos, no puede recibir nada', () => {
    expect(estadoDeCanal([], AHORA)).toBe('sin-dispositivo');
  });

  it('instalada y con permiso, está al día', () => {
    expect(estadoDeCanal([disp(true, 'concedido')], AHORA)).toBe('al-dia');
  });

  it('solo en pestaña: recibe al abrir, pero no le suena nada', () => {
    expect(estadoDeCanal([disp(false, 'concedido')], AHORA)).toBe('solo-en-pestana');
  });

  it('distingue el permiso denegado de la pestaña', () => {
    // Lo que hay que pedirle a la persona es distinto: instalar la aplicación,
    // o volver a conceder el permiso. Un solo estado para las dos cosas haría
    // que coordinación pidiera lo que no era.
    expect(estadoDeCanal([disp(false, 'denegado')], AHORA)).toBe('permiso-denegado');
  });

  it('el último envío fallido manda sobre todo lo demás', () => {
    // ────────────────────────────────────────────────────────────────────────
    // La validación en seco tiene un punto ciego, y este es el remedio.
    // ────────────────────────────────────────────────────────────────────────
    //
    // FCM acepta el token y `validate_only` dice «vivo», pero nunca toca el
    // servicio de push de Apple, que es donde muere de verdad un registro de
    // Safari. El 10 de septiembre de 2026 la pantalla daba por bien a un iPhone
    // al que ningún aviso llegaba, tres envíos seguidos.
    //
    // Las demás señales comprueban CONDICIONES; esta mira el HECHO.
    expect(
      estadoDeCanal([disp(true, 'concedido', haceDias(3), true)], AHORA, 30, haceDias(1)),
    ).toBe('ultimo-envio-fallo');
  });

  it('sin envíos fallidos recientes, el resto de señales decide', () => {
    expect(
      estadoDeCanal([disp(true, 'concedido', AHORA, true)], AHORA, 30, null),
    ).toBe('al-dia');
  });

  it('sin dispositivos, eso pesa más que el envío fallido', () => {
    // Quien no tiene dónde recibir necesita registrar un aparato, no
    // reengancharlo. Decirle lo segundo sería pedirle algo imposible.
    expect(estadoDeCanal([], AHORA, 30, haceDias(1))).toBe('sin-dispositivo');
  });

  it('si se reenganchó DESPUÉS del fallo, deja de contarse como fallo', () => {
    // ────────────────────────────────────────────────────────────────────────
    // La pregunta que lo destapó: «si Alfredo lo arregla, ¿desaparece?».
    // ────────────────────────────────────────────────────────────────────────
    //
    // Antes no: las entregas solo se escriben al mandar un aviso, así que su
    // último envío seguía siendo el fallido y la pantalla lo señalaba hasta el
    // próximo mensaje. Coordinación le pedía algo, la persona lo hacía, y el
    // panel no cambiaba.
    //
    // Un aviso que no se apaga cuando se resuelve el problema enseña a ignorar
    // la pantalla.
    expect(
      estadoDeCanal(
        [disp(true, 'concedido', haceDias(1), true)],
        AHORA,
        30,
        haceDias(3),
      ),
    ).toBe('reenganchado-sin-comprobar');
  });

  it('reenganchado NO es «al día», y la diferencia importa', () => {
    // «Al día» ya se dijo una vez de este mismo caso y era mentira: el
    // documento se veía impecable y ningún aviso llegaba. Lo honesto es decir
    // que se reenganchó Y que no se sabe si funcionó hasta el próximo envío.
    const reenganchado = estadoDeCanal(
      [disp(true, 'concedido', haceDias(1), true)],
      AHORA,
      30,
      haceDias(3),
    );
    expect(reenganchado).not.toBe('al-dia');
    expect(reenganchado).not.toBe('ultimo-envio-fallo');
  });

  it('reenganchado pero en pestaña: manda el problema real', () => {
    // Volver a entrar no arregla no tener la aplicación instalada. Si hay algo
    // comprobable que sigue mal, eso es lo que hay que decir.
    expect(
      estadoDeCanal(
        [disp(false, 'concedido', haceDias(1), true)],
        AHORA,
        30,
        haceDias(3),
      ),
    ).toBe('solo-en-pestana');
  });

  it('sin actividad posterior al fallo, sigue siendo fallo', () => {
    expect(
      estadoDeCanal(
        [disp(true, 'concedido', haceDias(5), true)],
        AHORA,
        30,
        haceDias(2),
      ),
    ).toBe('ultimo-envio-fallo');
  });

  it('un token muerto no se salva por verse bien el documento', () => {
    // ────────────────────────────────────────────────────────────────────────
    // El caso que engañó a la pantalla el 10 de septiembre de 2026.
    // ────────────────────────────────────────────────────────────────────────
    //
    // Un coordinador con un iPhone instalado, permiso concedido y actividad de
    // hace doce días no recibió el aviso. Su documento era impecable; el token
    // que llevaba dentro estaba muerto, y desde Firestore eso es invisible.
    expect(
      estadoDeCanal([disp(true, 'concedido', haceDias(12), false)], AHORA),
    ).toBe('token-muerto');
  });

  it('si NO se preguntó a FCM, no se penaliza', () => {
    // `undefined` es «no se comprobó», no «está muerto». Suponer lo segundo
    // mandaría a coordinación a buscar a gente que está perfectamente bien.
    expect(estadoDeCanal([disp(true, 'concedido', AHORA, undefined)], AHORA)).toBe('al-dia');
  });

  it('con dos aparatos, basta que UNO tenga el token vivo', () => {
    expect(
      estadoDeCanal(
        [disp(true, 'concedido', AHORA, false), disp(true, 'concedido', AHORA, true)],
        AHORA,
      ),
    ).toBe('al-dia');
  });

  it('el token muerto pesa más que la pestaña', () => {
    // Quien solo tiene un aparato y encima con el token muerto no recibe nada.
    // Decir «solo en pestaña» sería pedirle que instale algo que ya tiene.
    expect(estadoDeCanal([disp(false, 'concedido', AHORA, false)], AHORA)).toBe('token-muerto');
  });

  it('un aparato bueno basta, aunque haya otros malos', () => {
    // Quien tiene el teléfono instalado y además la aplicación abierta en una
    // pestaña del escritorio RECIBE. Marcarlo como problema sería mandar a
    // coordinación a buscar a alguien que está bien.
    expect(
      estadoDeCanal([disp(false, 'concedido'), disp(true, 'concedido')], AHORA),
    ).toBe('al-dia');
  });

  it('avisa cuando el único aparato bueno lleva un mes sin actividad', () => {
    // Es el caso del 7 de septiembre de 2026: cinco personas que habían
    // confirmado el aviso anterior perdieron el canal en ocho días de silencio,
    // y nadie lo supo hasta que falló un aviso real.
    expect(estadoDeCanal([disp(true, 'concedido', haceDias(31))], AHORA)).toBe(
      'sin-actividad-reciente',
    );
  });

  it('el umbral de aviso es configurable y no retira nada', () => {
    expect(estadoDeCanal([disp(true, 'concedido', haceDias(10))], AHORA, 7)).toBe(
      'sin-actividad-reciente',
    );
    expect(estadoDeCanal([disp(true, 'concedido', haceDias(10))], AHORA, 30)).toBe('al-dia');
  });

  it('sin fecha de actividad se da por al día', () => {
    expect(estadoDeCanal([disp(true, 'concedido', null)], AHORA)).toBe('al-dia');
  });
});

describe('GRAVEDAD_DE_CANAL', () => {
  it('ordena primero a quien no puede recibir nada', () => {
    const orden = ([
      'al-dia',
      'solo-en-pestana',
      'token-muerto',
      'ultimo-envio-fallo',
      'reenganchado-sin-comprobar',
      'sin-dispositivo',
    ] as const)
      .slice()
      .sort((a, b) => GRAVEDAD_DE_CANAL[a] - GRAVEDAD_DE_CANAL[b]);
    expect(orden[0]).toBe('sin-dispositivo');
    expect(orden[orden.length - 1]).toBe('al-dia');
  });

  it('«al día» es siempre el último, para que no estorbe la lista', () => {
    const valores = Object.entries(GRAVEDAD_DE_CANAL);
    const alDia = GRAVEDAD_DE_CANAL['al-dia'];
    for (const [estado, peso] of valores) {
      if (estado !== 'al-dia') {
        expect(peso).toBeLessThan(alDia);
      }
    }
  });
});

describe('la población del Alcance es la misma que la del envío', () => {
  // ──────────────────────────────────────────────────────────────────────────
  // Esta prueba existe porque las dos poblaciones YA se separaron una vez.
  // ──────────────────────────────────────────────────────────────────────────
  //
  // El 9 de septiembre de 2026, en desarrollo, la pantalla de Alcance decía
  // «los 4 catedráticos pueden recibir avisos» y un envío a todos salió a
  // siete, con dos fallos. La causa: el Alcance filtraba por
  // `rol === 'CATEDRATICO'` mientras el envío usaba `recibeAvisos`, que es una
  // bandera por persona con el rol como valor por omisión.
  //
  // Una pantalla que predice quién no va a recibir y calcula sobre otra
  // población no se equivoca a veces: miente siempre, y de la peor forma,
  // diciendo que todo está bien.

  const persona = (uid: string, rol: Rol, bandera?: boolean) => ({
    uid,
    activo: true,
    rol,
    recibeAvisos: bandera,
  });

  const padron = [
    persona('cat1', 'CATEDRATICO'),
    persona('cat2', 'CATEDRATICO'),
    // Un coordinador que además da clases, con la bandera encendida: ES
    // destinatario aunque su rol no sea CATEDRATICO. Es el caso exacto que
    // falló.
    persona('coord-que-recibe', 'COORDINADOR', true),
    // Y uno que no la tiene: no recibe, y tampoco debe aparecer en el Alcance.
    persona('coord-normal', 'COORDINADOR'),
    persona('auditor', 'AUDITOR'),
    // Un catedrático al que el coordinador le apagó la bandera.
    persona('cat-apagado', 'CATEDRATICO', false),
  ];

  it('el predicado de la audiencia y el del Alcance son EL MISMO', () => {
    const segunEnvio = resolverDestinatarios(
      { modo: 'TODOS', gruposIds: [], usuariosIds: [] },
      padron,
      [],
      null,
    ).uids;

    const segunAlcance = padron
      .filter((u) => u.activo && recibeAvisos(u.rol, u.recibeAvisos))
      .map((u) => u.uid);

    expect([...segunAlcance].sort()).toEqual([...segunEnvio].sort());
  });

  it('el coordinador con la bandera encendida entra en las dos', () => {
    expect(recibeAvisos('COORDINADOR', true)).toBe(true);

    // Y el filtro que había antes lo dejaba fuera. Se escribe como lo escribía
    // la versión defectuosa para que se vea la diferencia: el rol dice una cosa
    // y la bandera dice otra, y la que manda es la bandera.
    const filtrarPorRol = (rol: Rol) => rol === 'CATEDRATICO';
    expect(filtrarPorRol('COORDINADOR')).toBe(false);
    expect(recibeAvisos('COORDINADOR', true)).toBe(true);
  });

  it('el catedrático con la bandera apagada queda fuera de las dos', () => {
    expect(recibeAvisos('CATEDRATICO', false)).toBe(false);
  });
});
