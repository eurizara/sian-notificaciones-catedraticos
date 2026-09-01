/**
 * Pruebas de los errores del dominio — DT-24.
 *
 * Lo que se comprueba aquí no es una validación sino un **reconocimiento**: si
 * el sistema sabe distinguir «este aviso ya se envió» de «algo salió mal por
 * dentro». La diferencia no es cosmética. Un fallo interno invita a volver a
 * pulsar; un «ya se envió» dice que no hace falta.
 *
 * El 29 de agosto de 2026 esa distinción no existía, y dos avisos del
 * coordinador salieron cuatro.
 */

import { esDocumentoYaExistente, CODIGO_YA_EXISTE } from '../../src/domain/errores';

describe('esDocumentoYaExistente', () => {
  it('reconoce el rechazo de Firestore a un `create` repetido', () => {
    // Así llega el error real: un objeto con el código numérico de gRPC.
    expect(esDocumentoYaExistente({ code: CODIGO_YA_EXISTE })).toBe(true);
  });

  it('el código que reconoce es el 6, ALREADY_EXISTS', () => {
    // Fijado a propósito. Si alguien lo cambia, que sea decidiéndolo.
    expect(CODIGO_YA_EXISTE).toBe(6);
  });

  it('no confunde otros códigos de gRPC con un duplicado', () => {
    // 5 es NOT_FOUND, 7 PERMISSION_DENIED, 16 UNAUTHENTICATED. Tratar
    // cualquiera de ellos como «ya se envió» ocultaría un problema real
    // diciéndole a quien envía que su aviso ya salió, cuando no salió.
    for (const codigo of [0, 5, 7, 13, 16]) {
      expect(esDocumentoYaExistente({ code: codigo })).toBe(false);
    }
  });

  it('no se deja engañar por el código en texto', () => {
    // Se mira el número, no la cadena: el mensaje de Firestore está en inglés
    // y cambia entre versiones, mientras que el código es contrato de gRPC.
    expect(esDocumentoYaExistente({ code: '6' })).toBe(false);
    expect(esDocumentoYaExistente({ message: 'ALREADY_EXISTS' })).toBe(false);
  });

  it('aguanta cualquier cosa que le llegue', () => {
    // Lo recibe un `catch`, así que puede ser literalmente cualquier valor.
    // Que reviente aquí convertiría un envío fallido en una función caída.
    for (const valor of [null, undefined, 6, 'error', [], new Error('vaya')]) {
      expect(esDocumentoYaExistente(valor)).toBe(false);
    }
  });
});
