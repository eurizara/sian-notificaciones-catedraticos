/**
 * Las llaves VAPID de la aplicación y del servidor tienen que ser la misma.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * La pública vive en DOS sitios, y separarlos deja a todo un ambiente mudo.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 *   · `deploy.yml` la compila dentro de la aplicación: con ella se SUSCRIBE
 *     cada aparato.
 *   · `vapid.ts` la usa el servidor para FIRMAR cada envío.
 *
 * Si no coinciden, el servicio de push rechaza todos los envíos de ese ambiente
 * (la firma no corresponde a la llave con que se suscribió el aparato). Y un
 * aparato suscrito con la llave propia no tiene token de FCM al que caer: no le
 * llega nada. Nada de eso falla al compilar ni al desplegar; falla al primer
 * aviso, en el teléfono de otra persona.
 *
 * Por la misma razón, un ambiente que compila la aplicación con llave propia
 * TIENE que tener la suya en el servidor.
 */

import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { clavePublicaDe } from '../../src/infrastructure/vapid';

/** Entorno de GitHub → proyecto de Firebase. */
const PROYECTOS: Record<string, string> = {
  desarrollo: 'sian-umg-bdm-dev',
  qa: 'sian-umg-bdm-qa',
  produccion: 'sian-umg-bdm',
};

/** La llave que cada trabajo de `deploy.yml` compila dentro de la aplicación. */
function llavesCompiladas(): Record<string, string> {
  const flujo = readFileSync(join(__dirname, '../../../.github/workflows/deploy.yml'), 'utf8');
  const llaves: Record<string, string> = {};

  // Cada trabajo empieza en su `environment:`; lo que sigue hasta el próximo es
  // suyo.
  const tramos = flujo.split(/^\s*environment:\s*/m).slice(1);
  for (const tramo of tramos) {
    const ambiente = tramo.split(/\s/)[0] ?? '';
    const llave = /--dart-define=SIAN_VAPID_PROPIA=([A-Za-z0-9_-]*)/.exec(tramo)?.[1] ?? '';
    llaves[ambiente] = llave;
  }
  return llaves;
}

describe('llaves VAPID propias', () => {
  const compiladas = llavesCompiladas();

  it('se leen los tres ambientes del despliegue', () => {
    // Si el flujo cambia de forma y esto deja de encontrarlos, la prueba de
    // abajo pasaría sin comprobar nada.
    expect(Object.keys(compiladas).sort()).toEqual(Object.keys(PROYECTOS).sort());
  });

  for (const [ambiente, proyecto] of Object.entries(PROYECTOS)) {
    it(`${ambiente}: la aplicación y el servidor usan la misma pública`, () => {
      const enLaApp = compiladas[ambiente] ?? '';
      const enElServidor = clavePublicaDe(proyecto);

      if (enLaApp === '') {
        // Sin llave en la aplicación, los aparatos siguen por FCM: el servidor
        // puede tenerla o no, no cambia nada.
        return;
      }
      expect(enElServidor).toBe(enLaApp);
    });
  }

  it('una pública tiene la forma de una llave P-256 sin comprimir', () => {
    // 65 bytes en base64url sin relleno = 87 caracteres, y empieza por «B»
    // (el byte 0x04 de punto sin comprimir). Pegarla con un espacio o cortada
    // no falla en ningún otro sitio antes del primer aviso.
    for (const proyecto of Object.values(PROYECTOS)) {
      const llave = clavePublicaDe(proyecto);
      if (llave === '') continue;
      expect(llave).toMatch(/^B[A-Za-z0-9_-]{86}$/);
    }
  });
});
