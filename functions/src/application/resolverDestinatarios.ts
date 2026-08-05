/**
 * SIAN — Resolución de destinatarios (RF-USR-07, RF-ENT-01).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Función pura. No sabe que existe Firestore.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Recibe la gente y los grupos ya leídos, y decide quién recibe. Separarlo así
 * permite probar la regla que más importa —**a quién le llega un aviso de
 * emergencia**— sin levantar nada, y con casos que en producción costaría
 * provocar: un grupo con miembros repetidos, un miembro desactivado, alguien
 * que está en tres grupos a la vez.
 *
 * La deduplicación no es una optimización: es la diferencia entre recibir una
 * alerta y recibirla tres veces. Quien esté en «Docentes», «Ingeniería» y
 * «Coordinadores» debe recibir un solo aviso.
 */

import { ErrorValidacion } from '../domain/errores';
import type { Destinatarios, Rol } from '../domain/tipos';

/** Lo mínimo que hay que saber de alguien para decidir si le llega. */
export interface CandidatoDestinatario {
  readonly uid: string;
  readonly activo: boolean;
  readonly rol: Rol;
}

export interface GrupoResuelto {
  readonly id: string;
  readonly activo: boolean;
  readonly miembros: readonly string[];
}

export interface ResultadoResolucion {
  /** UIDs finales, sin repeticiones y en orden estable. */
  readonly uids: readonly string[];
  /** Quiénes quedaron fuera y por qué. Se registra en bitácora (RF-BIT-02). */
  readonly excluidos: readonly { uid: string; motivo: string }[];
}

/**
 * ¿Quién recibe este mensaje?
 *
 * Un usuario desactivado **no** recibe: RN-10 dice que una cuenta desactivada
 * pierde el acceso, y mandarle avisos sería contradecirlo. Se deja constancia
 * de la exclusión en vez de descartarlo en silencio, porque al emisor le sirve
 * saber que su aviso llegó a 42 y no a los 45 que esperaba.
 */
export function resolverDestinatarios(
  destinatarios: Destinatarios,
  usuarios: readonly CandidatoDestinatario[],
  grupos: readonly GrupoResuelto[],
): ResultadoResolucion {
  const porUid = new Map<string, CandidatoDestinatario>();
  for (const u of usuarios) {
    porUid.set(u.uid, u);
  }

  const candidatos: string[] = [];

  switch (destinatarios.modo) {
    case 'TODOS':
      // «Todos» son los catedráticos: un aviso institucional no se le manda a
      // la coordinación, que es quien lo escribe.
      candidatos.push(...usuarios.filter((u) => u.rol === 'CATEDRATICO').map((u) => u.uid));
      break;

    case 'GRUPOS': {
      const pedidos = new Set(destinatarios.gruposIds ?? []);
      const encontrados = new Set(grupos.map((g) => g.id));

      for (const id of pedidos) {
        if (!encontrados.has(id)) {
          throw new ErrorValidacion(
            'GRUPO_INEXISTENTE',
            `El grupo «${id}» no existe. No se envía nada: es preferible fallar a mandar un aviso a menos gente de la que se cree.`,
            { grupoId: id },
          );
        }
      }

      for (const g of grupos) {
        if (!pedidos.has(g.id)) {
          continue;
        }
        if (!g.activo) {
          throw new ErrorValidacion(
            'GRUPO_INACTIVO',
            `El grupo «${g.id}» está inactivo.`,
            { grupoId: g.id },
          );
        }
        candidatos.push(...g.miembros);
      }
      break;
    }

    case 'INDIVIDUAL':
      candidatos.push(...(destinatarios.usuariosIds ?? []));
      break;
  }

  const uids: string[] = [];
  const excluidos: { uid: string; motivo: string }[] = [];
  const yaVistos = new Set<string>();

  for (const uid of candidatos) {
    // Estar en tres grupos no puede significar tres notificaciones.
    if (yaVistos.has(uid)) {
      continue;
    }
    yaVistos.add(uid);

    const usuario = porUid.get(uid);

    if (usuario === undefined) {
      excluidos.push({ uid, motivo: 'SIN_PERFIL' });
      continue;
    }
    if (!usuario.activo) {
      // RN-10: una cuenta desactivada pierde el acceso. Seguir mandándole
      // avisos sería contradecir la propia regla.
      excluidos.push({ uid, motivo: 'CUENTA_DESACTIVADA' });
      continue;
    }

    uids.push(uid);
  }

  return { uids, excluidos };
}
