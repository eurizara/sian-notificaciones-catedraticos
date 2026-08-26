/**
 * Pruebas de los objetos de valor — RF-MSG-06, RF-AUT-03, RF-AUT-06.
 */

import { ErrorValidacion } from '../../src/domain/errores';
import {
  CorreoInstitucional,
  Cuerpo,
  HoraLocal,
  Titulo,
} from '../../src/domain/objetosDeValor';

describe('Titulo · RF-MSG-06', () => {
  it('recorta espacios sobrantes', () => {
    expect(Titulo.crear('  Simulacro de evacuación  ').valor).toBe('Simulacro de evacuación');
  });

  it('admite exactamente 80 caracteres y rechaza 81', () => {
    expect(Titulo.crear('a'.repeat(80)).valor).toHaveLength(80);
    expect(() => Titulo.crear('a'.repeat(81))).toThrow(ErrorValidacion);
  });

  it('cuenta caracteres, no bytes: los acentos y la eñe no gastan doble', () => {
    // 80 caracteres acentuados siguen siendo 80 caracteres.
    expect(() => Titulo.crear('ñ'.repeat(80))).not.toThrow();
  });

  it('rechaza un título vacío o de solo espacios', () => {
    expect(() => Titulo.crear('   ')).toThrow(ErrorValidacion);
    expect(() => Titulo.crear('')).toThrow(/TITULO_VACIO|obligatorio/);
  });

  it('es inmutable y comparable por valor', () => {
    const a = Titulo.crear('Aviso');
    const b = Titulo.crear('Aviso');
    expect(a.equals(b)).toBe(true);
    expect(a.equals(Titulo.crear('Otro'))).toBe(false);
    expect(Object.isFrozen(a)).toBe(true);
  });
});

describe('Cuerpo · RF-MSG-06', () => {
  it('admite 500 caracteres y rechaza 501', () => {
    expect(Cuerpo.crear('x'.repeat(500)).valor).toHaveLength(500);
    expect(() => Cuerpo.crear('x'.repeat(501))).toThrow(ErrorValidacion);
  });

  it('informa la longitud y el máximo en el detalle del error', () => {
    try {
      Cuerpo.crear('x'.repeat(600));
      throw new Error('debió lanzar');
    } catch (e) {
      expect((e as ErrorValidacion).detalle).toMatchObject({ longitud: 600, maximo: 500 });
    }
  });
});

describe('CorreoInstitucional · RF-AUT-03', () => {
  it('normaliza a minúsculas y sin espacios, porque es la clave de la lista blanca', () => {
    // El identificador del documento en `invitaciones` ES este valor
    // (documento 05, sección 2.10): normalizar mal es no encontrar al usuario.
    expect(CorreoInstitucional.crear('  Coordinacion@UMG.EDU.GT ').valor).toBe(
      'coordinacion@umg.edu.gt',
    );
  });

  it('expone el dominio para poder verificar pertenencia institucional', () => {
    expect(CorreoInstitucional.crear('ana@umg.edu.gt').dominio).toBe('umg.edu.gt');
  });

  it('rechaza formas que no son correo', () => {
    for (const malo of ['sinarroba', 'a@b', 'a@@b.com', 'con espacio@umg.gt', '@umg.gt', '']) {
      expect(() => CorreoInstitucional.crear(malo)).toThrow(ErrorValidacion);
    }
  });
});

describe('HoraLocal · RF-PRG-07, RF-PRG-08', () => {
  it('acepta HH:mm en 24 horas', () => {
    const h = HoraLocal.crear('07:30');
    expect([h.hora, h.minuto, h.minutosDesdeMedianoche]).toEqual([7, 30, 450]);
    expect(HoraLocal.crear('23:59').minutosDesdeMedianoche).toBe(1439);
  });

  it('rechaza horas imposibles y formatos de 12 horas', () => {
    for (const malo of ['24:00', '7:30', '07:60', '7pm', '19h00', '']) {
      expect(() => HoraLocal.crear(malo)).toThrow(ErrorValidacion);
    }
  });
});

// La política de contraseñas tiene su propio archivo de pruebas:
// `politicaContrasena.test.ts`. Creció lo bastante como para merecerlo.
