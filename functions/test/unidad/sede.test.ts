/**
 * Pruebas de sedes, facultades y membresías — 2.0 · ADR-009 · RF-SED, RF-FAC.
 *
 * Lo que más importa aquí es que la migración no rompa nada: un perfil o un
 * token de antes de la 2.0 tiene que comportarse exactamente igual que antes,
 * como de la sede inicial con su rol de siempre. Y que con varias sedes nadie
 * pueda actuar en una que no es suya, ni por omisión.
 */

import { claimsDe, decidirActivacion, type PerfilUsuario } from '../../src/application/activarSesion';
import { ErrorAutorizacion, ErrorValidacion } from '../../src/domain/errores';
import {
  FACULTAD_INICIAL,
  MAXIMO_DE_SEDES,
  SEDE_INICIAL,
  conFacultadesEnSede,
  conRolEnSede,
  elegirSede,
  esIdDeSede,
  membresiasDe,
  perteneceASede,
  rolEnSede,
  sedeDelDocumento,
  sedePrincipal,
  sedesDeMembresias,
  sedesDelToken,
} from '../../src/domain/sede';

describe('membresiasDe: un perfil de antes de la 2.0 es de la sede inicial', () => {
  it('sin membresías: la sede inicial con su rol de siempre', () => {
    expect(membresiasDe({ rol: 'COORDINADOR' })).toEqual({
      [SEDE_INICIAL]: { rol: 'COORDINADOR', facultades: [] },
    });
  });

  it('con membresías guardadas, se respetan y se ordenan las facultades', () => {
    expect(
      membresiasDe({
        rol: 'CATEDRATICO',
        membresias: {
          bdm: { rol: 'CATEDRATICO', facultades: ['ing-sistemas', 'derecho', 'ing-sistemas'] },
          otra: { rol: 'COORDINADOR' },
        },
      }),
    ).toEqual({
      bdm: { rol: 'CATEDRATICO', facultades: ['derecho', 'ing-sistemas'] },
      otra: { rol: 'COORDINADOR', facultades: [] },
    });
  });

  it('una entrada mal escrita se descarta sin quitarle las demás', () => {
    expect(
      membresiasDe({
        rol: 'CATEDRATICO',
        membresias: {
          bdm: { rol: 'CATEDRATICO', facultades: ['ing-sistemas', 'Con Espacios', 7] },
          'Sede Rara': { rol: 'COORDINADOR' },
          otra: { rol: 'REY' },
          vacia: null,
        },
      }),
    ).toEqual({ bdm: { rol: 'CATEDRATICO', facultades: ['ing-sistemas'] } });
  });

  it('si no queda ninguna válida, vuelve a la de omisión', () => {
    expect(membresiasDe({ rol: 'AUDITOR', membresias: { x: 'basura' } })).toEqual({
      [SEDE_INICIAL]: { rol: 'AUDITOR', facultades: [] },
    });
    expect(membresiasDe({ rol: 'AUDITOR', membresias: ['bdm'] })).toEqual({
      [SEDE_INICIAL]: { rol: 'AUDITOR', facultades: [] },
    });
  });
});

describe('identificadores', () => {
  it('cortos, en minúsculas, con guiones en medio', () => {
    expect(esIdDeSede('bdm')).toBe(true);
    expect(esIdDeSede(FACULTAD_INICIAL.id)).toBe(true);
    expect(esIdDeSede('a')).toBe(true);
    expect(esIdDeSede('-bdm')).toBe(false);
    expect(esIdDeSede('bdm-')).toBe(false);
    expect(esIdDeSede('BDM')).toBe(false);
    expect(esIdDeSede('sede/otra')).toBe(false);
    expect(esIdDeSede('x'.repeat(33))).toBe(false);
    expect(esIdDeSede(7)).toBe(false);
  });
});

describe('sede principal y token', () => {
  it('la principal es la inicial si pertenece a ella; si no, la primera', () => {
    expect(sedePrincipal({ zeta: { rol: 'CATEDRATICO', facultades: [] }, bdm: { rol: 'AUDITOR', facultades: [] } })).toBe('bdm');
    expect(sedePrincipal({ zeta: { rol: 'CATEDRATICO', facultades: [] }, alfa: { rol: 'AUDITOR', facultades: [] } })).toBe('alfa');
    expect(sedePrincipal({})).toBe(SEDE_INICIAL);
  });

  it('al token va el rol por sede, sin facultades', () => {
    expect(
      sedesDeMembresias({
        otra: { rol: 'COORDINADOR', facultades: ['x'] },
        bdm: { rol: 'CATEDRATICO', facultades: [] },
      }),
    ).toEqual({ bdm: 'CATEDRATICO', otra: 'COORDINADOR' });
  });

  it('un token de antes de la 2.0 equivale a la sede inicial con el rol global', () => {
    expect(sedesDelToken({ rol: 'COORDINADOR' }, 'COORDINADOR')).toEqual({ bdm: 'COORDINADOR' });
    expect(sedesDelToken({ sedes: 'bdm' }, 'CATEDRATICO')).toEqual({ bdm: 'CATEDRATICO' });
    expect(sedesDelToken({ sedes: { 'Mal Id': 'COORDINADOR', bdm: 'REY' } }, 'AUDITOR')).toEqual({
      bdm: 'AUDITOR',
    });
  });

  it('un token de la 2.0 dice sus sedes', () => {
    expect(sedesDelToken({ sedes: { bdm: 'CATEDRATICO', otra: 'COORDINADOR' } }, 'CATEDRATICO')).toEqual({
      bdm: 'CATEDRATICO',
      otra: 'COORDINADOR',
    });
  });
});

describe('elegirSede: RF-SED-04 y RF-SED-05', () => {
  const una = { bdm: 'CATEDRATICO' } as const;
  const dos = { bdm: 'CATEDRATICO', otra: 'COORDINADOR' } as const;

  it('con una sola sede no se pregunta', () => {
    expect(elegirSede(una)).toBe('bdm');
    expect(elegirSede(una, '')).toBe('bdm');
    expect(elegirSede(una, null)).toBe('bdm');
  });

  it('con varias hay que decir cuál, y tiene que ser suya', () => {
    expect(elegirSede(dos, 'otra')).toBe('otra');
    expect(() => elegirSede(dos)).toThrow(ErrorValidacion);
    expect(() => elegirSede(dos)).toThrow(/más de una sede/);
  });

  it('pedir una sede ajena se rechaza, aunque solo tenga una', () => {
    expect(() => elegirSede(una, 'otra')).toThrow(ErrorAutorizacion);
    expect(() => elegirSede(dos, 'tercera')).toThrow(ErrorAutorizacion);
    expect(() => elegirSede(una, '../bdm')).toThrow(ErrorAutorizacion);
  });

  it('el rol en una sede, o nada si no pertenece', () => {
    expect(rolEnSede(dos, 'otra')).toBe('COORDINADOR');
    expect(rolEnSede(dos, 'tercera')).toBeNull();
    expect(rolEnSede(dos, 'constructor')).toBeNull();
  });
});

describe('pertenencia y documentos', () => {
  it('un perfil sin membresías pertenece solo a la sede inicial', () => {
    expect(perteneceASede({ rol: 'CATEDRATICO' }, 'bdm')).toBe(true);
    expect(perteneceASede({ rol: 'CATEDRATICO' }, 'otra')).toBe(false);
  });

  it('un documento sin sede es de la inicial', () => {
    expect(sedeDelDocumento({})).toBe('bdm');
    expect(sedeDelDocumento(undefined)).toBe('bdm');
    expect(sedeDelDocumento({ sedeId: 'otra' })).toBe('otra');
    expect(sedeDelDocumento({ sedeId: 'Mal Id' })).toBe('bdm');
  });
});

describe('conRolEnSede', () => {
  it('cambia el rol en una sede sin tocar las otras ni las facultades', () => {
    expect(
      conRolEnSede(
        {
          rol: 'CATEDRATICO',
          membresias: {
            bdm: { rol: 'CATEDRATICO', facultades: ['ing-sistemas'] },
            otra: { rol: 'CATEDRATICO', facultades: [] },
          },
        },
        'bdm',
        'COORDINADOR',
      ),
    ).toEqual({
      bdm: { rol: 'COORDINADOR', facultades: ['ing-sistemas'] },
      otra: { rol: 'CATEDRATICO', facultades: [] },
    });
  });

  it('el primer cambio de un perfil sin membresías lo deja migrado', () => {
    expect(conRolEnSede({ rol: 'CATEDRATICO' }, 'bdm', 'ADMINISTRADORA')).toEqual({
      bdm: { rol: 'ADMINISTRADORA', facultades: [] },
    });
  });

  it('no deja pasar del máximo de sedes', () => {
    const muchas: Record<string, { rol: 'CATEDRATICO'; facultades: string[] }> = {};
    for (let i = 0; i < MAXIMO_DE_SEDES; i++) {
      muchas[`s${i}`] = { rol: 'CATEDRATICO', facultades: [] };
    }
    expect(() => conRolEnSede({ rol: 'CATEDRATICO', membresias: muchas }, 'una-mas', 'CATEDRATICO')).toThrow(
      ErrorValidacion,
    );
  });
});

describe('claims de la 2.0', () => {
  const base: PerfilUsuario = {
    uid: 'u',
    correo: 'a@umg.edu.gt',
    nombre: 'A',
    rol: 'CATEDRATICO',
    activo: true,
    proveedorAuth: 'google.com',
    puedeEmitirUrgentes: false,
    puedeCrearRecurrentes: false,
    zonaHoraria: 'America/Guatemala',
  };

  it('un perfil sin membresías lleva al token la sede inicial', () => {
    expect(claimsDe(base).sedes).toEqual({ bdm: 'CATEDRATICO' });
    expect(claimsDe(base).adminGeneral).toBe(false);
  });

  it('con varias sedes, el token lleva el rol de cada una', () => {
    const c = claimsDe({
      ...base,
      adminGeneral: true,
      membresias: {
        bdm: { rol: 'CATEDRATICO', facultades: ['ing-sistemas'] },
        otra: { rol: 'COORDINADOR', facultades: [] },
      },
    });
    expect(c.sedes).toEqual({ bdm: 'CATEDRATICO', otra: 'COORDINADOR' });
    expect(c.adminGeneral).toBe(true);
    expect(c.rol).toBe('CATEDRATICO');
  });

  it('con el máximo de sedes, los claims siguen cabiendo en el token (1000 bytes)', () => {
    const membresias: Record<string, { rol: 'ADMINISTRADORA'; facultades: string[] }> = {};
    for (let i = 0; i < MAXIMO_DE_SEDES; i++) {
      membresias[`sede-de-nombre-largo-${String(i).padStart(2, '0')}`] = {
        rol: 'ADMINISTRADORA',
        facultades: ['una', 'otra'],
      };
    }
    const c = claimsDe({ ...base, puedeEmitirUrgentes: true, puedeCrearRecurrentes: true, membresias });
    expect(Buffer.byteLength(JSON.stringify(c), 'utf8')).toBeLessThan(1000);
  });

  it('un alta nueva nace migrada, en la sede inicial con el rol de su invitación', () => {
    const r = decidirActivacion({
      uid: 'nuevo',
      correo: 'nueva@umg.edu.gt',
      proveedorAuth: 'google.com',
      invitacion: {
        correo: 'nueva@umg.edu.gt',
        rolAsignado: 'ADMINISTRADORA',
        nombre: 'Nueva',
        consumida: false,
        creadaPor: 'coord',
        creadaEn: new Date('2026-11-07T00:00:00Z'),
      },
      perfilExistente: null,
      zonaHorariaInstitucional: 'America/Guatemala',
    });
    expect(r.tipo).toBe('PERFIL_CREADO');
    if (r.tipo !== 'PERFIL_CREADO') return;
    expect(r.perfil.membresias).toEqual({ bdm: { rol: 'ADMINISTRADORA', facultades: [] } });
    expect(r.claims.sedes).toEqual({ bdm: 'ADMINISTRADORA' });
  });
});

describe('conFacultadesEnSede (RF-FAC-01)', () => {
  const CATALOGO = [
    { id: 'ing-sistemas', activa: true },
    { id: 'derecho', activa: true },
    { id: 'cerrada', activa: false },
  ];

  it('fija las facultades de esa sede, sin tocar el rol ni las otras sedes', () => {
    expect(
      conFacultadesEnSede(
        {
          rol: 'CATEDRATICO',
          membresias: {
            bdm: { rol: 'CATEDRATICO', facultades: ['ing-sistemas'] },
            otra: { rol: 'COORDINADOR', facultades: ['x'] },
          },
        },
        'bdm',
        ['derecho', 'ing-sistemas', 'derecho'],
        CATALOGO,
      ),
    ).toEqual({
      bdm: { rol: 'CATEDRATICO', facultades: ['derecho', 'ing-sistemas'] },
      otra: { rol: 'COORDINADOR', facultades: ['x'] },
    });
  });

  it('un perfil sin membresías queda migrado', () => {
    expect(conFacultadesEnSede({ rol: 'CATEDRATICO' }, 'bdm', ['ing-sistemas'], CATALOGO)).toEqual({
      bdm: { rol: 'CATEDRATICO', facultades: ['ing-sistemas'] },
    });
  });

  it('dejarla sin facultades es válido', () => {
    expect(conFacultadesEnSede({ rol: 'CATEDRATICO' }, 'bdm', [], CATALOGO).bdm?.facultades).toEqual([]);
  });

  it('una facultad inexistente o inactiva se rechaza', () => {
    expect(() => conFacultadesEnSede({ rol: 'CATEDRATICO' }, 'bdm', ['quimica'], CATALOGO)).toThrow(
      ErrorValidacion,
    );
    expect(() => conFacultadesEnSede({ rol: 'CATEDRATICO' }, 'bdm', ['cerrada'], CATALOGO)).toThrow(
      /no existe o está inactiva/,
    );
  });

  it('alguien de otra sede, o una lista mal formada, se rechaza', () => {
    expect(() => conFacultadesEnSede({ rol: 'CATEDRATICO' }, 'otra', [], CATALOGO)).toThrow(/no pertenece/);
    expect(() => conFacultadesEnSede({ rol: 'CATEDRATICO' }, 'bdm', 'ing-sistemas', CATALOGO)).toThrow(
      ErrorValidacion,
    );
    expect(() => conFacultadesEnSede({ rol: 'CATEDRATICO' }, 'bdm', ['Con Espacio'], CATALOGO)).toThrow(
      ErrorValidacion,
    );
  });
});
