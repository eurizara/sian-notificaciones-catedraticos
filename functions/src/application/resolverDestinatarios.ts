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
import { SEDE_INICIAL, membresiasDe, sedeDelDocumento } from '../domain/sede';
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
  /**
   * Sus sedes, con su rol y sus facultades en cada una (2.0). Sin el campo, la
   * sede inicial con `rol`: un perfil de antes de la migración.
   */
  readonly membresias?: unknown;
}

export interface GrupoResuelto {
  readonly id: string;
  readonly activo: boolean;
  readonly miembros: readonly string[];
  /** Sin el campo, la sede inicial (2.0). */
  readonly sedeId?: string;
  /**
   * La facultad del grupo (RF-FAC-03). Con ella, solo recibe el miembro que
   * hoy tiene esa facultad en la sede (2.0.7): si se la quitaron, el grupo no
   * se la vuelve a dar por la puerta de atrás.
   */
  readonly facultadId?: string | null;
}

/** Una facultad del catálogo de la sede, ya leída (RF-FAC-02). */
export interface FacultadResuelta {
  readonly id: string;
  readonly activa: boolean;
}

/** El rol y las facultades de alguien EN esta sede, o `null` si no pertenece. */
function enSede(
  u: CandidatoDestinatario,
  sedeId: string,
): { rol: Rol; facultades: readonly string[] } | null {
  const m = membresiasDe(u)[sedeId];
  return m === undefined ? null : m;
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
  /**
   * La sede desde la que se envía (2.0). Todo se resuelve DENTRO de ella:
   * «todos» son los de esta sede (RF-SED-03), un grupo de otra sede se rechaza,
   * y una persona de otra sede elegida a mano queda fuera, con su motivo
   * (RF-SED-05). Por omisión la inicial, que es como se comportó siempre.
   */
  sedeId: string = SEDE_INICIAL,
  /** Las facultades del catálogo de la sede, para el modo `FACULTAD`. */
  facultades: readonly FacultadResuelta[] = [],
): ResultadoResolucion {
  const porUid = new Map<string, CandidatoDestinatario>();
  for (const u of usuarios) {
    porUid.set(u.uid, u);
  }

  const candidatos: string[] = [];
  /** uid → facultades que le exigen sus grupos; `null`: ninguna (2.0.7). */
  const facultadExigida = new Map<string, Set<string> | null>();

  switch (destinatarios.modo) {
    case 'TODOS':
      // «Todos» son los catedráticos DE ESTA SEDE. Coordinación, administración
      // académica y auditoría trabajan SOBRE el sistema de avisos en vez de ser
      // su destino. Se mira el rol en esta sede: alguien puede coordinar en
      // otra y dar clases aquí.
      candidatos.push(
        ...usuarios
          .filter((u) => {
            const m = enSede(u, sedeId);
            return m !== null && recibeAvisos(m.rol, u.recibeAvisos);
          })
          .map((u) => u.uid),
      );
      break;

    case 'FACULTAD': {
      // Como con los grupos: una facultad que no existe o está inactiva hace
      // fallar el envío. Mandar a menos gente de la que se cree es peor que no
      // mandar.
      const pedidas = new Set(destinatarios.facultadesIds ?? []);
      const porId = new Map(facultades.map((f) => [f.id, f]));
      for (const id of pedidas) {
        const f = porId.get(id);
        if (f === undefined) {
          throw new ErrorValidacion(
            'FACULTAD_INEXISTENTE',
            `La facultad «${id}» no existe en esta sede. No se envía nada.`,
            { facultadId: id, sedeId },
          );
        }
        if (!f.activa) {
          throw new ErrorValidacion('FACULTAD_INACTIVA', `La facultad «${id}» está inactiva.`, {
            facultadId: id,
            sedeId,
          });
        }
      }
      candidatos.push(
        ...usuarios
          .filter((u) => enSede(u, sedeId)?.facultades.some((f) => pedidas.has(f)) === true)
          .map((u) => u.uid),
      );
      break;
    }

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
        if (sedeDelDocumento(g) !== sedeId) {
          throw new ErrorValidacion(
            'GRUPO_DE_OTRA_SEDE',
            `El grupo «${g.id}» es de otra sede.`,
            { grupoId: g.id, sedeId },
          );
        }
        if (!g.activo) {
          throw new ErrorValidacion(
            'GRUPO_INACTIVO',
            `El grupo «${g.id}» está inactivo.`,
            { grupoId: g.id },
          );
        }
        candidatos.push(...g.miembros);
        // 2.0.7: quién exige facultad. Basta un grupo sin facultad que lo
        // incluya para que no se le exija ninguna.
        const f = g.facultadId ?? null;
        for (const m of g.miembros) {
          const previa = facultadExigida.get(m);
          if (!facultadExigida.has(m)) {
            facultadExigida.set(m, f === null ? null : new Set([f]));
          } else if (previa !== null && previa !== undefined) {
            if (f === null) {
              facultadExigida.set(m, null);
            } else {
              previa.add(f);
            }
          }
        }
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

    // RF-SED-05: alguien de otra sede no recibe, aunque esté en un grupo o se
    // haya elegido a mano. Consta, para que el emisor lo vea en el conteo.
    const membresia = enSede(usuario, sedeId);
    if (membresia === null) {
      excluidos.push({ uid, motivo: 'OTRA_SEDE' });
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
    if (!recibeAvisos(membresia.rol, usuario.recibeAvisos)) {
      excluidos.push({ uid, motivo: 'ROL_NO_RECIBE' });
      continue;
    }

    // 2.0.7: en un grupo de una facultad, quien ya no la tiene en esta sede.
    const exigidas = facultadExigida.get(uid);
    if (exigidas !== null && exigidas !== undefined && !membresia.facultades.some((f) => exigidas.has(f))) {
      excluidos.push({ uid, motivo: 'FUERA_DE_LA_FACULTAD' });
      continue;
    }

    uids.push(uid);
  }

  return { uids, excluidos };
}

/** Una persona que se puede elegir como destinataria (U-6). */
export interface PersonaElegible {
  readonly uid: string;
  readonly nombre: string;
  readonly correo: string;
}

/**
 * A quién se puede mandar un aviso individual (U-6, RF-USR-06).
 *
 * **El mismo criterio que `resolverDestinatarios`**: activo, que reciba
 * avisos, y que no sea quien escribe. Si el selector ofreciera a alguien que
 * el envío luego descarta, el aviso llegaría a menos gente de la que se ve en
 * pantalla, que es justo lo que la confirmación con nombres quiere evitar.
 *
 * Solo nombre y correo: es lo que hace falta para elegir, y no expone el
 * resto del perfil a quien redacta.
 */
export function personasElegibles(
  usuarios: readonly (CandidatoDestinatario & { nombre?: string; correo?: string })[],
  autor: string,
  sedeId: string = SEDE_INICIAL,
): PersonaElegible[] {
  return usuarios
    .filter((u) => {
      const m = enSede(u, sedeId);
      return u.uid !== autor && u.activo && m !== null && recibeAvisos(m.rol, u.recibeAvisos);
    })
    .map((u) => ({ uid: u.uid, nombre: (u.nombre ?? '').trim(), correo: (u.correo ?? '').trim() }))
    .sort((a, b) => (a.nombre || a.correo).localeCompare(b.nombre || b.correo, 'es'));
}

