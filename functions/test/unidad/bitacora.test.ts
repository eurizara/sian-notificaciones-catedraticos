/**
 * Pruebas de la construcción de asientos — RF-BIT-01, RF-BIT-02, RNF-17.
 */

import { actorSistema, crearAsiento, TIPOS_EVENTO } from '../../src/domain/bitacora';
import type { Actor } from '../../src/domain/bitacora';
import { esperarCodigo } from './ayudas';

const ACTOR: Actor = {
  uid: 'uid-coordinador',
  correo: 'coordinacion@umg.edu.gt',
  rol: 'COORDINADOR',
};

function entradaValida(parcial: Record<string, unknown> = {}) {
  return {
    tipo: 'USUARIO_CREADO' as const,
    actor: ACTOR,
    entidad: 'USUARIO' as const,
    entidadId: 'uid-1',
    resumen: 'Alta de ana@umg.edu.gt',
    ...parcial,
  };
}

describe('RF-BIT-02 · contenido obligatorio del asiento', () => {
  it('desnormaliza correo y rol del actor', () => {
    // La bitácora debe poder leerse dentro de dos años sin depender de que
    // ese usuario siga existiendo (documento 05, sección 2.9).
    const a = crearAsiento(entradaValida());
    expect(a.actorUid).toBe('uid-coordinador');
    expect(a.actorCorreo).toBe('coordinacion@umg.edu.gt');
    expect(a.actorRol).toBe('COORDINADOR');
  });

  it('registra el instante y el origen', () => {
    const cuando = new Date('2026-08-03T13:00:00.000Z');
    const a = crearAsiento(entradaValida({ ocurridoEn: cuando, origen: 'APP_DOCENTE' }));
    expect(a.ocurridoEn).toEqual(cuando);
    expect(a.origen).toBe('APP_DOCENTE');
  });

  it('usa el panel web como origen por omisión', () => {
    expect(crearAsiento(entradaValida()).origen).toBe('PANEL_WEB');
  });

  it('exige un resumen legible por una persona', () => {
    // Dentro de dos años, quien audite no va a reconstruir qué pasó a partir
    // de un identificador.
    esperarCodigo(() => crearAsiento(entradaValida({ resumen: '   ' })), 'RESUMEN_OBLIGATORIO');
  });

  it('exige señalar sobre qué entidad ocurrió', () => {
    esperarCodigo(() => crearAsiento(entradaValida({ entidadId: '' })), 'ENTIDAD_ID_OBLIGATORIO');
  });
});

describe('catálogo cerrado del documento 05, sección 3', () => {
  it('rechaza un tipo de evento inventado', () => {
    esperarCodigo(
      () => crearAsiento(entradaValida({ tipo: 'ALGO_QUE_ME_INVENTE' })),
      'TIPO_EVENTO_INVALIDO',
    );
  });

  it('rechaza una entidad fuera del catálogo', () => {
    esperarCodigo(
      () => crearAsiento(entradaValida({ entidad: 'FACTURA' })),
      'ENTIDAD_INVALIDA',
    );
  });

  it('cubre los eventos que el documento 05 declara', () => {
    for (const tipo of ['SESION_INICIADA', 'SESION_RECHAZADA', 'USUARIO_CREADO', 'LECTURA_CONFIRMADA']) {
      expect(TIPOS_EVENTO).toContain(tipo);
    }
  });
});

describe('actor del sistema', () => {
  it('el planificador se identifica como SISTEMA, no como una persona', () => {
    const a = crearAsiento(
      entradaValida({ tipo: 'OCURRENCIA_DISPARADA', actor: actorSistema, entidad: 'MENSAJE' }),
    );
    expect(a.actorUid).toBe('SISTEMA');
    expect(a.actorRol).toBe('SISTEMA');
  });
});

describe('inmutabilidad', () => {
  it('el asiento y sus datos quedan congelados', () => {
    // RF-BIT-03: la bitácora es inmutable. Que el objeto lo sea en memoria
    // no la protege en la base, pero evita que un asiento se modifique entre
    // construirlo y escribirlo.
    const a = crearAsiento(entradaValida({ datos: { motivo: 'X' } }));
    expect(Object.isFrozen(a)).toBe(true);
    expect(Object.isFrozen(a.datos)).toBe(true);
  });
});
