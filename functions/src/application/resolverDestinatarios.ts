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

import { recibeAvisos } from '../domain/autorizacion';
import { ErrorValidacion } from '../domain/errores';
import type { Destinatarios, Rol } from '../domain/tipos';

/** Lo mínimo que hay que saber de alguien para decidir si le llega. */
export interface CandidatoDestinatario {
  readonly uid: string;
  readonly activo: boolean;
  readonly rol: Rol;
  /**
   * Decisión del coordinador sobre si esta persona recibe avisos.
   *
   * `undefined` significa «lo que diga su rol», que es cómo se comportó el
   * sistema antes de que existiera la bandera. Los perfiles antiguos no la
   * tienen y no hace falta migrarlos.
   */
  readonly recibeAvisos?: boolean;
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
  /**
   * Quién escribe el aviso. Se excluye de sus propios destinatarios.
   *
   * Antes no hacía falta porque los emisores no recibían. Con la bandera sí:
   * un administrador académico que reciba avisos y mande uno a todos se lo
   * mandaría a sí mismo y se contaría en el denominador de su propia
   * confirmación. Su propio aviso no es algo de lo que haya que enterarse.
   */
  autor: string | null = null,
): ResultadoResolucion {
  const porUid = new Map<string, CandidatoDestinatario>();
  for (const u of usuarios) {
    porUid.set(u.uid, u);
  }

  const candidatos: string[] = [];

  switch (destinatarios.modo) {
    case 'TODOS':
      // «Todos» son los catedráticos. Coordinación, administración académica
      // y auditoría trabajan SOBRE el sistema de avisos en vez de ser su
      // destino.
      candidatos.push(
        ...usuarios.filter((u) => recibeAvisos(u.rol, u.recibeAvisos)).map((u) => u.uid),
      );
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

    if (autor !== null && uid === autor) {
      excluidos.push({ uid, motivo: 'ES_EL_AUTOR' });
      continue;
    }

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

    // También en GRUPOS e INDIVIDUAL, no solo en TODOS.
    //
    // Y esto es lo que evita el limbo: quien no recibe queda fuera ANTES de
    // que se cree su entrega. Si se colara, aparecería para siempre como
    // «pendiente de confirmar» en un reporte que nadie puede cerrar, porque
    // esa persona nunca va a recibir nada que confirmar.
    //
    // Aquí la exclusión CONSTA, con su motivo, y el emisor la ve en el conteo
    // antes de enviar.
    if (!recibeAvisos(usuario.rol, usuario.recibeAvisos)) {
      excluidos.push({ uid, motivo: 'ROL_NO_RECIBE' });
      continue;
    }

    uids.push(uid);
  }

  return { uids, excluidos };
}
