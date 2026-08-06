/**
 * Resolución de destinatarios — RF-USR-07, RF-ENT-01, RN-10.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Es la regla que decide a quién le llega un aviso de emergencia.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Por eso está aislada como función pura: los casos que aquí se prueban en
 * milisegundos —un miembro repetido en tres grupos, una cuenta desactivada, un
 * grupo que ya no existe— costaría horas provocarlos contra Firestore, y son
 * exactamente los que se descubren tarde y en el peor momento.
 */

import { recibeAvisos, recibePorOmision } from '../../src/domain/autorizacion';
import {
  resolverDestinatarios,
  type CandidatoDestinatario,
  type GrupoResuelto,
} from '../../src/application/resolverDestinatarios';
import { esperarCodigo } from './ayudas';

function persona(
  uid: string,
  extra: Partial<CandidatoDestinatario> = {},
): CandidatoDestinatario {
  return { uid, activo: true, rol: 'CATEDRATICO', ...extra };
}

function grupo(id: string, miembros: string[], activo = true): GrupoResuelto {
  return { id, activo, miembros };
}

const PADRON = [
  persona('ana'),
  persona('beto'),
  persona('carla'),
  persona('dario', { activo: false }),
  persona('elena', { rol: 'COORDINADOR' }),
  persona('fabio', { rol: 'ADMINISTRADORA' }),
  persona('gaby', { rol: 'AUDITOR' }),
  // Da clases y además emite: el caso que motivó la bandera.
  persona('hilda', { rol: 'ADMINISTRADORA', recibeAvisos: true }),
];

describe('quién recibe avisos', () => {
  // ───────────────────────────────────────────────────────────────────────
  // Recibir y emitir son dos preguntas distintas.
  // ───────────────────────────────────────────────────────────────────────
  //
  // El auditor observa sin formar parte del reparto. El coordinador los
  // escribe: mandárselos a sí mismo llenaría su teléfono de sus propios
  // simulacros y falsearía el porcentaje de confirmación.
  it('por omisión, solo el catedrático', () => {
    expect(recibeAvisos('CATEDRATICO')).toBe(true);
    expect(recibeAvisos('COORDINADOR')).toBe(false);
    expect(recibeAvisos('ADMINISTRADORA')).toBe(false);
    expect(recibeAvisos('AUDITOR')).toBe(false);
  });

  it('la decisión del coordinador manda sobre el rol', () => {
    // ────────────────────────────────────────────────────────────────────
    // Es lo que evita que una persona necesite dos cuentas.
    // ────────────────────────────────────────────────────────────────────
    //
    // Un catedrático nombrado administrador académico para que pueda emitir
    // sigue dando clases. Con dos cuentas, la bitácora registraría dos
    // identidades para un mismo humano y la confirmación de lectura la
    // firmaría la cuenta que recibe, no la que trabaja.
    expect(recibeAvisos('ADMINISTRADORA', true)).toBe(true);
    expect(recibeAvisos('COORDINADOR', true)).toBe(true);

    // Y en el otro sentido: un catedrático que no quiera recibir tampoco
    // recibe.
    expect(recibeAvisos('CATEDRATICO', false)).toBe(false);
  });

  it('sin bandera se cae al rol, y por eso no hay que migrar nada', () => {
    // Los perfiles ya creados no tienen el campo. `undefined` significa «lo
    // que diga tu rol», que es exactamente cómo se comportó el sistema hasta
    // ahora.
    expect(recibeAvisos('CATEDRATICO', undefined)).toBe(
      recibePorOmision('CATEDRATICO'),
    );
    expect(recibeAvisos('AUDITOR', undefined)).toBe(recibePorOmision('AUDITOR'));
  });
});

describe('modo TODOS', () => {
  it('son los catedráticos, más quien el coordinador haya marcado', () => {
    const r = resolverDestinatarios({ modo: 'TODOS' }, PADRON, []);
    expect(r.uids).toEqual(['ana', 'beto', 'carla', 'hilda']);
  });

  it('deja fuera a los tres roles que no reciben', () => {
    const r = resolverDestinatarios({ modo: 'TODOS' }, PADRON, []);
    for (const uid of ['elena', 'fabio', 'gaby']) {
      expect(r.uids).not.toContain(uid);
    }
  });

  it('una cuenta desactivada no recibe, y consta por qué', () => {
    // RN-10: una cuenta desactivada pierde el acceso. Seguir mandándole
    // avisos sería contradecir la propia regla.
    const r = resolverDestinatarios({ modo: 'TODOS' }, PADRON, []);
    expect(r.uids).not.toContain('dario');
    expect(r.excluidos).toContainEqual({
      uid: 'dario',
      motivo: 'CUENTA_DESACTIVADA',
    });
  });
});

describe('modo GRUPOS', () => {
  it('quien está en tres grupos recibe UNA vez', () => {
    // No es una optimización: es la diferencia entre recibir una alerta y
    // recibirla tres veces.
    const r = resolverDestinatarios(
      { modo: 'GRUPOS', gruposIds: ['g1', 'g2', 'g3'] },
      PADRON,
      [
        grupo('g1', ['ana', 'beto']),
        grupo('g2', ['ana', 'carla']),
        grupo('g3', ['ana']),
      ],
    );

    expect(r.uids.filter((u) => u === 'ana')).toHaveLength(1);
    expect(r.uids).toEqual(['ana', 'beto', 'carla']);
  });

  it('un grupo repetido dentro del mismo grupo tampoco duplica', () => {
    const r = resolverDestinatarios(
      { modo: 'GRUPOS', gruposIds: ['g1'] },
      PADRON,
      [grupo('g1', ['ana', 'ana', 'beto'])],
    );
    expect(r.uids).toEqual(['ana', 'beto']);
  });

  it('un grupo inexistente detiene el envío entero', () => {
    // Es preferible fallar a mandar un aviso a menos gente de la que se cree:
    // en un simulacro, «llegó a 20» cuando se esperaban 45 es un incidente.
    esperarCodigo(
      () =>
        resolverDestinatarios(
          { modo: 'GRUPOS', gruposIds: ['g1', 'fantasma'] },
          PADRON,
          [grupo('g1', ['ana'])],
        ),
      'GRUPO_INEXISTENTE',
    );
  });

  it('un grupo inactivo también lo detiene', () => {
    esperarCodigo(
      () =>
        resolverDestinatarios({ modo: 'GRUPOS', gruposIds: ['g1'] }, PADRON, [
          grupo('g1', ['ana'], false),
        ]),
      'GRUPO_INACTIVO',
    );
  });

  it('un miembro sin perfil se excluye con su motivo', () => {
    // Pasa cuando alguien fue borrado y quedó su UID en el grupo. No puede
    // tumbar el envío al resto, pero tampoco desaparecer en silencio.
    const r = resolverDestinatarios(
      { modo: 'GRUPOS', gruposIds: ['g1'] },
      PADRON,
      [grupo('g1', ['ana', 'fantasma'])],
    );
    expect(r.uids).toEqual(['ana']);
    expect(r.excluidos).toContainEqual({ uid: 'fantasma', motivo: 'SIN_PERFIL' });
  });



  it('NADIE que no reciba se cuela por un grupo, y consta por qué', () => {
    // Es lo que evita el limbo: si se colara, aparecería para siempre como
    // «pendiente de confirmar» en un reporte que nadie puede cerrar, porque
    // esa persona nunca va a recibir nada que confirmar.
    const r = resolverDestinatarios(
      { modo: 'GRUPOS', gruposIds: ['g1'] },
      PADRON,
      [grupo('g1', ['elena', 'fabio', 'gaby', 'ana'])],
    );

    expect(r.uids).toEqual(['ana']);
    for (const uid of ['elena', 'fabio', 'gaby']) {
      expect(r.excluidos).toContainEqual({ uid, motivo: 'ROL_NO_RECIBE' });
    }
  });
});

describe('el autor no es destinatario de su propio aviso', () => {
  it('se excluye, con su motivo', () => {
    // Su propio aviso no es algo de lo que haya que enterarse, y contarlo
    // falsearía el denominador de su propia confirmación.
    const r = resolverDestinatarios({ modo: 'TODOS' }, PADRON, [], 'ana');
    expect(r.uids).not.toContain('ana');
    expect(r.excluidos).toContainEqual({ uid: 'ana', motivo: 'ES_EL_AUTOR' });
  });

  it('sin autor declarado, nadie se excluye por eso', () => {
    const r = resolverDestinatarios({ modo: 'TODOS' }, PADRON, []);
    expect(r.uids).toContain('ana');
  });
});

describe('modo INDIVIDUAL', () => {
  it('respeta el orden en que se pidieron', () => {
    const r = resolverDestinatarios(
      { modo: 'INDIVIDUAL', usuariosIds: ['carla', 'ana'] },
      PADRON,
      [],
    );
    expect(r.uids).toEqual(['carla', 'ana']);
  });

  it('tampoco alcanza a una cuenta desactivada', () => {
    const r = resolverDestinatarios(
      { modo: 'INDIVIDUAL', usuariosIds: ['dario'] },
      PADRON,
      [],
    );
    expect(r.uids).toEqual([]);
    expect(r.excluidos).toHaveLength(1);
  });
});

describe('el conteo previo dice la verdad', () => {
  it('lo que se cuenta es exactamente lo que se envía', () => {
    // RF-USR-07 enseña el conteo ANTES de confirmar. Si contara distinto de
    // lo que luego envía, sería peor que no contar: daría confianza falsa.
    const destinatarios = { modo: 'GRUPOS' as const, gruposIds: ['g1'] };
    const grupos = [grupo('g1', ['ana', 'dario', 'beto', 'ana'])];

    const conteo = resolverDestinatarios(destinatarios, PADRON, grupos);
    const envio = resolverDestinatarios(destinatarios, PADRON, grupos);

    expect(conteo.uids).toEqual(envio.uids);
    expect(conteo.uids).toHaveLength(2);
  });
});
