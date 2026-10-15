/**
 * La forma de la integración continua: cuatro controles en paralelo y un
 * resumen que los espera (`needs`). Se usa en las demostraciones de la
 * cátedra, así que se vigila que no cambie sin querer.
 */

import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const ci = readFileSync(join(__dirname, '../../../.github/workflows/ci.yml'), 'utf8');

function bloqueDe(trabajo: string): string {
  const inicio = ci.indexOf(`\n  ${trabajo}:\n`);
  expect(inicio).toBeGreaterThan(-1);
  const siguiente = ci.slice(inicio + 1).search(/\n {2}[a-z_-]+:\n/);
  return siguiente === -1 ? ci.slice(inicio) : ci.slice(inicio, inicio + 1 + siguiente);
}

describe('integración continua', () => {
  it('los cuatro controles no esperan a nadie: corren en paralelo', () => {
    for (const trabajo of ['functions', 'reglas', 'secretos', 'flutter']) {
      expect(bloqueDe(trabajo)).not.toMatch(/\n {4}needs:/);
    }
  });

  it('el resumen espera a los cuatro', () => {
    expect(bloqueDe('resumen')).toMatch(/needs: \[functions, reglas, secretos, flutter\]/);
  });

  it('todos corren en Linux (ubuntu-latest)', () => {
    const maquinas = [...ci.matchAll(/runs-on: (\S+)/g)].map((m) => m[1]);
    expect(maquinas).toHaveLength(5);
    expect(new Set(maquinas)).toEqual(new Set(['ubuntu-latest']));
  });
});
