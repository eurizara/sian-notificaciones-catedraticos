/**
 * Demostración 1 · prueba de UNIDAD.
 *
 * El 13/09/2026 SIAN ordenó versiones como texto y «1.5.10» quedó antes que
 * «1.5.9». Esta prueba reproduce ese error en pequeño.
 */
import { ordenarVersiones } from './ordenarVersiones';

describe('Demostración 1 · ordenar versiones', () => {
  it('1.5.10 va después de 1.5.9', () => {
    expect(ordenarVersiones(['1.5.10', '1.5.9', '1.6.0'])).toEqual(['1.5.9', '1.5.10', '1.6.0']);
  });
});
