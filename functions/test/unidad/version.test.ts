/**
 * Versiones de la aplicación: compararlas bien y resumirlas por persona.
 *
 * El 13 de septiembre de 2026 salió 1.5.10, y dos sitios que elegían «la más
 * reciente» ordenando como texto se quedaron con 1.5.9. Nada falla cuando eso
 * pasa: la pantalla simplemente dice otra cosa de lo que corre cada aparato.
 */

import {
  compararVersiones,
  resumirVersiones,
  versionMasAlta,
} from '../../src/domain/version';

describe('compararVersiones', () => {
  it('1.5.10 es posterior a 1.5.9: por número, no por texto', () => {
    expect(compararVersiones('1.5.10', '1.5.9')).toBeGreaterThan(0);
    expect(compararVersiones('1.5.9', '1.5.10')).toBeLessThan(0);
    // Como cadena salía al revés, que es el fallo que motivó esto.
    expect(['1.5.9', '1.5.10'].sort()).toEqual(['1.5.10', '1.5.9']);
  });

  it('compara tramo a tramo', () => {
    expect(compararVersiones('2.0.0', '1.99.99')).toBeGreaterThan(0);
    expect(compararVersiones('1.10.0', '1.9.9')).toBeGreaterThan(0);
    expect(compararVersiones('1.5.10', '1.5.10')).toBe(0);
  });

  it('lo que no es una versión va antes que cualquier versión', () => {
    for (const basura of ['', 'vieja', '1.5', '1.5.x', ' ']) {
      expect(compararVersiones(basura, '0.0.1')).toBeLessThan(0);
      expect(compararVersiones('0.0.1', basura)).toBeGreaterThan(0);
    }
  });
});

describe('versionMasAlta', () => {
  it('elige por número', () => {
    expect(versionMasAlta(['1.5.9', '1.5.10', '1.5.2'])).toBe('1.5.10');
  });

  it('ignora vacíos y basura; sin ninguna válida, vacío', () => {
    expect(versionMasAlta(['', '1.5.8', 'vieja'])).toBe('1.5.8');
    expect(versionMasAlta(['', '  '])).toBe('');
    expect(versionMasAlta([])).toBe('');
  });

  it('tolera espacios alrededor', () => {
    expect(versionMasAlta([' 1.5.10 ', '1.5.9'])).toBe('1.5.10');
  });
});

describe('resumirVersiones', () => {
  const personas = [
    { uid: 'b', nombre: 'Zoila', correo: 'z@umg' },
    { uid: 'a', nombre: 'Ana', correo: 'a@umg' },
    { uid: 'c', nombre: 'Sin aparato', correo: 'c@umg' },
  ];
  const hace = new Date('2026-09-13T20:00:00Z');

  it('va por aparato: el teléfono al día y la computadora atrasada se ven por separado', () => {
    const r = resumirVersiones(personas, [
      { uid: 'a', plataforma: 'WEB_ANDROID', navegador: 'Chrome', versionApp: '1.5.10', ultimaActividad: hace },
      { uid: 'a', plataforma: 'WEB_ESCRITORIO', navegador: 'Chrome', versionApp: '1.5.4', ultimaActividad: null },
    ]);
    expect(r).toHaveLength(1);
    expect(r[0]!.aparatos).toEqual([
      { id: '', plataforma: 'WEB_ANDROID', navegador: 'Chrome', versionApp: '1.5.10', ultimaActividad: hace.toISOString() },
      { id: '', plataforma: 'WEB_ESCRITORIO', navegador: 'Chrome', versionApp: '1.5.4', ultimaActividad: null },
    ]);
  });

  it('quien no tiene aparatos no aparece: eso lo dice la lista de canal', () => {
    const r = resumirVersiones(personas, [
      { uid: 'b', plataforma: 'WEB_IOS', navegador: 'Safari', versionApp: '1.5.9', ultimaActividad: hace },
    ]);
    expect(r.map((p) => p.uid)).toEqual(['b']);
  });

  it('aparatos de alguien que no es destinatario no se cuelan', () => {
    const r = resumirVersiones(personas, [
      { uid: 'x', plataforma: 'WEB_IOS', navegador: 'Safari', versionApp: '1.0.0', ultimaActividad: hace },
    ]);
    expect(r).toEqual([]);
  });

  it('ordenado por nombre, y la versión vacía se conserva como vacía', () => {
    const r = resumirVersiones(personas, [
      { uid: 'b', plataforma: 'WEB_IOS', navegador: 'Safari', versionApp: ' ', ultimaActividad: hace },
      { uid: 'a', plataforma: 'WEB_IOS', navegador: 'Safari', versionApp: '1.5.10', ultimaActividad: hace },
    ]);
    expect(r.map((p) => p.nombre)).toEqual(['Ana', 'Zoila']);
    expect(r[1]!.aparatos[0]!.versionApp).toBe('');
  });
});
