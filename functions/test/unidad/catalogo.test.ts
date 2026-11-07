/**
 * Mantenimiento de catálogos — 2.0 · RF-CAT-01 a RF-CAT-05.
 *
 * Lo que se vigila: que no se repitan nombres que una persona leería como el
 * mismo, que el identificador no cambie nunca después del alta, y que nada se
 * borre: se desactiva.
 */

import { alcanceDe, puede } from '../../src/domain/autorizacion';
import { TIPOS_EVENTO } from '../../src/domain/bitacora';
import {
  claveDeNombre,
  decidirGuardado,
  idDesdeNombre,
  type ElementoCatalogo,
} from '../../src/domain/catalogo';
import { esperarCodigo } from './ayudas';

const CATALOGO: ElementoCatalogo[] = [
  { id: 'ing-sistemas', nombre: 'Ingeniería en Sistemas', activa: true },
  { id: 'derecho', nombre: 'Derecho', activa: false },
];

describe('nombres e identificadores', () => {
  it('compara sin tildes, mayúsculas ni espacios de más', () => {
    expect(claveDeNombre('  Ingeniería   en SISTEMAS ')).toBe('ingenieria en sistemas');
  });

  it('el identificador sale del nombre, con forma de identificador de sede', () => {
    expect(idDesdeNombre('Ingeniería en Sistemas')).toBe('ingenieria-en-sistemas');
    expect(idDesdeNombre('Ciencias Económicas y Empresariales de la Sede Central')).toHaveLength(32);
    expect(idDesdeNombre('¡¡¡')).toBe('');
  });
});

describe('decidirGuardado', () => {
  it('alta: identificador derivado, activa por omisión', () => {
    const d = decidirGuardado({ nombre: ' Medicina ' }, CATALOGO);
    expect(d).toEqual({
      elemento: { id: 'medicina', nombre: 'Medicina', activa: true },
      nuevo: true,
      cambios: ['alta'],
    });
  });

  it('RF-CAT-03: un nombre repetido se rechaza aunque cambien tildes o mayúsculas', () => {
    esperarCodigo(() => decidirGuardado({ nombre: 'INGENIERIA en sistemas' }, CATALOGO), 'NOMBRE_REPETIDO');
    // También contra uno desactivado: sigue existiendo.
    esperarCodigo(() => decidirGuardado({ nombre: 'derecho' }, CATALOGO), 'NOMBRE_REPETIDO');
  });

  it('el identificador no cambia al renombrar', () => {
    const d = decidirGuardado({ id: 'ing-sistemas', nombre: 'Ingeniería en Sistemas de Información' }, CATALOGO);
    expect(d.elemento.id).toBe('ing-sistemas');
    expect(d.nuevo).toBe(false);
    expect(d.cambios).toEqual(['nombre: «Ingeniería en Sistemas» → «Ingeniería en Sistemas de Información»']);
  });

  it('RF-CAT-02: desactivar y reactivar, sin borrar', () => {
    expect(decidirGuardado({ id: 'ing-sistemas', nombre: 'Ingeniería en Sistemas', activa: false }, CATALOGO).cambios).toEqual(['desactivado']);
    expect(decidirGuardado({ id: 'derecho', nombre: 'Derecho', activa: true }, CATALOGO).cambios).toEqual(['reactivado']);
  });

  it('sin cambios no hay nada que registrar', () => {
    expect(decidirGuardado({ id: 'derecho', nombre: 'Derecho' }, CATALOGO).cambios).toEqual([]);
  });

  it('editar algo que no existe se rechaza', () => {
    esperarCodigo(() => decidirGuardado({ id: 'quimica', nombre: 'Química' }, CATALOGO), 'ELEMENTO_INEXISTENTE');
  });

  it('nombres demasiado cortos, largos o sin letras', () => {
    esperarCodigo(() => decidirGuardado({ nombre: 'x' }, CATALOGO), 'NOMBRE_INVALIDO');
    esperarCodigo(() => decidirGuardado({ nombre: 'x'.repeat(81) }, CATALOGO), 'NOMBRE_INVALIDO');
    esperarCodigo(() => decidirGuardado({ nombre: '¡¡¡' }, CATALOGO), 'NOMBRE_INVALIDO');
    esperarCodigo(() => decidirGuardado({ nombre: 42 }, CATALOGO), 'NOMBRE_INVALIDO');
  });

  it('dos nombres distintos que darían el mismo identificador', () => {
    esperarCodigo(
      () => decidirGuardado({ nombre: 'Ing. Sistemas' }, [{ id: 'ing-sistemas', nombre: 'Ing Sistemas!', activa: true }]),
      'NOMBRE_REPETIDO',
    );
  });
});

describe('RF-CAT-05 · quién mantiene', () => {
  it('las facultades, solo la coordinación', () => {
    expect(alcanceDe('COORDINADOR', 'ADMINISTRAR_CATALOGOS')).toBe('TODO');
    for (const rol of ['ADMINISTRADORA', 'CATEDRATICO', 'AUDITOR'] as const) {
      expect(puede({ uid: 'u', rol, activo: true }, 'ADMINISTRAR_CATALOGOS')).toBe(false);
    }
    expect(puede({ uid: 'u', rol: 'COORDINADOR', activo: false }, 'ADMINISTRAR_CATALOGOS')).toBe(false);
  });

  it('RF-CAT-04 · el cambio tiene su tipo de asiento', () => {
    expect(TIPOS_EVENTO).toContain('CATALOGO_MODIFICADO');
  });
});
