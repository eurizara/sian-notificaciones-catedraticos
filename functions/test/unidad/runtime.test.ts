/**
 * El runtime de las funciones: el mismo en todas partes, y lejos de su retiro.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Por qué existe (DT-32, 23/09/2026)
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Las funciones corrían en Node.js 20, que Google declaró obsoleto el
 * 30/04/2026 y retira el 30/10/2026. Desde el retiro no se pueden crear ni
 * actualizar funciones con ese runtime: cualquier corrección habría quedado
 * bloqueada. Nadie lo notó hasta cinco semanas antes, revisando otra cosa.
 *
 * Esta prueba es la alarma que faltó. Falla **90 días antes** del retiro, con
 * tiempo para cambiar de runtime con calma y probarlo en desarrollo y QA.
 *
 * Cuando falle: mirar el calendario en
 * https://docs.cloud.google.com/functions/docs/runtime-support, pasar al
 * siguiente runtime en `firebase.json` y en los dos flujos de GitHub, y
 * añadir su fecha aquí.
 */

import { readFileSync } from 'node:fs';
import { join } from 'node:path';

/** Fecha de retiro de cada runtime, según el calendario oficial de Google. */
const RETIRO: Record<string, string> = {
  nodejs20: '2026-10-30',
  nodejs22: '2027-10-31',
  nodejs24: '2028-10-31',
};

const DIAS_DE_AVISO = 90;

const raiz = join(__dirname, '../../..');
const leer = (ruta: string) => readFileSync(join(raiz, ruta), 'utf8');

function runtimeDeFunciones(): string {
  const config = JSON.parse(leer('firebase.json')) as {
    functions: { runtime?: string }[] | { runtime?: string };
  };
  const funciones = Array.isArray(config.functions) ? config.functions : [config.functions];
  const runtimes = [...new Set(funciones.map((f) => f.runtime ?? ''))];
  expect(runtimes).toHaveLength(1);
  return runtimes[0]!;
}

describe('runtime de las funciones', () => {
  it('es uno que conocemos, con fecha de retiro anotada', () => {
    expect(Object.keys(RETIRO)).toContain(runtimeDeFunciones());
  });

  it(`faltan más de ${DIAS_DE_AVISO} días para que Google lo retire`, () => {
    const runtime = runtimeDeFunciones();
    const retiro = new Date(`${RETIRO[runtime]}T00:00:00Z`);
    const dias = (retiro.getTime() - Date.now()) / 86_400_000;
    expect({ runtime, diasHastaElRetiro: Math.floor(dias) }).toEqual({
      runtime,
      diasHastaElRetiro: expect.any(Number),
    });
    if (dias <= DIAS_DE_AVISO) {
      throw new Error(
        `${runtime} se retira el ${RETIRO[runtime]} (quedan ${Math.floor(dias)} días). ` +
          'Pasar al siguiente runtime: ver el comentario al inicio de este archivo.',
      );
    }
  });

  it('la CI y el despliegue prueban y compilan con esa misma versión de Node', () => {
    // Probar en una versión y desplegar en otra es como no haber probado.
    const mayor = runtimeDeFunciones().replace('nodejs', '');
    for (const flujo of ['.github/workflows/ci.yml', '.github/workflows/deploy.yml']) {
      const versiones = [...leer(flujo).matchAll(/node-version:\s*'(\d+)'/g)].map((m) => m[1]);
      expect(versiones.length).toBeGreaterThan(0);
      for (const v of versiones) {
        expect({ flujo, v }).toEqual({ flujo, v: mayor });
      }
    }
  });

  it('los tipos de Node corresponden a esa versión', () => {
    const mayor = runtimeDeFunciones().replace('nodejs', '');
    const paquete = JSON.parse(leer('functions/package.json')) as {
      devDependencies: Record<string, string>;
    };
    expect(paquete.devDependencies['@types/node']).toMatch(new RegExp(`^\\^?${mayor}\\.`));
  });
});
