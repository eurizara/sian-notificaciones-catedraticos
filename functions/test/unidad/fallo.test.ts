/**
 * Los fallos que ocurren en el aparato — DT-34.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Existe porque el peor fallo del proyecto no dejó rastro en el servidor.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * El 12 de septiembre de 2026 el registro de dispositivos se colgó en todos los
 * aparatos y el servidor no registró un solo error: se supo porque un aviso de
 * prueba no llegó. Lo que se prueba aquí es qué se acepta (nada personal, nada
 * que no esté en la lista), cuánto se escribe (con tope) y cómo se resume para
 * Alcance.
 */

import {
  DOCUMENTOS_POR_DIA,
  LARGO_DE_DETALLE,
  SEGUNDOS_ENTRE_REPORTES,
  decidirEscritura,
  idDeFallo,
  leerReporte,
  limpiarDetalle,
  resumirFallos,
} from '../../src/domain/fallo';

const bueno = {
  que: 'registro-dispositivo',
  version: '1.6.10',
  plataforma: 'WEB_IOS',
  aparato: 'a1B2c3D4e5F6g7H8',
  detalle: 'TimeoutException after 0:00:12',
};

describe('leerReporte', () => {
  it('acepta un reporte bien formado', () => {
    expect(leerReporte(bueno)).toEqual(bueno);
  });

  it('solo los tipos de la lista: lo demás se descarta', () => {
    expect(leerReporte({ ...bueno, que: 'lo-que-sea' })).toBeNull();
    expect(leerReporte({ ...bueno, que: undefined })).toBeNull();
  });

  it('la plataforma desconocida pasa como OTRA, no se descarta el fallo', () => {
    expect(leerReporte({ ...bueno, plataforma: 'NINTENDO' })?.plataforma).toBe('OTRA');
  });

  it('una versión sin forma de versión queda vacía', () => {
    expect(leerReporte({ ...bueno, version: '<script>' })?.version).toBe('');
  });

  it('el identificador del aparato tiene que ser uno de los que genera la app', () => {
    for (const aparato of ['', 'corto', 'a/b/c/d/e/f/g/h', 'x'.repeat(65), 42]) {
      expect(leerReporte({ ...bueno, aparato })).toBeNull();
    }
  });

  it('lo que no es un objeto se descarta', () => {
    for (const cuerpo of [null, undefined, 'texto', 3, []]) {
      expect(leerReporte(cuerpo)).toBeNull();
    }
  });

  it('el detalle es opcional y se limpia', () => {
    expect(leerReporte({ ...bueno, detalle: undefined })?.detalle).toBe('');
    expect(leerReporte({ ...bueno, detalle: 'falló ana@umg.edu.gt' })?.detalle).toBe(
      'falló [correo]',
    );
  });
});

describe('limpiarDetalle: nada personal sale del aparato', () => {
  it('quita correos', () => {
    expect(limpiarDetalle('user-not-found: ana.perez@miumg.edu.gt')).toBe(
      'user-not-found: [correo]',
    );
  });

  it('quita números largos: teléfonos, carnés', () => {
    expect(limpiarDetalle('carné 0905-21-12345 tel 5555 1234')).toBe(
      'carné [número] tel [número]',
    );
    // Lo corto se queda: una duración o una versión no identifican a nadie.
    expect(limpiarDetalle('after 0:00:12 en 1.6.10, código 404')).toBe(
      'after 0:00:12 en 1.6.10, código 404',
    );
  });

  it('quita claves y tokens: cadenas largas sin espacios', () => {
    expect(limpiarDetalle('token dKx9_aZ3-QwErTyUiOpAsDfGhJkL1234 inválido')).toBe(
      'token [clave] inválido',
    );
  });

  it('de una dirección solo queda el sitio: la consulta puede llevar datos', () => {
    expect(
      limpiarDetalle('fetch https://fcm.googleapis.com/fcm/send/abc?auth=xyz falló'),
    ).toBe('fetch https://fcm.googleapis.com/… falló');
  });

  it('se recorta, y los espacios se juntan', () => {
    const largo = limpiarDetalle(`a  b\n\nc ${'palabra '.repeat(100)}`);
    expect(largo.startsWith('a b c palabra')).toBe(true);
    expect(largo.length).toBeLessThanOrEqual(LARGO_DE_DETALLE);
    expect(largo.endsWith('…')).toBe(true);
  });

  it('lo que no es texto queda vacío', () => {
    expect(limpiarDetalle(undefined)).toBe('');
    expect(limpiarDetalle({ a: 1 })).toBe('');
  });
});

describe('idDeFallo', () => {
  it('uno por aparato, tipo y día (UTC): el mismo fallo repetido suma en el mismo documento', () => {
    const r = leerReporte(bueno)!;
    expect(idDeFallo(r, new Date('2026-09-26T05:59:00Z'))).toBe(
      '20260926_a1B2c3D4e5F6g7H8_registro-dispositivo',
    );
  });
});

describe('decidirEscritura: con tope, para que nadie llene la base', () => {
  const ahora = new Date('2026-09-26T12:00:00Z');

  it('el primero del día se crea', () => {
    expect(decidirEscritura(null, 0, ahora)).toBe('nuevo');
  });

  it('el mismo fallo, pasado el intervalo, suma', () => {
    const antes = new Date(ahora.getTime() - (SEGUNDOS_ENTRE_REPORTES + 1) * 1000);
    expect(decidirEscritura({ ultimo: antes }, 3, ahora)).toBe('sumar');
  });

  it('el mismo fallo dentro del intervalo no escribe nada', () => {
    const antes = new Date(ahora.getTime() - 5_000);
    expect(decidirEscritura({ ultimo: antes }, 3, ahora)).toBe('ignorar');
  });

  it('llegado el tope del día, no se crean más; los existentes sí suman', () => {
    expect(decidirEscritura(null, DOCUMENTOS_POR_DIA, ahora)).toBe('ignorar');
    const antes = new Date(ahora.getTime() - 120_000);
    expect(decidirEscritura({ ultimo: antes }, DOCUMENTOS_POR_DIA, ahora)).toBe('sumar');
  });
});

describe('resumirFallos: lo que ve Alcance', () => {
  const ahora = new Date('2026-09-26T12:00:00Z');
  const hace = (horas: number) => new Date(ahora.getTime() - horas * 3_600_000);
  const fila = (
    aparato: string,
    que: string,
    horas: number,
    extra: Partial<{ veces: number; plataforma: string; version: string; detalle: string }> = {},
  ) => ({
    aparato,
    que,
    ultimo: hace(horas),
    veces: extra.veces ?? 1,
    plataforma: extra.plataforma ?? 'WEB_IOS',
    version: extra.version ?? '1.6.10',
    detalle: extra.detalle ?? '',
  });

  it('solo las últimas 24 horas, contando aparatos distintos', () => {
    const r = resumirFallos(
      [
        fila('A', 'worker', 1, { veces: 3 }),
        fila('A', 'registro-dispositivo', 2),
        fila('B', 'worker', 23),
        fila('C', 'worker', 25),
      ],
      ahora,
    );
    expect(r.aparatos).toBe(2);
    expect(r.reportes).toBe(5);
  });

  it('por tipo, de más aparatos a menos, con plataformas y versiones sin repetir', () => {
    const r = resumirFallos(
      [
        fila('A', 'registro-dispositivo', 1, { detalle: 'viejo' }),
        fila('B', 'worker', 1, { plataforma: 'WEB_ANDROID', version: '1.6.9' }),
        fila('C', 'worker', 2),
        fila('D', 'worker', 3, { plataforma: 'WEB_ANDROID', version: '1.6.9' }),
      ],
      ahora,
    );
    expect(r.porTipo.map((t) => [t.que, t.aparatos])).toEqual([
      ['worker', 3],
      ['registro-dispositivo', 1],
    ]);
    expect(r.porTipo[0]!.plataformas).toEqual(['WEB_ANDROID', 'WEB_IOS']);
    expect(r.porTipo[0]!.versiones).toEqual(['1.6.9', '1.6.10']);
    expect(r.porTipo[1]!.ultimoDetalle).toBe('viejo');
  });

  it('sin fallos, ceros y lista vacía', () => {
    expect(resumirFallos([], ahora)).toEqual({ aparatos: 0, reportes: 0, porTipo: [] });
  });
});
