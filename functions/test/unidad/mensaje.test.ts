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
import { LIMITES, type Adjunto } from '../../src/domain/tipos';
import type { ErrorDominio } from '../../src/domain/errores';
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
      'ADJUNTO_VACIO',
    );
  });

  it('rechaza un audio sin ruta de almacenamiento', () => {
    esperarCodigo(
      () => crear({ adjuntos: { audio: { ruta: '', bytes: 10, duracionSeg: 5 } } }),
      'ADJUNTO_SIN_RUTA',
    );
  });
});

// ---------------------------------------------------------------------------
// RF-MSG-05 · VARIOS ADJUNTOS, Y EN EL ORDEN DEL EMISOR.
// ---------------------------------------------------------------------------
//
// El orden lo elige quien redacta y significa algo: un plano, después la nota
// de voz que lo explica, después la foto del punto de reunión. Guardarlo como
// «los audios» y «las imágenes» por separado obligaría a reconstruir ese orden
// al mostrarlo, y no hay forma de reconstruir lo que no se guardó.
describe('RF-MSG-05 · varios adjuntos', () => {
  const voz = (n: number): Adjunto => ({
    tipo: 'AUDIO',
    ruta: `mensajes/x/${n}-voz.webm`,
    bytes: 300_000,
    tipoMime: 'audio/webm',
    duracionSeg: 20,
  });
  const img = (n: number): Adjunto => ({
    tipo: 'IMAGEN',
    ruta: `mensajes/x/${n}-imagen.png`,
    bytes: 900_000,
    tipoMime: 'image/png',
  });

  it('conserva el orden en que se adjuntaron, mezclando tipos', () => {
    const lista = [img(1), voz(2), img(3)];
    const m = crear({ adjuntos: { lista } });

    expect(m.adjuntos.lista?.map((a) => a.ruta)).toEqual([
      'mensajes/x/1-imagen.png',
      'mensajes/x/2-voz.webm',
      'mensajes/x/3-imagen.png',
    ]);
  });

  it('el formato dice QUÉ hay, no cuántos', () => {
    expect(crear({ adjuntos: { lista: [img(1), img(2)] } }).formato).toEqual(['TEXTO', 'IMAGEN']);
    expect(crear({ adjuntos: { lista: [voz(1), img(2)] } }).formato).toEqual([
      'TEXTO',
      'VOZ',
      'IMAGEN',
    ]);
  });

  it('admite el máximo de cada tipo y rechaza uno más', () => {
    expect(() => crear({ adjuntos: { lista: [img(1), img(2), img(3)] } })).not.toThrow();
    esperarCodigo(
      () => crear({ adjuntos: { lista: [img(1), img(2), img(3), img(4)] } }),
      'DEMASIADAS_IMAGENES',
    );

    expect(() => crear({ adjuntos: { lista: [voz(1), voz(2)] } })).not.toThrow();
    esperarCodigo(
      () => crear({ adjuntos: { lista: [voz(1), voz(2), voz(3)] } }),
      'DEMASIADAS_NOTAS_DE_VOZ',
    );
  });

  it('rechaza el conjunto demasiado pesado aunque cada pieza quepa', () => {
    // Tres imágenes de 4 MB pasan una a una y suman 12: en una conexión mala
    // eso no es un aviso, es contenido que no llega.
    const pesada = (n: number): Adjunto => ({ ...img(n), bytes: 4 * 1024 * 1024 });
    esperarCodigo(
      () => crear({ adjuntos: { lista: [pesada(1), pesada(2), pesada(3)] } }),
      'ADJUNTOS_MUY_PESADOS',
    );
  });

  it('dice en qué posición está el adjunto que falla', () => {
    // Con cinco adjuntos, «la imagen está vacía» no dice cuál, y el emisor
    // tiene que adivinar cuál quitar.
    let lanzado: unknown;
    try {
      crear({ adjuntos: { lista: [img(1), { ...img(2), bytes: 0 }] } });
    } catch (e) {
      lanzado = e;
    }
    expect((lanzado as ErrorDominio).detalle).toMatchObject({ posicion: 2 });
  });
});

// ---------------------------------------------------------------------------
// LOS MENSAJES YA ENVIADOS NO SE REESCRIBEN (RN-03).
// ---------------------------------------------------------------------------
//
// Dejar de entender la forma antigua borraría los adjuntos de todo lo
// entregado hasta hoy: seguirían en Storage, pero nadie sabría que existen.
describe('RF-MSG-05 · la forma antigua se sigue leyendo', () => {
  it('un {audio, imagen} de antes se traduce a la lista, con la voz primero', () => {
    const m = crear({
      adjuntos: {
        audio: { ruta: 'mensajes/y/voz.webm', bytes: 1000, duracionSeg: 9 },
        imagen: { ruta: 'mensajes/y/imagen.png', bytes: 2000, tipoMime: 'image/png' },
      },
    });

    expect(m.formato).toEqual(['TEXTO', 'VOZ', 'IMAGEN']);
    expect(m.adjuntos.lista).toEqual([
      {
        tipo: 'AUDIO',
        ruta: 'mensajes/y/voz.webm',
        bytes: 1000,
        tipoMime: 'audio/webm',
        duracionSeg: 9,
      },
      { tipo: 'IMAGEN', ruta: 'mensajes/y/imagen.png', bytes: 2000, tipoMime: 'image/png' },
    ]);
  });

  it('lo que se GUARDA es siempre la forma nueva', () => {
    // Que convivan dos maneras de escribir lo mismo garantiza que tarde o
    // temprano una de las dos deje de leerse en algún sitio.
    const m = crear({ adjuntos: { imagen: { ruta: 'i', bytes: 10, tipoMime: 'image/png' } } });
    expect(m.adjuntos.audio).toBeUndefined();
    expect(m.adjuntos.imagen).toBeUndefined();
    expect(m.adjuntos.lista).toHaveLength(1);
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
