#!/usr/bin/env node
/**
 * SIAN — Comprueba que TODAS las Functions quedaron desplegadas.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * `firebase deploy` puede terminar en 0 habiendo fallado casi todo.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Al estrenar producción el 26 de agosto de 2026, dieciocho de diecinueve
 * funciones fallaron con un 409 —«Could not create bucket
 * gcf-v2-sources-…»—, una carrera que ocurre la primera vez que se despliega
 * en un proyecto nuevo: todas intentan crear a la vez el bucket donde se
 * guarda el código. El despliegue las dio por avisadas con un ⚠, salió con
 * código 0, el trabajo apareció en verde y el pipeline siguió a desplegar el
 * hosting. Producción quedó con la aplicación entera y un solo endpoint vivo.
 *
 * Un despliegue que se cae ruidosamente es un problema. Uno que se cae en
 * silencio y se declara exitoso es peor, porque nadie va a mirar.
 *
 * Este script compara lo que el código exporta contra lo que hay en la nube y
 * falla si falta algo. Se ejecuta después de desplegar.
 *
 *   node scripts/verificar-functions.js <salida-de-functions:list --json>
 */

const fs = require('fs');
const path = require('path');

const RAIZ = path.join(__dirname, '..');
const INDICE = path.join(RAIZ, 'functions', 'src', 'index.ts');

/**
 * Nombres que el código publica como Functions.
 *
 * Se leen del índice y no de una lista escrita a mano, que se quedaría vieja
 * la primera vez que alguien agregue una función y olvide actualizarla — que
 * es exactamente el olvido que este script existe para atrapar.
 *
 * `export * as dominio` queda fuera: es el dominio, que se exporta para las
 * pruebas y los scripts, no un endpoint.
 */
function esperadas() {
  const fuente = fs.readFileSync(INDICE, 'utf8');
  const nombres = new Set();

  for (const bloque of fuente.matchAll(/export\s*\{([^}]*)\}\s*from/g)) {
    for (const bruto of bloque[1].split(',')) {
      const nombre = bruto.trim().split(/\s+as\s+/).pop().trim();
      if (nombre) nombres.add(nombre);
    }
  }
  return [...nombres].sort();
}

/** Nombres que la nube dice tener. */
function desplegadas(rutaJson) {
  const crudo = JSON.parse(fs.readFileSync(rutaJson, 'utf8'));
  const lista = Array.isArray(crudo) ? crudo : (crudo.result ?? []);
  return lista
    .map((f) => f.id ?? f.functionName ?? (f.name ?? '').split('/').pop())
    .filter(Boolean)
    .sort();
}

function main() {
  const rutaJson = process.argv[2];
  if (!rutaJson) {
    console.error('Uso: node scripts/verificar-functions.js <archivo.json>');
    process.exit(2);
  }

  const quiero = esperadas();
  const hay = new Set(desplegadas(rutaJson));
  const faltan = quiero.filter((n) => !hay.has(n));

  console.log(`  el código publica ${quiero.length} funciones`);
  console.log(`  la nube tiene      ${hay.size}`);

  if (faltan.length === 0) {
    console.log('  ✔ están todas');
    return;
  }

  console.error(`\n  FALTAN ${faltan.length}:`);
  for (const n of faltan) console.error(`    · ${n}`);
  console.error(
    '\n  Un despliegue puede terminar en 0 habiendo fallado funciones sueltas.\n' +
      '  Si es la primera vez que se despliega en este proyecto, casi seguro es\n' +
      '  la carrera del bucket gcf-v2-sources: vuelve a desplegar y se resuelve,\n' +
      '  porque el bucket ya quedó creado.',
  );
  process.exit(1);
}

main();
