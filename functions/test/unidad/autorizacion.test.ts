/**
 * Pruebas de la matriz RBAC — documento 01, sección 2.2 · RN-01.
 *
 * La matriz se recorre entera, celda por celda. Es la única forma de que un
 * cambio de permiso no pase inadvertido: si alguien mueve un «No» a un «Sí»,
 * esta prueba falla y obliga a actualizar también el documento.
 */

import { ErrorAutorizacion } from '../../src/domain/errores';
import { exigirPermiso, puede, type Permiso, type Sujeto } from '../../src/domain/autorizacion';
import type { Rol } from '../../src/domain/tipos';

function sujeto(rol: Rol, extra: Partial<Sujeto> = {}): Sujeto {
  return { uid: 'u-1', rol, activo: true, ...extra };
}

const RECURSO_PROPIO = { creadoPor: 'u-1' };
const RECURSO_AJENO = { creadoPor: 'u-2' };

describe('Matriz de permisos, celda por celda', () => {
  // Cada fila: permiso, y lo que se espera de cada rol sobre un recurso propio.
  const esperado: ReadonlyArray<[Permiso, boolean, boolean, boolean, boolean]> = [
    // permiso                     coord  admin  catedrático  auditor
    ['CREAR_AVISO_INFORMATIVO', true, true, false, false],
    ['ADJUNTAR_MULTIMEDIA', true, true, false, false],
    ['PROGRAMAR_ENVIO', true, true, false, false],
    ['CANCELAR_PROGRAMACION', true, true, false, false],
    ['EXIGIR_CONFIRMACION', true, true, false, false],
    ['VER_REPORTE_ENTREGAS', true, true, false, true],
    ['VER_BITACORA_COMPLETA', true, false, false, true],
    ['ADMINISTRAR_USUARIOS', true, false, false, false],
    ['ADMINISTRAR_GRUPOS', true, true, false, false],
    ['CONFIRMAR_LECTURA', true, true, true, false],
    ['VER_HISTORIAL_PROPIO', true, true, true, false],
  ];

  it.each(esperado)(
    '%s',
    (permiso, coordinador, administradora, catedratico, auditor) => {
      expect(puede(sujeto('COORDINADOR'), permiso, RECURSO_PROPIO)).toBe(coordinador);
      expect(puede(sujeto('ADMINISTRADORA'), permiso, RECURSO_PROPIO)).toBe(administradora);
      expect(puede(sujeto('CATEDRATICO'), permiso, RECURSO_PROPIO)).toBe(catedratico);
      expect(puede(sujeto('AUDITOR'), permiso, RECURSO_PROPIO)).toBe(auditor);
    },
  );
});

describe('«Solo lo propio» de la administradora', () => {
  it('puede cancelar su programación pero no la de otro emisor', () => {
    const admin = sujeto('ADMINISTRADORA');
    expect(puede(admin, 'CANCELAR_PROGRAMACION', RECURSO_PROPIO)).toBe(true);
    expect(puede(admin, 'CANCELAR_PROGRAMACION', RECURSO_AJENO)).toBe(false);
  });

  it('ve el reporte de entregas de sus mensajes, no el de los ajenos', () => {
    const admin = sujeto('ADMINISTRADORA');
    expect(puede(admin, 'VER_REPORTE_ENTREGAS', RECURSO_PROPIO)).toBe(true);
    expect(puede(admin, 'VER_REPORTE_ENTREGAS', RECURSO_AJENO)).toBe(false);
  });

  it('el coordinador y el auditor no distinguen dueño', () => {
    expect(puede(sujeto('COORDINADOR'), 'VER_REPORTE_ENTREGAS', RECURSO_AJENO)).toBe(true);
    expect(puede(sujeto('AUDITOR'), 'VER_REPORTE_ENTREGAS', RECURSO_AJENO)).toBe(true);
  });

  it('sin recurso, un permiso de alcance propio se deniega', () => {
    expect(puede(sujeto('ADMINISTRADORA'), 'CANCELAR_PROGRAMACION')).toBe(false);
  });
});

describe('Autorización fina «según autorización» del coordinador', () => {
  it('la administradora emite urgentes solo si el coordinador lo habilitó', () => {
    expect(puede(sujeto('ADMINISTRADORA'), 'CREAR_ALERTA_URGENTE')).toBe(false);
    expect(
      puede(sujeto('ADMINISTRADORA', { puedeEmitirUrgentes: true }), 'CREAR_ALERTA_URGENTE'),
    ).toBe(true);
  });

  it('la administradora crea recurrentes solo si el coordinador lo habilitó', () => {
    expect(puede(sujeto('ADMINISTRADORA'), 'CREAR_RECURRENTE')).toBe(false);
    expect(
      puede(sujeto('ADMINISTRADORA', { puedeCrearRecurrentes: true }), 'CREAR_RECURRENTE'),
    ).toBe(true);
  });

  it('el coordinador no necesita habilitación fina', () => {
    expect(puede(sujeto('COORDINADOR'), 'CREAR_ALERTA_URGENTE')).toBe(true);
    expect(puede(sujeto('COORDINADOR'), 'CREAR_RECURRENTE')).toBe(true);
  });

  it('la habilitación fina no le sirve de nada a un catedrático', () => {
    expect(
      puede(sujeto('CATEDRATICO', { puedeEmitirUrgentes: true }), 'CREAR_ALERTA_URGENTE'),
    ).toBe(false);
  });
});

describe('RN-10 · usuario desactivado', () => {
  it('conserva su historial pero no puede ejercer ningún permiso', () => {
    const coordinadorInactivo = sujeto('COORDINADOR', { activo: false });
    expect(puede(coordinadorInactivo, 'CREAR_AVISO_INFORMATIVO')).toBe(false);
    expect(puede(coordinadorInactivo, 'VER_BITACORA_COMPLETA')).toBe(false);
    expect(puede(coordinadorInactivo, 'CONFIRMAR_LECTURA')).toBe(false);
  });
});

describe('exigirPermiso', () => {
  it('no lanza cuando el permiso existe', () => {
    expect(() => exigirPermiso(sujeto('COORDINADOR'), 'ADMINISTRAR_USUARIOS')).not.toThrow();
  });

  it('lanza ErrorAutorizacion con datos aptos para la bitácora', () => {
    try {
      exigirPermiso(sujeto('CATEDRATICO'), 'ADMINISTRAR_USUARIOS');
      throw new Error('debió lanzar');
    } catch (e) {
      expect(e).toBeInstanceOf(ErrorAutorizacion);
      const err = e as ErrorAutorizacion;
      expect(err.codigo).toBe('PERMISO_DENEGADO');
      expect(err.detalle).toMatchObject({ rol: 'CATEDRATICO', permiso: 'ADMINISTRAR_USUARIOS' });
    }
  });
});
