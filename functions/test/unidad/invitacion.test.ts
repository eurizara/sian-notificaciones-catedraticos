/**
 * Pruebas de la lista blanca institucional — RF-AUT-03, RF-USR-01.
 */

import { ErrorValidacion } from '../../src/domain/errores';
import {
  MAX_INVITACIONES_POR_CARGA,
  crearInvitacion,
  decidirCarga,
  interpretarCsv,
} from '../../src/domain/invitacion';
import { esperarCodigo } from './ayudas';

const CREADOR = 'uid-coordinador';

describe('crearInvitacion', () => {
  it('normaliza el correo, que es la clave del documento', () => {
    // El identificador del documento ES el correo normalizado (documento 05,
    // sección 2.10): normalizar mal es no encontrar al usuario.
    const i = crearInvitacion({
      correo: '  Ana.Perez@UMG.EDU.GT ',
      rolAsignado: 'CATEDRATICO',
      creadaPor: CREADOR,
    });
    expect(i.correo).toBe('ana.perez@umg.edu.gt');
  });

  it('acepta el rol en cualquier caja y lo normaliza', () => {
    expect(
      crearInvitacion({ correo: 'a@umg.gt', rolAsignado: 'coordinador', creadaPor: CREADOR })
        .rolAsignado,
    ).toBe('COORDINADOR');
  });

  it('nace sin consumir', () => {
    const i = crearInvitacion({
      correo: 'a@umg.gt',
      rolAsignado: 'AUDITOR',
      creadaPor: CREADOR,
    });
    expect(i.consumida).toBe(false);
    expect(i.consumidaPor).toBeUndefined();
  });

  it('rechaza un rol desconocido', () => {
    esperarCodigo(
      () =>
        crearInvitacion({ correo: 'a@umg.gt', rolAsignado: 'SUPERUSUARIO', creadaPor: CREADOR }),
      'ROL_INVALIDO',
    );
  });

  it('rechaza un correo con forma inválida', () => {
    esperarCodigo(
      () => crearInvitacion({ correo: 'sinarroba', rolAsignado: 'AUDITOR', creadaPor: CREADOR }),
      'CORREO_INVALIDO',
    );
  });

  it('RF-BIT-02 · exige saber quién la creó', () => {
    esperarCodigo(
      () => crearInvitacion({ correo: 'a@umg.gt', rolAsignado: 'AUDITOR', creadaPor: '' }),
      'CREADOR_OBLIGATORIO',
    );
  });
});

describe('RF-USR-01 · carga masiva por CSV', () => {
  it('interpreta un archivo con encabezado', () => {
    const csv = [
      'correo,rol,nombre',
      'ana@umg.edu.gt,CATEDRATICO,Ana Pérez',
      'luis@umg.edu.gt,CATEDRATICO,Luis Gómez',
    ].join('\n');

    const r = interpretarCsv(csv, CREADOR);
    expect(r.validas).toHaveLength(2);
    expect(r.rechazadas).toHaveLength(0);
    expect(r.validas[0]?.nombre).toBe('Ana Pérez');
  });

  it('interpreta un archivo sin encabezado', () => {
    const r = interpretarCsv('ana@umg.edu.gt,CATEDRATICO,Ana', CREADOR);
    expect(r.validas).toHaveLength(1);
  });

  it('una línea mala NO aborta la carga entera', () => {
    // Descartar 300 correos buenos por una coma de más sería la peor forma
    // posible de tratar a quien carga la lista.
    const csv = [
      'ana@umg.edu.gt,CATEDRATICO,Ana',
      'esto-no-es-correo,CATEDRATICO,Nadie',
      'luis@umg.edu.gt,CATEDRATICO,Luis',
    ].join('\n');

    const r = interpretarCsv(csv, CREADOR);
    expect(r.validas).toHaveLength(2);
    expect(r.rechazadas).toHaveLength(1);
  });

  it('la línea rechazada dice su número y su motivo', () => {
    const csv = ['ana@umg.edu.gt,CATEDRATICO,Ana', 'luis@umg.edu.gt,MARCIANO,Luis'].join('\n');

    const r = interpretarCsv(csv, CREADOR);
    expect(r.rechazadas[0]?.numero).toBe(2);
    expect(r.rechazadas[0]?.error).toContain('MARCIANO');
  });

  it('numera las líneas contando el encabezado', () => {
    const csv = ['correo,rol,nombre', 'ana@umg.edu.gt,CATEDRATICO,Ana', 'malo,X,Y'].join('\n');

    const r = interpretarCsv(csv, CREADOR);
    // La línea mala es la tercera del archivo tal como se ve en un editor.
    expect(r.rechazadas[0]?.numero).toBe(3);
  });

  it('rechaza un correo repetido en vez de sobrescribirlo en silencio', () => {
    // Puede ser un error de copiado con dos roles distintos, y adivinar cuál
    // gana sería inventar.
    const csv = ['ana@umg.edu.gt,CATEDRATICO,Ana', 'ana@umg.edu.gt,COORDINADOR,Ana'].join('\n');

    const r = interpretarCsv(csv, CREADOR);
    expect(r.validas).toHaveLength(1);
    expect(r.validas[0]?.rolAsignado).toBe('CATEDRATICO');
    expect(r.rechazadas[0]?.error).toContain('repetido');
  });

  it('detecta el repetido aunque cambie la caja del correo', () => {
    const csv = ['ana@umg.edu.gt,CATEDRATICO,Ana', 'ANA@UMG.EDU.GT,CATEDRATICO,Ana'].join('\n');
    expect(interpretarCsv(csv, CREADOR).rechazadas).toHaveLength(1);
  });

  it('ignora líneas en blanco y espacios sobrantes', () => {
    const csv = ['', '  ana@umg.edu.gt , CATEDRATICO , Ana  ', '', ''].join('\n');
    const r = interpretarCsv(csv, CREADOR);
    expect(r.validas).toHaveLength(1);
    expect(r.validas[0]?.correo).toBe('ana@umg.edu.gt');
  });

  it('rechaza un archivo vacío', () => {
    esperarCodigo(() => interpretarCsv('\n\n  \n', CREADOR), 'CSV_VACIO');
  });

  it('rechaza una carga por encima del tope', () => {
    const csv = Array.from(
      { length: MAX_INVITACIONES_POR_CARGA + 1 },
      (_, i) => `p${i}@umg.edu.gt,CATEDRATICO,P${i}`,
    ).join('\n');

    expect(() => interpretarCsv(csv, CREADOR)).toThrow(ErrorValidacion);
  });
});

/**
 * Volver a cargar un correo que ya está en la lista — RF-USR-01.
 *
 * ────────────────────────────────────────────────────────────────────────────
 * Es el caso que rompió la carga masiva del 25 de agosto de 2026.
 * ────────────────────────────────────────────────────────────────────────────
 *
 * La carga escribía `consumida: false` sobre TODO lo que llegaba, incluida
 * gente que ya había entrado. El documento quedaba diciendo que la invitación
 * seguía sin usar mientras conservaba su `consumidaPor` y su `consumidaEn`: se
 * contradecía a sí mismo, y con eso desarmaba la comprobación de
 * `decidirActivacion` que rechaza a quien intenta usar una invitación ajena ya
 * consumida.
 */
describe('decidirCarga', () => {
  it('un correo que no está en la lista se crea', () => {
    expect(decidirCarga({ existe: false, consumida: false })).toBe('CREAR');
  });

  it('un correo que está pero nadie ha usado se actualiza', () => {
    // Corregir una lista antes de que la gente entre es legítimo: una tilde
    // mal puesta, o alguien que pasa a coordinación antes de su primer acceso.
    expect(decidirCarga({ existe: true, consumida: false })).toBe('ACTUALIZAR');
  });

  it('un correo de alguien que YA ENTRÓ no se toca', () => {
    // Su rol de verdad vive en su perfil y en sus claims. Cambiarlo aquí no se
    // lo cambia a la persona: solo deja a los dos sitios en desacuerdo.
    expect(decidirCarga({ existe: true, consumida: true })).toBe('NO_TOCAR');
  });

  it('«ya entró» manda sobre cualquier otra cosa', () => {
    // La propiedad que sostiene todo lo anterior: si la invitación consta como
    // consumida, ninguna carga la reescribe. Si alguien invierte este orden,
    // vuelve el defecto exacto.
    for (const existe of [true]) {
      expect(decidirCarga({ existe, consumida: true })).toBe('NO_TOCAR');
    }
  });
});
