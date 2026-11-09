/**
 * Pruebas de las reglas de seguridad de Firestore (RNF-08).
 *
 * Requieren el emulador de Firestore corriendo. Se ejecutan con:
 *   firebase emulators:exec --only firestore "npm --prefix functions run test:rules"
 *
 * Se ejecutan en serie (--runInBand) porque comparten una única instancia
 * de emulador y se limpian entre pruebas.
 */
// El SDK de administración (prueba de membresías, 2.0.5) necesita saber el
// proyecto. En la CI el emulador se arranca sin --project y no lo hay; con un
// id «demo-» el SDK nunca intenta salir a un proyecto real.
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-sian';

module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/test/reglas'],
  testMatch: ['**/*.test.ts'],
  testTimeout: 20000,
};
