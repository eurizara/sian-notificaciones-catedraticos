/**
 * Responder a un aviso — DT-27, mejora M-5.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Lo que más importa probar es quién NO puede escribir.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Una conversación entre dos personas atada a un aviso deja de serlo en cuanto
 * un tercero puede meterse, o en cuanto el emisor puede abrir conversaciones
 * con quien no le escribió: eso ya sería una mensajería general.
 */

import { ErrorAutorizacion } from '../../src/domain/errores';
import {
  LARGO_MAXIMO_RESPUESTA,
  MINUTOS_ENTRE_AVISOS_AL_EMISOR,
  avisoAlCatedratico,
  avisoAlEmisor,
  debeAvisarAlEmisor,
  decidirLado,
  normalizarRespuesta,
  vistaPrevia,
} from '../../src/domain/respuesta';
import { esperarCodigo } from './ayudas';

const EMISOR = 'uid-coordinador';
const CATEDRATICO = 'uid-catedratico';
const OTRO = 'uid-otro';

describe('normalizarRespuesta', () => {
  it('recorta los extremos y conserva los saltos de dentro', () => {
    expect(normalizarRespuesta('  No puedo asistir.\nLlego a las 10.  ')).toBe(
      'No puedo asistir.\nLlego a las 10.',
    );
  });

  it('una respuesta vacía o solo de espacios no se guarda', () => {
    esperarCodigo(() => normalizarRespuesta(''), 'RESPUESTA_VACIA');
    esperarCodigo(() => normalizarRespuesta('   \n  '), 'RESPUESTA_VACIA');
    esperarCodigo(() => normalizarRespuesta(undefined), 'RESPUESTA_VACIA');
    esperarCodigo(() => normalizarRespuesta(42), 'RESPUESTA_VACIA');
  });

  it('tiene un largo máximo, justo en el límite pasa', () => {
    expect(normalizarRespuesta('a'.repeat(LARGO_MAXIMO_RESPUESTA))).toHaveLength(
      LARGO_MAXIMO_RESPUESTA,
    );
    esperarCodigo(
      () => normalizarRespuesta('a'.repeat(LARGO_MAXIMO_RESPUESTA + 1)),
      'RESPUESTA_DEMASIADO_LARGA',
    );
  });
});

describe('decidirLado · el destinatario', () => {
  it('escribe en su propio hilo, aunque todavía no exista', () => {
    expect(
      decidirLado({ uid: CATEDRATICO, creadoPor: EMISOR, esDestinatario: true, hiloExiste: false }),
    ).toEqual({ lado: 'CATEDRATICO', hiloUid: CATEDRATICO });
  });

  it('pedir su propio hilo por nombre es lo mismo', () => {
    expect(
      decidirLado({
        uid: CATEDRATICO,
        creadoPor: EMISOR,
        esDestinatario: true,
        hiloPedido: CATEDRATICO,
        hiloExiste: true,
      }),
    ).toEqual({ lado: 'CATEDRATICO', hiloUid: CATEDRATICO });
  });

  it('NO puede escribir en el hilo de otro destinatario', () => {
    esperarCodigo(
      () =>
        decidirLado({
          uid: CATEDRATICO,
          creadoPor: EMISOR,
          esDestinatario: true,
          hiloPedido: OTRO,
          hiloExiste: true,
        }),
      'HILO_AJENO',
    );
  });

  it('quien no recibió el aviso NO puede responderlo', () => {
    esperarCodigo(
      () =>
        decidirLado({ uid: OTRO, creadoPor: EMISOR, esDestinatario: false, hiloExiste: false }),
      'NO_ES_DESTINATARIO',
    );
  });

  it('los rechazos de acceso son de autorización, no de validación', () => {
    // El servidor los traduce distinto: «no puedes» y «está mal escrito» no
    // se responden igual.
    expect(() =>
      decidirLado({ uid: OTRO, creadoPor: EMISOR, esDestinatario: false, hiloExiste: false }),
    ).toThrow(ErrorAutorizacion);
  });
});

describe('decidirLado · quien emitió el aviso', () => {
  it('contesta en el hilo de un destinatario que ya escribió', () => {
    expect(
      decidirLado({
        uid: EMISOR,
        creadoPor: EMISOR,
        esDestinatario: false,
        hiloPedido: CATEDRATICO,
        hiloExiste: true,
      }),
    ).toEqual({ lado: 'EMISOR', hiloUid: CATEDRATICO });
  });

  it('NO puede abrir una conversación con quien no escribió', () => {
    // Es la diferencia entre responder y una mensajería general.
    esperarCodigo(
      () =>
        decidirLado({
          uid: EMISOR,
          creadoPor: EMISOR,
          esDestinatario: false,
          hiloPedido: CATEDRATICO,
          hiloExiste: false,
        }),
      'HILO_INEXISTENTE',
    );
  });

  it('no puede responderse a sí mismo, aunque esté entre los destinatarios', () => {
    // Quien emite a toda la sede y también recibe avisos está en la lista.
    esperarCodigo(
      () =>
        decidirLado({ uid: EMISOR, creadoPor: EMISOR, esDestinatario: true, hiloExiste: false }),
      'RESPUESTA_A_UNO_MISMO',
    );
  });

  it('otro coordinador que no emitió el aviso NO entra en el hilo', () => {
    // Coordinación puede leer todos los avisos, pero la conversación es de
    // quien emitió y de quien respondió.
    esperarCodigo(
      () =>
        decidirLado({
          uid: 'uid-otro-coordinador',
          creadoPor: EMISOR,
          esDestinatario: false,
          hiloPedido: CATEDRATICO,
          hiloExiste: true,
        }),
      'HILO_AJENO',
    );
  });
});

describe('debeAvisarAlEmisor · veintidós respuestas no son veintidós notificaciones', () => {
  const ahora = new Date('2026-09-11T15:00:00Z');
  const haceMinutos = (m: number) => new Date(ahora.getTime() - m * 60000);

  it('la primera respuesta avisa en el acto', () => {
    expect(debeAvisarAlEmisor(null, ahora)).toBe(true);
  });

  it('las que llegan poco después se pliegan', () => {
    expect(debeAvisarAlEmisor(haceMinutos(1), ahora)).toBe(false);
    expect(debeAvisarAlEmisor(haceMinutos(MINUTOS_ENTRE_AVISOS_AL_EMISOR - 1), ahora)).toBe(false);
  });

  it('pasado el intervalo, vuelve a avisar', () => {
    expect(debeAvisarAlEmisor(haceMinutos(MINUTOS_ENTRE_AVISOS_AL_EMISOR), ahora)).toBe(true);
    expect(debeAvisarAlEmisor(haceMinutos(90), ahora)).toBe(true);
  });
});

describe('lo que dicen las notificaciones', () => {
  it('con una respuesta: quién y qué', () => {
    const n = avisoAlEmisor({
      nombre: 'Ana López',
      tituloAviso: 'Reunión del viernes',
      texto: 'No puedo asistir.',
      sinLeer: 1,
    });
    expect(n.titulo).toBe('Respuesta de Ana López');
    expect(n.cuerpo).toBe('A «Reunión del viernes»: No puedo asistir.');
  });

  it('con varias: cuántas, y NO el texto de la última', () => {
    // El texto de la última engañaría: parecería que es la única.
    const n = avisoAlEmisor({
      nombre: 'Ana López',
      tituloAviso: 'Reunión del viernes',
      texto: 'No puedo asistir.',
      sinLeer: 5,
    });
    expect(n.titulo).toBe('5 respuestas sin leer');
    expect(n.cuerpo).not.toContain('No puedo asistir');
    expect(n.cuerpo).toContain('Ana López');
  });

  it('al catedrático le dice quién le respondió y sobre qué', () => {
    const n = avisoAlCatedratico({
      nombreEmisor: 'Coordinación',
      tituloAviso: 'Reunión',
      texto: 'Gracias por avisar.',
    });
    expect(n.titulo).toBe('Coordinación te respondió');
    expect(n.cuerpo).toBe('Sobre «Reunión»: Gracias por avisar.');
  });
});

describe('vistaPrevia', () => {
  it('lo corto pasa entero, con los saltos convertidos en espacios', () => {
    expect(vistaPrevia('Hola\n\nmundo')).toBe('Hola mundo');
  });

  it('lo largo se corta en una palabra y lleva puntos suspensivos', () => {
    const texto = 'palabra '.repeat(40);
    const vista = vistaPrevia(texto, 30);
    expect(vista.endsWith('…')).toBe(true);
    expect(vista.length).toBeLessThanOrEqual(31);
    expect(vista).not.toMatch(/pala…$/);
  });
});
