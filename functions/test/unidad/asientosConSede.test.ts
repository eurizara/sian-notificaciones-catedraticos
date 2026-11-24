/**
 * Todo asiento de la bitácora dice de qué sede es (2.0-f).
 *
 * Desde la 2.0.12 la bitácora se pide por sede (`where('sedeId', '==', …)`), y
 * desde la 2.0.13 las reglas lo exigen. Un asiento sin sede no aparece en la
 * de ninguna: el 23/11/2026 eran once (inicios de sesión, aparatos, lecturas,
 * respuestas, grupos, usuarios, invitaciones…). Esta prueba lee el código del
 * servidor y falla si alguna llamada a `crearAsiento` vuelve a olvidarla.
 */

import { readdirSync, readFileSync, statSync } from 'fs';
import { join } from 'path';

function archivos(dir: string): string[] {
  return readdirSync(dir).flatMap((n) => {
    const ruta = join(dir, n);
    return statSync(ruta).isDirectory() ? archivos(ruta) : ruta.endsWith('.ts') ? [ruta] : [];
  });
}

/** El texto de cada `crearAsiento({ … })`, con su archivo y línea. */
function llamadas(ruta: string): { donde: string; texto: string }[] {
  const s = readFileSync(ruta, 'utf8');
  const res: { donde: string; texto: string }[] = [];
  let i = s.indexOf('crearAsiento(');
  while (i !== -1) {
    let profundidad = 0;
    let j = i + 'crearAsiento'.length;
    for (; j < s.length; j++) {
      if (s[j] === '(') profundidad++;
      if (s[j] === ')' && --profundidad === 0) break;
    }
    res.push({ donde: `${ruta}:${s.slice(0, i).split('\n').length}`, texto: s.slice(i, j) });
    i = s.indexOf('crearAsiento(', j);
  }
  return res;
}

describe('2.0-f · cada asiento de la bitácora lleva su sede', () => {
  const todas = archivos(join(__dirname, '../../src'))
    // La definición, no una llamada.
    .filter((r) => !r.endsWith(join('domain', 'bitacora.ts')))
    .flatMap(llamadas);

  it('hay llamadas que revisar (si no, la prueba no prueba nada)', () => {
    expect(todas.length).toBeGreaterThan(15);
  });

  it('ninguna llamada a crearAsiento olvida sedeId', () => {
    expect(todas.filter((l) => !l.texto.includes('sedeId')).map((l) => l.donde)).toEqual([]);
  });
});
