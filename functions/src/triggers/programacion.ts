/**
 * SIAN — Programación de mensajes (RF-PRG-02..11).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Las fechas se guardan en UTC y se muestran en hora institucional.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * RN-05 y RF-PRG-03. No es purismo: un simulacro programado «a las 7:00» tiene
 * que dispararse a las 7:00 de Guatemala aunque el servidor esté en otro
 * continente y aunque quien lo programó viaje. Guardar la hora local sin zona
 * es cómo se llega a que un aviso salga a medianoche.
 */

import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';

import {
  MARGEN_PASADO_SEGUNDOS,
  validarFechaFutura,
} from '../application/despacho';
import { crearAsiento } from '../domain/bitacora';
import { exigirPermiso, type Sujeto } from '../domain/autorizacion';
import { ErrorAutorizacion, ErrorDominio } from '../domain/errores';
import { MensajeFactory, prioridadDeDespacho } from '../domain/mensaje';
import { calcularProximasOcurrencias } from '../domain/recurrencia/planificacion';
import type {
  Adjuntos,
  Destinatarios,
  Programacion,
  Recurrencia,
  Rol,
  TipoMensaje,
} from '../domain/tipos';
import { FieldValue, OPCIONES_FUNCION, RUTAS, aTimestamp, db } from '../infrastructure/firebase';
import { escribirAsiento } from '../infrastructure/repositorios';

const ZONA_INSTITUCIONAL = 'America/Guatemala';

function sujetoDe(peticion: {
  auth?: { uid: string; token: Record<string, unknown> };
}): Sujeto {
  if (!peticion.auth) {
    throw new HttpsError('unauthenticated', 'Hay que iniciar sesión.');
  }
  return {
    uid: peticion.auth.uid,
    rol: (peticion.auth.token.rol as Rol | undefined) ?? 'CATEDRATICO',
    activo: peticion.auth.token.activo === true,
    puedeEmitirUrgentes: peticion.auth.token.puedeEmitirUrgentes === true,
    puedeCrearRecurrentes: peticion.auth.token.puedeCrearRecurrentes === true,
  };
}

/**
 * Vista previa de las próximas ocurrencias (RF-PRG-09).
 *
 * Se enseña **antes** de guardar porque un patrón de recurrencia es difícil de
 * leer y fácil de equivocar: «cada 2 días a las 7:00, lunes y miércoles»
 * suena claro hasta que se ven las fechas reales y resulta que la primera cae
 * en domingo. Diez fechas concretas contestan lo que ninguna descripción
 * contesta.
 *
 * No escribe nada: es un cálculo puro expuesto por la red.
 */
export const vistaPreviaOcurrencias = onCall(OPCIONES_FUNCION, async (peticion) => {
  const sujeto = sujetoDe(peticion);

  try {
    exigirPermiso(sujeto, 'PROGRAMAR_ENVIO');

    const { recurrencia } = peticion.data as { recurrencia?: Recurrencia };
    if (!recurrencia) {
      throw new HttpsError('invalid-argument', 'Falta el patrón de recurrencia.');
    }

    const ocurrencias = calcularProximasOcurrencias(recurrencia, ZONA_INSTITUCIONAL);

    return {
      ocurrencias: ocurrencias.map((o) => ({
        numero: o.numero,
        previstaPara: o.previstaPara.toISOString(),
        previstaParaLocal: o.previstaParaLocal,
      })),
      // Que salgan menos de las pedidas no es un fallo: significa que el
      // patrón se agota antes, y saberlo aquí evita programar algo que no va
      // a repetirse tanto como se cree.
      agotaAntes: ocurrencias.length < 10,
    };
  } catch (e) {
    throw traducir(e);
  }
});

interface PeticionProgramar {
  titulo?: string;
  cuerpo?: string;
  tipo?: TipoMensaje;
  requiereConfirmacion?: boolean;
  destinatarios?: Destinatarios;
  confirmacionUrgente?: boolean;
  mensajeId?: string;
  adjuntos?: Adjuntos;
  /** ISO 8601 en UTC. Para modo UNICO. */
  ejecutarEn?: string;
  recurrencia?: Recurrencia;
}

/**
 * Programa un mensaje para más tarde (RF-PRG-02) o de forma recurrente
 * (RF-PRG-05).
 *
 * No despacha: encola. El despachador es quien decide, cada minuto, qué toca
 * salir. Separarlo así es lo que permite suspender, reanudar y cancelar sin
 * tocar el mensaje, y lo que hace que un reinicio no pierda nada.
 */
export const programarMensaje = onCall(OPCIONES_FUNCION, async (peticion) => {
  const sujeto = sujetoDe(peticion);
  const datos = peticion.data as PeticionProgramar;
  const correo = (peticion.auth?.token.email as string | undefined) ?? '';

  try {
    const tipo = datos.tipo ?? 'INFORMATIVO';
    const esRecurrente = datos.recurrencia !== undefined;

    exigirPermiso(sujeto, 'PROGRAMAR_ENVIO');
    exigirPermiso(
      sujeto,
      tipo === 'URGENTE' ? 'CREAR_ALERTA_URGENTE' : 'CREAR_AVISO_INFORMATIVO',
    );
    if (esRecurrente) {
      exigirPermiso(sujeto, 'CREAR_RECURRENTE');
    }
    if (datos.requiereConfirmacion === true) {
      exigirPermiso(sujeto, 'EXIGIR_CONFIRMACION');
    }
    if (datos.adjuntos?.audio || datos.adjuntos?.imagen) {
      exigirPermiso(sujeto, 'ADJUNTAR_MULTIMEDIA');
    }

    // RN-06: la doble confirmación se exige aquí también, no solo al enviar
    // ya. Una urgente programada suena igual de fuerte cuando llega.
    if (tipo === 'URGENTE' && datos.confirmacionUrgente !== true) {
      throw new ErrorAutorizacion(
        'FALTA_CONFIRMACION_URGENTE',
        'Una alerta urgente exige una segunda confirmación explícita (RN-06).',
      );
    }

    const destinatarios = datos.destinatarios;
    if (!destinatarios) {
      throw new HttpsError('invalid-argument', 'Faltan los destinatarios.');
    }

    const programacion: Programacion = esRecurrente
      ? {
          modo: 'RECURRENTE',
          zonaHoraria: ZONA_INSTITUCIONAL,
          recurrencia: datos.recurrencia,
        }
      : {
          modo: 'UNICO',
          zonaHoraria: ZONA_INSTITUCIONAL,
          ejecutarEn: datos.ejecutarEn ?? '',
        };

    // La fábrica valida el contenido y la coherencia de la programación.
    const mensaje = MensajeFactory.crear({
      titulo: datos.titulo ?? '',
      cuerpo: datos.cuerpo ?? '',
      tipo,
      adjuntos: datos.adjuntos,
      requiereConfirmacion: datos.requiereConfirmacion ?? false,
      destinatarios,
      programacion,
      creadoPor: sujeto.uid,
    });

    // Primera ocurrencia: la fecha pedida, o la que calcule el patrón.
    let primera: Date;
    if (esRecurrente) {
      const proximas = calcularProximasOcurrencias(
        datos.recurrencia!,
        ZONA_INSTITUCIONAL,
        1,
      );
      if (proximas.length === 0) {
        throw new ErrorAutorizacion(
          'RECURRENCIA_SIN_OCURRENCIAS',
          'Ese patrón no produce ninguna fecha. Revisa el rango, los días y la hora.',
        );
      }
      primera = proximas[0]!.previstaPara;
    } else {
      primera = new Date(datos.ejecutarEn ?? '');
      // RF-PRG-04.
      validarFechaFutura(primera);
    }

    const refMensaje = datos.mensajeId
      ? db.collection(RUTAS.mensajes).doc(datos.mensajeId)
      : db.collection(RUTAS.mensajes).doc();

    await refMensaje.create({
      ...mensaje,
      creadoEn: aTimestamp(mensaje.creadoEn),
      estado: 'PROGRAMADO',
      // Los destinatarios se resuelven al despachar, no ahora: entre hoy y el
      // día del envío puede entrar o salir gente, y lo que importa es quién
      // está cuando el aviso sale.
      destinatariosUids: [],
      totalDestinatarios: 0,
      resumenEntrega: { entregados: 0, fallidos: 0, abiertos: 0, confirmados: 0 },
      enviadoEn: null,
      proximaOcurrencia: aTimestamp(primera),
    });

    await encolar(refMensaje.id, primera, prioridadDeDespacho(tipo), 1);

    await escribirAsiento(
      crearAsiento({
        tipo: 'MENSAJE_PROGRAMADO',
        actor: { uid: sujeto.uid, correo, rol: sujeto.rol },
        entidad: 'MENSAJE',
        entidadId: refMensaje.id,
        resumen: esRecurrente
          ? `«${mensaje.titulo}» programado de forma recurrente, primera vez el ${primera.toISOString()}`
          : `«${mensaje.titulo}» programado para el ${primera.toISOString()}`,
        datos: {
          tipo,
          modo: programacion.modo,
          primeraOcurrencia: primera.toISOString(),
          zonaHoraria: ZONA_INSTITUCIONAL,
        },
        origen: 'PANEL_WEB',
      }),
    );

    return {
      mensajeId: refMensaje.id,
      primeraOcurrencia: primera.toISOString(),
      modo: programacion.modo,
    };
  } catch (e) {
    throw traducir(e);
  }
});

/**
 * Suspende, reanuda o cancela una programación (RF-PRG-10, RF-PRG-11).
 *
 * Suspender y cancelar no son lo mismo y no se pueden confundir: suspender
 * detiene una recurrencia dejándola lista para volver; cancelar la termina
 * para siempre. La segunda es irreversible, así que la interfaz la pide dos
 * veces y aquí se comprueba el estado antes de tocar nada.
 */
export const cambiarProgramacion = onCall(OPCIONES_FUNCION, async (peticion) => {
  const sujeto = sujetoDe(peticion);
  const correo = (peticion.auth?.token.email as string | undefined) ?? '';
  const { mensajeId, accion } = peticion.data as {
    mensajeId?: string;
    accion?: 'SUSPENDER' | 'REANUDAR' | 'CANCELAR';
  };

  try {
    if (!mensajeId || !accion) {
      throw new HttpsError('invalid-argument', 'Faltan el mensaje o la acción.');
    }

    const ref = db.collection(RUTAS.mensajes).doc(mensajeId);
    const doc = await ref.get();

    if (!doc.exists) {
      throw new HttpsError('not-found', 'Ese mensaje no existe.');
    }

    // Alcance PROPIO para la administradora: solo sobre lo que ella creó.
    exigirPermiso(sujeto, 'CANCELAR_PROGRAMACION', {
      creadoPor: (doc.get('creadoPor') as string | undefined) ?? '',
    });

    const estado = doc.get('estado') as string;
    if (estado === 'ENVIADO' || estado === 'ENVIADO_CON_FALLOS') {
      // RN-03. Un mensaje que ya salió no se desprograma: ya lo recibieron.
      throw new ErrorAutorizacion(
        'MENSAJE_YA_ENVIADO',
        'Ese mensaje ya se envió. Lo enviado no se cancela ni se edita.',
      );
    }

    const nuevoEstado = accion === 'CANCELAR'
      ? 'CANCELADO'
      : accion === 'SUSPENDER'
        ? 'SUSPENDIDO'
        : 'PROGRAMADO';

    await ref.update({
      estado: nuevoEstado,
      ...(doc.get('programacion.modo') === 'RECURRENTE'
        ? { 'programacion.recurrencia.suspendida': accion === 'SUSPENDER' }
        : {}),
    });

    // Los ítems pendientes se retiran de la cola: dejarlos ahí obligaría al
    // despachador a comprobar el estado del mensaje en cada ciclo.
    const pendientes = await db
      .collection(RUTAS.colaDespacho)
      .where('mensajeId', '==', mensajeId)
      .where('estado', '==', 'PENDIENTE')
      .get();

    const lote = db.batch();
    for (const item of pendientes.docs) {
      if (accion === 'REANUDAR') {
        lote.update(item.ref, { estado: 'PENDIENTE' });
      } else {
        lote.update(item.ref, { estado: 'FALLIDO', motivo: accion });
      }
    }
    await lote.commit();

    await escribirAsiento(
      crearAsiento({
        tipo: accion === 'CANCELAR'
          ? 'MENSAJE_CANCELADO'
          : accion === 'SUSPENDER'
            ? 'MENSAJE_SUSPENDIDO'
            : 'MENSAJE_REANUDADO',
        actor: { uid: sujeto.uid, correo, rol: sujeto.rol },
        entidad: 'MENSAJE',
        entidadId: mensajeId,
        resumen: `«${doc.get('titulo') as string}» — ${accion.toLowerCase()}`,
        datos: { accion, estadoAnterior: estado, estadoNuevo: nuevoEstado },
        origen: 'PANEL_WEB',
      }),
    );

    return { mensajeId, estado: nuevoEstado };
  } catch (e) {
    throw traducir(e);
  }
});

/** Encola una ocurrencia para que el despachador la recoja. */
export async function encolar(
  mensajeId: string,
  ejecutarEn: Date,
  prioridad: number,
  numeroOcurrencia: number,
): Promise<void> {
  // El identificador es determinista: mensaje + número de ocurrencia. Dos
  // ejecuciones que intenten encolar la misma ocurrencia escriben el mismo
  // documento en vez de crear dos, que es la mitad de RF-PRG-12.
  const id = `${mensajeId}_${numeroOcurrencia}`;

  await db.collection(RUTAS.colaDespacho).doc(id).set({
    mensajeId,
    ocurrenciaId: `${numeroOcurrencia}`,
    numeroOcurrencia,
    ejecutarEn: aTimestamp(ejecutarEn),
    estado: 'PENDIENTE',
    intentos: 0,
    bloqueoHasta: null,
    prioridad,
    creadoEn: FieldValue.serverTimestamp(),
  });
}

function traducir(e: unknown): HttpsError {
  if (e instanceof HttpsError) {
    return e;
  }
  if (e instanceof ErrorAutorizacion) {
    return new HttpsError('permission-denied', e.message, { codigo: e.codigo });
  }
  if (e instanceof ErrorDominio) {
    return new HttpsError('invalid-argument', e.message, { codigo: e.codigo });
  }
  logger.error('Fallo en la programación', { error: String(e) });
  return new HttpsError('internal', 'No se pudo completar la operación.');
}

export { MARGEN_PASADO_SEGUNDOS };
