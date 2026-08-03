/**
 * Pruebas de la entidad Mensaje y su fábrica — RF-MSG-01 a RF-MSG-08, RF-MSG-12,
 * RF-USR-06, RN-06.
 */

import {
  MensajeFactory,
  exigeDobleConfirmacion,
  prioridadDeDespacho,
  type EntradaMensaje,
} from '../../src/domain/mensaje';
import { LIMITES } from '../../src/domain/tipos';
import { esperarCodigo } from './ayudas';

const ZONA = 'America/Guatemala';

function entrada(parcial: Partial<EntradaMensaje> = {}): EntradaMensaje {
  return {
    titulo: 'Simulacro de evacuación',
    cuerpo: 'Se realizará un simulacro a las 10:00. Diríjase al punto de reunión.',
    tipo: 'URGENTE',
    destinatarios: { modo: 'TODOS' },
    programacion: { modo: 'INMEDIATO', zonaHoraria: ZONA },
    creadoPor: 'uid-coordinador',
    creadoEn: new Date('2026-08-03T13:00:00.000Z'),
    ...parcial,
  };
}

/** Atajo: crear un mensaje a partir de una entrada parcial. */
function crear(parcial: Partial<EntradaMensaje> = {}) {
  return MensajeFactory.crear(entrada(parcial));
}

describe('Creación de un mensaje válido', () => {
  it('nace en BORRADOR, con formato TEXTO y sin exigir confirmación', () => {
    const m = crear();
    expect(m.estado).toBe('BORRADOR');
    expect(m.formato).toEqual(['TEXTO']);
    expect(m.requiereConfirmacion).toBe(false);
  });

  it('RF-MSG-12 · puede exigir confirmación de lectura', () => {
    expect(crear({ requiereConfirmacion: true }).requiereConfirmacion).toBe(true);
  });

  it('la entidad resultante es inmutable', () => {
    expect(Object.isFrozen(crear())).toBe(true);
  });

  it('RN-03 · puede referenciar el mensaje que corrige', () => {
    expect(crear({ referenciaCorreccion: 'msg-anterior' }).referenciaCorreccion).toBe('msg-anterior');
    expect(crear().referenciaCorreccion).toBeUndefined();
  });
});

describe('RF-MSG-05 · el formato se deduce de los adjuntos, no se declara', () => {
  const audio = { ruta: 'mensajes/x/a.webm', bytes: 300_000, duracionSeg: 25 };
  const imagen = { ruta: 'mensajes/x/i.png', bytes: 900_000, tipoMime: 'image/png' };

  it('texto + voz', () => {
    expect(crear({ adjuntos: { audio } }).formato).toEqual(['TEXTO', 'VOZ']);
  });

  it('texto + imagen', () => {
    expect(crear({ adjuntos: { imagen } }).formato).toEqual(['TEXTO', 'IMAGEN']);
  });

  it('los tres a la vez', () => {
    expect(crear({ adjuntos: { audio, imagen } }).formato).toEqual(['TEXTO', 'VOZ', 'IMAGEN']);
  });
});

describe('RF-MSG-07 · límites de la nota de voz', () => {
  it('admite justo 60 segundos y 2 MB', () => {
    expect(() =>
      crear({
        adjuntos: {
          audio: {
            ruta: 'mensajes/x/a.webm',
            bytes: LIMITES.AUDIO_MAX_BYTES,
            duracionSeg: LIMITES.AUDIO_MAX_SEGUNDOS,
          },
        },
      }),
    ).not.toThrow();
  });

  it('rechaza más de 60 segundos', () => {
    esperarCodigo(
      () => crear({ adjuntos: { audio: { ruta: 'a', bytes: 1000, duracionSeg: 61 } } }),
      'AUDIO_MUY_LARGO',
    );
  });

  it('rechaza más de 2 MB', () => {
    esperarCodigo(
      () =>
        crear({
          adjuntos: { audio: { ruta: 'a', bytes: LIMITES.AUDIO_MAX_BYTES + 1, duracionSeg: 10 } },
        }),
      'AUDIO_MUY_PESADO',
    );
  });

  it('rechaza un audio vacío', () => {
    esperarCodigo(
      () => crear({ adjuntos: { audio: { ruta: 'a', bytes: 0, duracionSeg: 5 } } }),
      'AUDIO_VACIO',
    );
  });

  it('rechaza un audio sin ruta de almacenamiento', () => {
    esperarCodigo(
      () => crear({ adjuntos: { audio: { ruta: '', bytes: 10, duracionSeg: 5 } } }),
      'AUDIO_SIN_RUTA',
    );
  });
});

describe('RF-MSG-08 · límites de la imagen', () => {
  it('admite JPEG, PNG y WebP', () => {
    for (const tipoMime of LIMITES.IMAGEN_MIMES) {
      expect(() => crear({ adjuntos: { imagen: { ruta: 'i', bytes: 1000, tipoMime } } })).not.toThrow();
    }
  });

  it('rechaza formatos no admitidos, como HEIC, GIF o PDF', () => {
    for (const tipoMime of ['image/heic', 'application/pdf', 'image/gif']) {
      esperarCodigo(
        () => crear({ adjuntos: { imagen: { ruta: 'i', bytes: 1000, tipoMime } } }),
        'IMAGEN_FORMATO_NO_ADMITIDO',
      );
    }
  });

  it('rechaza más de 5 MB', () => {
    esperarCodigo(
      () =>
        crear({
          adjuntos: {
            imagen: { ruta: 'i', bytes: LIMITES.IMAGEN_MAX_BYTES + 1, tipoMime: 'image/jpeg' },
          },
        }),
      'IMAGEN_MUY_PESADA',
    );
  });
});

describe('RF-USR-06 · coherencia de los destinatarios', () => {
  it('acepta los tres modos bien formados', () => {
    expect(() => crear({ destinatarios: { modo: 'TODOS' } })).not.toThrow();
    expect(() => crear({ destinatarios: { modo: 'GRUPOS', gruposIds: ['g1'] } })).not.toThrow();
    expect(() => crear({ destinatarios: { modo: 'INDIVIDUAL', usuariosIds: ['u1'] } })).not.toThrow();
  });

  it('rechaza GRUPOS sin grupos', () => {
    esperarCodigo(
      () => crear({ destinatarios: { modo: 'GRUPOS', gruposIds: [] } }),
      'DESTINATARIOS_SIN_GRUPOS',
    );
  });

  it('rechaza INDIVIDUAL sin usuarios', () => {
    esperarCodigo(
      () => crear({ destinatarios: { modo: 'INDIVIDUAL' } }),
      'DESTINATARIOS_SIN_USUARIOS',
    );
  });

  it('rechaza TODOS acompañado de listas: es una contradicción, no un matiz', () => {
    esperarCodigo(
      () => crear({ destinatarios: { modo: 'TODOS', gruposIds: ['g1'] } }),
      'DESTINATARIOS_INCOHERENTES',
    );
  });
});

describe('Coherencia de la programación', () => {
  it('exige zona horaria siempre (RN-05)', () => {
    esperarCodigo(
      () => crear({ programacion: { modo: 'INMEDIATO', zonaHoraria: '' } }),
      'ZONA_HORARIA_OBLIGATORIA',
    );
  });

  it('exige ejecutarEn en modo UNICO', () => {
    esperarCodigo(
      () => crear({ programacion: { modo: 'UNICO', zonaHoraria: ZONA } }),
      'EJECUTAR_EN_OBLIGATORIO',
    );
  });

  it('exige el patrón en modo RECURRENTE', () => {
    esperarCodigo(
      () => crear({ programacion: { modo: 'RECURRENTE', zonaHoraria: ZONA } }),
      'RECURRENCIA_OBLIGATORIA',
    );
  });

  it('rechaza un envío inmediato que además trae fecha de ejecución', () => {
    esperarCodigo(
      () =>
        crear({
          programacion: {
            modo: 'INMEDIATO',
            zonaHoraria: ZONA,
            ejecutarEn: '2026-08-15T14:00:00.000Z',
          },
        }),
      'PROGRAMACION_INCOHERENTE',
    );
  });
});

describe('Invariantes básicas', () => {
  it('RF-MSG-06 · aplica los límites de título y cuerpo', () => {
    esperarCodigo(() => crear({ titulo: 'a'.repeat(81) }), 'TITULO_MUY_LARGO');
    esperarCodigo(() => crear({ cuerpo: 'a'.repeat(501) }), 'CUERPO_MUY_LARGO');
  });

  it('RF-BIT-02 · exige saber quién creó el mensaje', () => {
    esperarCodigo(() => crear({ creadoPor: '' }), 'EMISOR_OBLIGATORIO');
  });

  it('RF-MSG-02 · exige una clasificación válida', () => {
    esperarCodigo(
      () => crear({ tipo: 'MEDIO_URGENTE' as unknown as 'URGENTE' }),
      'TIPO_MENSAJE_INVALIDO',
    );
  });
});

describe('RN-06 y prioridad de despacho', () => {
  it('solo la alerta urgente exige doble confirmación del emisor', () => {
    expect(exigeDobleConfirmacion('URGENTE')).toBe(true);
    expect(exigeDobleConfirmacion('INFORMATIVO')).toBe(false);
  });

  it('las urgentes salen primero del mismo lote de la cola', () => {
    expect(prioridadDeDespacho('URGENTE')).toBeGreaterThan(prioridadDeDespacho('INFORMATIVO'));
  });
});
