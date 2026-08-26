/**
 * Pruebas de las reglas de seguridad de Firestore (RNF-08).
 *
 * Requieren el emulador de Firestore corriendo. Se ejecutan con:
 *   firebase emulators:exec --only firestore "npm --prefix functions run test:rules"
 *
 * Se ejecutan en serie (--runInBand) porque comparten una única instancia
 * de emulador y se limpian entre pruebas.
 */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/test/reglas'],
  testMatch: ['**/*.test.ts'],
  testTimeout: 20000,
};
