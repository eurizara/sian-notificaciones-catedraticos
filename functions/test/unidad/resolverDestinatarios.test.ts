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
];

describe('modo TODOS', () => {
  it('son los catedráticos, no todo el mundo', () => {
    // Un aviso institucional no se le manda a la coordinación, que es quien
    // lo escribe.
    const r = resolverDestinatarios({ modo: 'TODOS' }, PADRON, []);
    expect(r.uids).toEqual(['ana', 'beto', 'carla']);
    expect(r.uids).not.toContain('elena');
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

  it('un grupo puede incluir a quien no es catedrático', () => {
    // A diferencia de TODOS: si alguien puso a la coordinadora en un grupo,
    // fue a propósito.
    const r = resolverDestinatarios(
      { modo: 'GRUPOS', gruposIds: ['g1'] },
      PADRON,
      [grupo('g1', ['elena'])],
    );
    expect(r.uids).toEqual(['elena']);
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
