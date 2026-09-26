/**
 * App Check (DT-33): primero se observa, después se exige.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Por qué hay una sola llave
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Los registros de producción dicen `"app": "MISSING"` en cada llamada: la
 * sesión se verifica, pero no que la llamada salga de la aplicación. Exigir
 * App Check antes de que **todas** las llamadas legítimas lo traigan —incluido
 * el iPhone instalado— dejaría fuera a catedráticos reales sin aviso.
 *
 * Por eso todas las funciones llamables comparten `OPCIONES_LLAMABLE`, y la
 * decisión de exigirlo es una sola constante. Esta prueba vigila las dos cosas:
 * que ninguna función se salte las opciones comunes (y quede fuera cuando se
 * exija), y que nadie lo exija por accidente mientras se observa.
 *
 * Las dos rutas HTTP que llama el service worker (`acuse` y la renovación de
 * la suscripción) quedan fuera a propósito: el worker no tiene cómo obtener un
 * token de App Check, y cada una valida lo suyo.
 */

import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

import { EXIGIR_APP_CHECK, OPCIONES_LLAMABLE } from '../../src/infrastructure/firebase';

const disparadores = join(__dirname, '../../src/triggers');

function llamables(): { archivo: string; opciones: string }[] {
  const hallados: { archivo: string; opciones: string }[] = [];
  for (const archivo of readdirSync(disparadores).filter((a) => a.endsWith('.ts'))) {
    const fuente = readFileSync(join(disparadores, archivo), 'utf8');
    for (const m of fuente.matchAll(/\bonCall\(\s*([^,]+),/g)) {
      hallados.push({ archivo, opciones: m[1]!.trim() });
    }
  }
  return hallados;
}

describe('App Check en modo observación (DT-33)', () => {
  it('todas las funciones llamables usan las opciones comunes', () => {
    const todas = llamables();
    expect(todas.length).toBeGreaterThanOrEqual(20);
    const sueltas = todas.filter((l) => l.opciones !== 'OPCIONES_LLAMABLE');
    expect(sueltas).toEqual([]);
  });

  it('todavía no se exige: se observa hasta que todas las llamadas legítimas lo traigan', () => {
    // Para exigirlo: ver documento 11, «App Check», y cambiar solo esta constante.
    expect(EXIGIR_APP_CHECK).toBe(false);
    expect(OPCIONES_LLAMABLE.enforceAppCheck).toBe(EXIGIR_APP_CHECK);
  });

  it('las opciones comunes conservan región y tope de instancias', () => {
    expect(OPCIONES_LLAMABLE.region).toBe('us-central1');
    expect(OPCIONES_LLAMABLE.maxInstances).toBe(10);
  });
});
