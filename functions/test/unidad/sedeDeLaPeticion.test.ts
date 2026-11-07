/**
 * En qué sede actúa una petición y con qué rol — 2.0 · ADR-009 (segunda defensa).
 *
 * El permiso se mira con el rol que la persona tiene EN la sede donde actúa:
 * quien coordina en una sede y da clases en otra no puede enviar avisos desde
 * la segunda. Y un token de antes de la 2.0 sigue funcionando igual.
 */

import { puede } from '../../src/domain/autorizacion';
import { ErrorAutorizacion, ErrorValidacion } from '../../src/domain/errores';
import {
  rolDelPerfilEnSede,
  sedeDeLaPeticion,
  sujetoEnSede,
} from '../../src/application/sedeDeLaPeticion';

const DOS_SEDES = {
  rol: 'COORDINADOR',
  activo: true,
  sedes: { bdm: 'COORDINADOR', otra: 'CATEDRATICO' },
};

describe('sedeDeLaPeticion', () => {
  it('un token de antes de la 2.0 es de la sede inicial con su rol', () => {
    expect(sedeDeLaPeticion({ rol: 'ADMINISTRADORA', activo: true })).toMatchObject({
      sedeId: 'bdm',
      rol: 'ADMINISTRADORA',
    });
  });

  it('el rol que cuenta es el de la sede pedida', () => {
    expect(sedeDeLaPeticion(DOS_SEDES, 'otra').rol).toBe('CATEDRATICO');
    expect(sedeDeLaPeticion(DOS_SEDES, 'bdm').rol).toBe('COORDINADOR');
  });

  it('con varias sedes y sin decir cuál, no se adivina', () => {
    expect(() => sedeDeLaPeticion(DOS_SEDES)).toThrow(ErrorValidacion);
  });

  it('una sede ajena se rechaza', () => {
    expect(() => sedeDeLaPeticion(DOS_SEDES, 'tercera')).toThrow(ErrorAutorizacion);
  });

  it('un rol global desconocido no da privilegios', () => {
    expect(sedeDeLaPeticion({ rol: 'REY' }).rol).toBe('CATEDRATICO');
  });
});

describe('sujetoEnSede: el permiso con el rol de ESA sede', () => {
  it('coordina en bdm: puede enviar desde bdm, no desde la otra', () => {
    const enBdm = sujetoEnSede({ uid: 'u', token: DOS_SEDES }, 'bdm');
    const enOtra = sujetoEnSede({ uid: 'u', token: DOS_SEDES }, 'otra');
    expect(enBdm.sedeId).toBe('bdm');
    expect(puede(enBdm, 'CREAR_AVISO_INFORMATIVO')).toBe(true);
    expect(puede(enOtra, 'CREAR_AVISO_INFORMATIVO')).toBe(false);
  });

  it('las autorizaciones finas y el estado vienen del token', () => {
    const s = sujetoEnSede(
      { uid: 'u', token: { rol: 'ADMINISTRADORA', activo: false, puedeEmitirUrgentes: true } },
    );
    expect(s).toMatchObject({ activo: false, puedeEmitirUrgentes: true, puedeCrearRecurrentes: false });
  });
});

describe('rolDelPerfilEnSede', () => {
  it('perfil sin membresías: su rol en la inicial, nada en otra', () => {
    expect(rolDelPerfilEnSede({ rol: 'CATEDRATICO' }, 'bdm')).toBe('CATEDRATICO');
    expect(rolDelPerfilEnSede({ rol: 'CATEDRATICO' }, 'otra')).toBeNull();
  });

  it('perfil con membresías: el rol de cada sede', () => {
    const datos = {
      rol: 'COORDINADOR',
      membresias: { bdm: { rol: 'COORDINADOR' }, otra: { rol: 'CATEDRATICO', facultades: [] } },
    };
    expect(rolDelPerfilEnSede(datos, 'otra')).toBe('CATEDRATICO');
  });

  it('un rol guardado desconocido no da privilegios', () => {
    expect(rolDelPerfilEnSede({ rol: 'REY' }, 'bdm')).toBe('CATEDRATICO');
  });
});
