/**
 * Mantenimiento que nadie mira hasta que falla: dependencias y llaves (S-8, S-9).
 *
 * Dependabot estuvo configurado desde la iteración 1.1 y, a 26/09/2026, no
 * había abierto ni un pull request. Su silencio se parecía demasiado a «no hay
 * nada que actualizar». Estas pruebas vigilan que el reemplazo siga en su
 * sitio, y que el procedimiento para rotar las llaves VAPID no desaparezca de
 * la documentación el día que haga falta.
 */

import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const raiz = join(__dirname, '../../..');
const leer = (ruta: string) => readFileSync(join(raiz, ruta), 'utf8');

describe('actualización mensual de dependencias (S-8)', () => {
  const flujo = leer('.github/workflows/actualizar-dependencias.yml');

  it('corre el día 1 de cada mes, y se puede lanzar a mano', () => {
    expect(flujo).toMatch(/cron: '0 13 1 \* \*'/);
    expect(flujo).toMatch(/^\s+workflow_dispatch:/m);
  });

  it('sale de develop y propone contra develop: nunca toca qa ni main', () => {
    expect(flujo).toMatch(/ref: develop/);
    expect(flujo).toMatch(/--base develop/);
    expect(flujo).not.toMatch(/--base (qa|main)/);
  });

  it('solo sube dentro de los rangos: nada de mayores automáticas', () => {
    expect(flujo).toMatch(/npm update/);
    expect(flujo).toMatch(/flutter pub upgrade\s*$/m);
    expect(flujo).not.toMatch(/--major-versions|npm install [^\n]*@latest|ncu -u/);
  });

  it('solo confirma archivos de bloqueo', () => {
    const agregados = flujo.match(/git add ([^\n]+)/)![1]!.split(/\s+/);
    expect(agregados.sort()).toEqual(
      ['app/pubspec.lock', 'functions/package-lock.json', 'package-lock.json'].sort(),
    );
  });

  it('lanza la integración continua, que tiene que aceptar el lanzamiento a mano', () => {
    // Lo que se empuja con el token de un flujo no dispara otros flujos: sin
    // esto el pull request esperaría unos checks que nunca llegan.
    expect(flujo).toMatch(/gh workflow run ci\.yml --ref "\$rama"/);
    expect(leer('.github/workflows/ci.yml')).toMatch(/^\s+workflow_dispatch:/m);
  });

  it('Dependabot ya no lleva npm ni pub: dos mecanismos darían PR duplicados', () => {
    const dependabot = leer('.github/dependabot.yml');
    expect(dependabot).not.toMatch(/package-ecosystem: (npm|pub)/);
    expect(dependabot).toMatch(/package-ecosystem: github-actions/);
  });
});

describe('procedimiento para rotar las llaves VAPID (S-9)', () => {
  const doc = leer('docs/11-ambientes.md');

  it('está escrito, con los pasos que no se pueden saltar', () => {
    const i = doc.indexOf('**Rotar las llaves VAPID');
    expect(i).toBeGreaterThan(-1);
    const seccion = doc.slice(i, i + 6000);
    // La privada nunca pasa por el repositorio ni por nadie más.
    expect(seccion).toMatch(/Nueva versión/);
    // Cada aparato se vuelve a suscribir al abrir SIAN: sin eso no recibe.
    expect(seccion).toMatch(/abr[ae] SIAN/);
    // La versión vieja se destruye al final, no al principio.
    expect(seccion).toMatch(/Destruir/);
  });
});
