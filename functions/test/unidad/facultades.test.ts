/**
 * Catálogo único de facultades y lo que ofrece cada sede (2.0.6).
 *
 * Lo que se vigila: que nada quede colgando. No se retira de una sede una
 * facultad que alguien tiene, ni se desactiva en el catálogo una que alguna
 * sede ofrece; y una sede solo ofrece lo que está en el catálogo y activo.
 */

import { ErrorValidacion } from '../../src/domain/errores';
import { decidirOferta, exigirQueNingunaSedeLaOfrezca } from '../../src/domain/facultades';

const SISTEMAS = { nombre: 'Ingeniería en Sistemas', activa: true };

function motivo(f: () => unknown): string {
  try {
    f();
  } catch (e) {
    expect(e).toBeInstanceOf(ErrorValidacion);
    return (e as ErrorValidacion).codigo;
  }
  throw new Error('no lanzó');
}

describe('decidirOferta', () => {
  it('ofrecer una del catálogo que la sede no tenía: alta', () => {
    expect(decidirOferta({ ofrecer: true, catalogo: SISTEMAS, actual: undefined, personas: 0 })).toBe('alta');
  });

  it('ofrecer otra vez una que se había retirado: reactivada', () => {
    expect(decidirOferta({ ofrecer: true, catalogo: SISTEMAS, actual: { activa: false }, personas: 0 })).toBe(
      'reactivada',
    );
  });

  it('lo que ya está como se pide no cambia nada', () => {
    expect(decidirOferta({ ofrecer: true, catalogo: SISTEMAS, actual: { activa: true }, personas: 0 })).toBeNull();
    expect(decidirOferta({ ofrecer: false, catalogo: SISTEMAS, actual: undefined, personas: 0 })).toBeNull();
    expect(decidirOferta({ ofrecer: false, catalogo: SISTEMAS, actual: { activa: false }, personas: 3 })).toBeNull();
  });

  it('una sede no inventa facultades: tiene que estar en el catálogo', () => {
    expect(motivo(() => decidirOferta({ ofrecer: true, catalogo: undefined, actual: undefined, personas: 0 }))).toBe(
      'FACULTAD_INEXISTENTE',
    );
  });

  it('ni ofrece una desactivada en el catálogo', () => {
    expect(
      motivo(() =>
        decidirOferta({ ofrecer: true, catalogo: { ...SISTEMAS, activa: false }, actual: undefined, personas: 0 }),
      ),
    ).toBe('FACULTAD_INACTIVA');
  });

  it('retirar una que nadie tiene: retirada', () => {
    expect(decidirOferta({ ofrecer: false, catalogo: SISTEMAS, actual: { activa: true }, personas: 0 })).toBe(
      'retirada',
    );
  });

  it('retirar una que alguien tiene: se impide y se dice cuántos y qué hacer', () => {
    try {
      decidirOferta({ ofrecer: false, catalogo: SISTEMAS, actual: { activa: true }, personas: 2 });
      throw new Error('no lanzó');
    } catch (e) {
      expect((e as ErrorValidacion).codigo).toBe('FACULTAD_EN_USO');
      expect((e as Error).message).toContain('La tienen 2 personas');
      expect((e as Error).message).toContain('Usuarios');
      expect((e as Error).message).not.toContain('grupo');
    }
    try {
      decidirOferta({ ofrecer: false, catalogo: undefined, actual: { activa: true }, personas: 1 });
      throw new Error('no lanzó');
    } catch (e) {
      expect((e as Error).message).toContain('La tiene 1 persona');
    }
  });
});

describe('2.0.7 · una facultad que usan grupos de la sede', () => {
  it('no se retira, y se dice qué cambiar', () => {
    try {
      decidirOferta({ ofrecer: false, catalogo: SISTEMAS, actual: { activa: true }, personas: 0, grupos: 1 });
      throw new Error('no lanzó');
    } catch (e) {
      expect((e as ErrorValidacion).codigo).toBe('FACULTAD_EN_USO');
      expect((e as Error).message).toBe(
        'La usa 1 grupo en esta sede. Primero cambie la facultad de esos grupos; después retírela de la sede.',
      );
    }
  });

  it('con personas y grupos, dice las dos cosas', () => {
    expect(() =>
      decidirOferta({ ofrecer: false, catalogo: SISTEMAS, actual: { activa: true }, personas: 1, grupos: 2 }),
    ).toThrow('La tiene 1 persona y la usan 2 grupos en esta sede. Primero quítesela en Usuarios y cambie la facultad de esos grupos');
  });
});

describe('exigirQueNingunaSedeLaOfrezca', () => {
  it('sin sedes que la ofrezcan, se puede desactivar', () => {
    expect(() => exigirQueNingunaSedeLaOfrezca('Psicología', [])).not.toThrow();
  });

  it('con sedes que la ofrecen, se impide y se nombran', () => {
    expect(() => exigirQueNingunaSedeLaOfrezca('Psicología', ['Boca del Monte'])).toThrow(
      /la ofrece: Boca del Monte\./,
    );
    expect(() => exigirQueNingunaSedeLaOfrezca('Psicología', ['Boca del Monte', 'Villa Nueva'])).toThrow(
      /la ofrecen: Boca del Monte, Villa Nueva/,
    );
  });
});
