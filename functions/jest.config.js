/**
 * Pruebas unitarias del dominio y de la capa de aplicación.
 * No tocan red, ni emulador, ni nube (documento 02, sección 8).
 *
 * El umbral de cobertura es el de RNF-15: 70% en dominio y aplicación.
 */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/test/unidad'],
  testMatch: ['**/*.test.ts'],
  collectCoverageFrom: [
    'src/domain/**/*.ts',
    'src/application/**/*.ts',
    '!src/**/index.ts',
  ],
  coverageThreshold: {
    global: {
      branches: 70,
      functions: 70,
      lines: 70,
      statements: 70,
    },
  },
  coverageDirectory: 'coverage',
};
