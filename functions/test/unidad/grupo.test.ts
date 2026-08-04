/**
 * Pruebas de grupos de destinatarios — RF-USR-03, RF-USR-04, RF-USR-05, DT-08.
 */

import {
  UMBRAL_AVISO_MIEMBROS,
  agregarMiembros,
  crearGrupo,
  quitarMiembros,
  rozaElLimite,
} from '../../src/domain/grupo';
import { LIMITES } from '../../src/domain/tipos';
import { esperarCodigo } from './ayudas';

const CREADOR = 'uid-coordinador';

function grupoDePrueba(miembros: readonly string[] = []) {
  return crearGrupo({
    nombre: 'Facultad de Ingeniería',
    descripcion: 'Catedráticos de Ingeniería',
    miembros,
    creadoPor: CREADOR,
  });
}

describe('creación', () => {
  it('mantiene el conteo desnormalizado en correspondencia con la lista', () => {
    const g = grupoDePrueba(['u1', 'u2', 'u3']);
    expect(g.totalMiembros).toBe(3);
    expect(g.miembros).toHaveLength(3);
  });

  it('nace activo', () => {
    expect(grupoDePrueba().activo).toBe(true);
  });

  it('exige nombre y creador', () => {
    esperarCodigo(
      () => crearGrupo({ nombre: '   ', creadoPor: CREADOR }),
      'NOMBRE_GRUPO_VACIO',
    );
    esperarCodigo(() => crearGrupo({ nombre: 'X', creadoPor: '' }), 'CREADOR_OBLIGATORIO');
  });

  it('limita la longitud del nombre', () => {
    esperarCodigo(
      () => crearGrupo({ nombre: 'a'.repeat(61), creadoPor: CREADOR }),
      'NOMBRE_GRUPO_MUY_LARGO',
    );
  });
});

describe('RF-USR-05 · normalización de miembros', () => {
  it('colapsa repetidos en lugar de rechazarlos', () => {
    // Que alguien aparezca dos veces en una selección es un descuido de la
    // interfaz, no una intención; duplicarlo generaría dos entregas al mismo
    // destinatario.
    const g = grupoDePrueba(['u1', 'u1', 'u2']);
    expect(g.miembros).toEqual(['u1', 'u2']);
    expect(g.totalMiembros).toBe(2);
  });

  it('descarta cadenas vacías y espacios', () => {
    const g = grupoDePrueba(['u1', '', '   ', ' u2 ']);
    expect(g.miembros).toEqual(['u1', 'u2']);
  });
});

describe('DT-08 · límite de 200 miembros', () => {
  it('admite exactamente el máximo', () => {
    const justos = Array.from({ length: LIMITES.MAX_MIEMBROS_POR_GRUPO }, (_, i) => `u${i}`);
    expect(grupoDePrueba(justos).totalMiembros).toBe(LIMITES.MAX_MIEMBROS_POR_GRUPO);
  });

  it('rechaza uno más', () => {
    // El límite no es arbitrario: los miembros viven como arreglo dentro del
    // documento, y un documento de Firestore no pasa de 1 MiB.
    const demasiados = Array.from(
      { length: LIMITES.MAX_MIEMBROS_POR_GRUPO + 1 },
      (_, i) => `u${i}`,
    );
    esperarCodigo(() => grupoDePrueba(demasiados), 'GRUPO_DEMASIADO_GRANDE');
  });

  it('avisa antes de llegar al tope, no cuando ya no cabe nadie', () => {
    // Descubrir el límite el día que hace falta agregar a alguien es peor que
    // saberlo con 50 de margen.
    expect(rozaElLimite(UMBRAL_AVISO_MIEMBROS - 1)).toBe(false);
    expect(rozaElLimite(UMBRAL_AVISO_MIEMBROS)).toBe(true);
    expect(UMBRAL_AVISO_MIEMBROS).toBeLessThan(LIMITES.MAX_MIEMBROS_POR_GRUPO);
  });
});

describe('RF-USR-04 · agregar y quitar', () => {
  it('agrega sin duplicar a quien ya estaba', () => {
    const g = agregarMiembros(grupoDePrueba(['u1', 'u2']), ['u2', 'u3']);
    expect(g.miembros).toEqual(['u1', 'u2', 'u3']);
    expect(g.totalMiembros).toBe(3);
  });

  it('quita y actualiza el conteo', () => {
    const g = quitarMiembros(grupoDePrueba(['u1', 'u2', 'u3']), ['u2']);
    expect(g.miembros).toEqual(['u1', 'u3']);
    expect(g.totalMiembros).toBe(2);
  });

  it('quitar a alguien que no estaba no altera nada', () => {
    const g = quitarMiembros(grupoDePrueba(['u1']), ['u9']);
    expect(g.miembros).toEqual(['u1']);
  });

  it('agregar por encima del límite se rechaza', () => {
    const casiLleno = Array.from({ length: LIMITES.MAX_MIEMBROS_POR_GRUPO }, (_, i) => `u${i}`);
    esperarCodigo(
      () => agregarMiembros(grupoDePrueba(casiLleno), ['uno-mas']),
      'GRUPO_DEMASIADO_GRANDE',
    );
  });

  it('las operaciones no mutan el grupo original', () => {
    const original = grupoDePrueba(['u1']);
    agregarMiembros(original, ['u2']);
    quitarMiembros(original, ['u1']);
    expect(original.miembros).toEqual(['u1']);
  });
});
