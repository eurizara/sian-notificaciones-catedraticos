/**
 * SIAN — Lista blanca institucional (RF-AUT-03, RF-USR-01).
 *
 * La invitación es lo único que abre la puerta del sistema. No hay registro
 * abierto: alguien puede crearse una credencial en el proveedor de identidad,
 * pero sin invitación no obtiene perfil, ni rol, ni acceso a un solo documento.
 *
 * Que el identificador del documento **sea** el correo normalizado
 * (documento 05, sección 2.10) no es un detalle de almacenamiento: garantiza
 * unicidad sin necesidad de consulta, y convierte «¿está autorizado?» en una
 * sola lectura por clave.
 */

import { ErrorValidacion } from './errores';
import { CorreoInstitucional } from './objetosDeValor';
import { ROLES, type Rol } from './tipos';

export interface Invitacion {
  /** Correo normalizado. Es también el identificador del documento. */
  readonly correo: string;
  readonly rolAsignado: Rol;
  readonly nombre: string;
  readonly consumida: boolean;
  readonly consumidaPor?: string;
  readonly creadaPor: string;
  readonly creadaEn: Date;
}

export interface EntradaInvitacion {
  readonly correo: string;
  readonly rolAsignado: string;
  readonly nombre?: string;
  readonly creadaPor: string;
  readonly creadaEn?: Date;
}

/** Máximo de invitaciones por carga masiva (RF-USR-01). */
export const MAX_INVITACIONES_POR_CARGA = 500;

export function crearInvitacion(entrada: EntradaInvitacion): Invitacion {
  const correo = CorreoInstitucional.crear(entrada.correo);

  const rol = (entrada.rolAsignado ?? '').trim().toUpperCase() as Rol;
  if (!ROLES.includes(rol)) {
    throw new ErrorValidacion(
      'ROL_INVALIDO',
      `Rol desconocido: «${entrada.rolAsignado}». Se espera ${ROLES.join(', ')}.`,
      { rolRecibido: entrada.rolAsignado },
    );
  }

  if (!entrada.creadaPor) {
    throw new ErrorValidacion(
      'CREADOR_OBLIGATORIO',
      'Toda invitación debe registrar quién la creó (RF-BIT-02).',
    );
  }

  return Object.freeze({
    correo: correo.valor,
    rolAsignado: rol,
    nombre: (entrada.nombre ?? '').trim(),
    consumida: false,
    creadaPor: entrada.creadaPor,
    creadaEn: entrada.creadaEn ?? new Date(),
  });
}

/** Qué hacer con un correo que llega en una carga. */
export type DestinoCarga = 'CREAR' | 'ACTUALIZAR' | 'NO_TOCAR';

/** Lo que la lista blanca ya sabía de ese correo. */
export interface EstadoEnLista {
  readonly existe: boolean;
  readonly consumida: boolean;
}

/**
 * Decide qué hacer con un correo que vuelve a llegar en una carga (RF-USR-01).
 *
 * ────────────────────────────────────────────────────────────────────────────
 * A quien YA ENTRÓ no se le toca la invitación.
 * ────────────────────────────────────────────────────────────────────────────
 *
 * Los tres casos no son el mismo suceso, y tratarlos igual fue el defecto:
 *
 *   · No existe        → se crea. Es un alta de verdad.
 *   · Existe sin usar  → se actualizan rol y nombre. Corregir una lista antes
 *                        de que la gente entre es legítimo y frecuente: se
 *                        equivocó una tilde, o alguien pasa de catedrático a
 *                        coordinación antes de su primer acceso.
 *   · Existe y ya usó  → no se toca nada. Su rol de verdad vive en su perfil y
 *                        en sus claims, no aquí: cambiarlo en la invitación no
 *                        se lo cambia a la persona, solo deja a los dos sitios
 *                        diciendo cosas distintas. Se cambia desde la pantalla
 *                        de usuarios, que sí mueve las dos.
 *
 * Antes, una recarga escribía `consumida: false` sobre quien ya había entrado.
 * El documento quedaba contradiciéndose —`consumida` en falso junto a su
 * `consumidaPor` y su `consumidaEn`— y con eso se desarmaba la comprobación de
 * `decidirActivacion` que rechaza a quien intenta usar una invitación que otro
 * ya consumió.
 */
export function decidirCarga(actual: EstadoEnLista): DestinoCarga {
  if (!actual.existe) {
    return 'CREAR';
  }
  return actual.consumida ? 'NO_TOCAR' : 'ACTUALIZAR';
}

/** Resultado de interpretar una línea del CSV de carga masiva. */
export interface LineaCsv {
  readonly numero: number;
  readonly invitacion?: Invitacion;
  readonly error?: string;
}

export interface ResultadoCsv {
  readonly validas: readonly Invitacion[];
  readonly rechazadas: readonly LineaCsv[];
}

/**
 * Interpreta un CSV de carga masiva (RF-USR-01).
 *
 * Formato esperado, con o sin fila de encabezado:
 *
 *     correo,rol,nombre
 *     ana.perez@umg.edu.gt,CATEDRATICO,Ana Pérez
 *
 * Una línea inválida **no aborta la carga**: se rechaza esa sola y se informa
 * con su número de línea y el motivo. Descartar 300 correos buenos por una
 * coma de más sería la peor forma posible de tratar a quien carga la lista.
 */
export function interpretarCsv(contenido: string, creadaPor: string): ResultadoCsv {
  const lineas = contenido
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  if (lineas.length === 0) {
    throw new ErrorValidacion('CSV_VACIO', 'El archivo no tiene ninguna línea con contenido.');
  }

  // Encabezado opcional: se detecta por la primera columna.
  const primera = (lineas[0] ?? '').toLowerCase();
  const cuerpo = primera.startsWith('correo') ? lineas.slice(1) : lineas;

  if (cuerpo.length > MAX_INVITACIONES_POR_CARGA) {
    throw new ErrorValidacion(
      'CSV_DEMASIADO_GRANDE',
      `La carga masiva admite hasta ${MAX_INVITACIONES_POR_CARGA} líneas; llegaron ${cuerpo.length}.`,
      { lineas: cuerpo.length, maximo: MAX_INVITACIONES_POR_CARGA },
    );
  }

  const validas: Invitacion[] = [];
  const rechazadas: LineaCsv[] = [];
  const vistos = new Set<string>();
  const desplazamiento = primera.startsWith('correo') ? 2 : 1;

  cuerpo.forEach((linea, indice) => {
    const numero = indice + desplazamiento;
    const campos = linea.split(',').map((c) => c.trim());
    const [correo, rol, nombre] = campos;

    try {
      const invitacion = crearInvitacion({
        correo: correo ?? '',
        rolAsignado: rol ?? '',
        nombre: nombre ?? '',
        creadaPor,
      });

      // Un correo repetido dentro del mismo archivo se rechaza en lugar de
      // sobrescribirse en silencio: puede ser un error de copiado con dos
      // roles distintos, y adivinar cuál gana sería inventar.
      if (vistos.has(invitacion.correo)) {
        rechazadas.push({ numero, error: `Correo repetido en el archivo: ${invitacion.correo}` });
        return;
      }

      vistos.add(invitacion.correo);
      validas.push(invitacion);
    } catch (e) {
      rechazadas.push({
        numero,
        error: e instanceof Error ? e.message : 'Línea no interpretable',
      });
    }
  });

  return { validas, rechazadas };
}
