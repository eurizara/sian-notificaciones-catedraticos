/**
 * Ayudas compartidas por las pruebas unitarias.
 *
 * Las pruebas se atan al **código** del error, no a su redacción. El texto de
 * un mensaje puede reescribirse mañana sin que cambie nada del contrato; el
 * código es lo que consumen la bitácora (RF-BIT-02) y la interfaz para decidir
 * qué mostrar.
 */

import { ErrorDominio } from '../../src/domain/errores';

/** Verifica que `fn` lanza un ErrorDominio con exactamente ese código. */
export function esperarCodigo(fn: () => unknown, codigo: string): void {
  let lanzado: unknown;
  try {
    fn();
  } catch (e) {
    lanzado = e;
  }

  if (lanzado === undefined) {
    throw new Error(`Se esperaba que lanzara ${codigo}, pero no lanzó nada.`);
  }
  expect(lanzado).toBeInstanceOf(ErrorDominio);
  expect((lanzado as ErrorDominio).codigo).toBe(codigo);
}
