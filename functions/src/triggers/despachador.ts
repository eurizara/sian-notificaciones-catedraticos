/**
 * SIAN — Despachador programado (RF-PRG-12, 13, 14 · RES-04).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Un aviso que sale dos veces destruye más confianza que uno que no sale.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Corre cada minuto y **puede solaparse consigo mismo**: Cloud Scheduler no
 * garantiza ejecución única y una Function puede reintentarse sola. Si dos
 * ejecuciones toman la misma ocurrencia, el simulacro se anuncia dos veces y
 * la siguiente vez nadie se lo cree.
 *
 * De ahí las tres defensas, en capas:
 *
 *   1. **Identificador determinista** del ítem: `mensaje_ocurrencia`. Encolar
 *      dos veces escribe el mismo documento, no crea dos.
 *   2. **Transacción de bloqueo** al tomarlo. La segunda ejecución lo ve
 *      TOMADO con bloqueo vigente y lo deja pasar.
 *   3. **Bloqueo con vencimiento**, de cinco minutos. Sin él, una ejecución
 *      que muriera a mitad dejaría el aviso encallado para siempre y nadie se
 *      enteraría hasta que alguien preguntara por qué no llegó.
 *
 * Un job de Cloud Scheduler para todo el sistema, no uno por mensaje: el plan
 * gratuito incluye tres, y uno por mensaje se agotaría al cuarto (deuda DT-05,
 * aceptada de forma permanente).
 */

import { onSchedule } from 'firebase-functions/v2/scheduler';
import type { DocumentReference, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';

import {
  MAX_INTENTOS,
  bloqueoHasta,
  decidirSobreItem,
  ordenarLote,
  type ItemCola,
} from '../application/despacho';
import { crearAsiento } from '../domain/bitacora';
import { ACTOR_SISTEMA } from '../domain/bitacora';
import { prioridadDeDespacho } from '../domain/mensaje';
import {
  calcularProximasOcurrencias,
  decidirDespacho,
  desviacionSegundos,
  recurrenciaAgotada,
  recurrenciaSuspendida,
} from '../domain/recurrencia/planificacion';
import type { Recurrencia, TipoMensaje } from '../domain/tipos';
import { FieldValue, RUTAS, aTimestamp, db } from '../infrastructure/firebase';
import { escribirAsiento } from '../infrastructure/repositorios';
import { despacharMensaje } from './envio';
import { encolar } from './programacion';

const ZONA_INSTITUCIONAL = 'America/Guatemala';

/** Cuántos ítems por ciclo. Con más, el minuto se queda corto. */
const MAX_POR_CICLO = 20;

export const despachador = onSchedule(
  {
    // RNF-04 admite hasta 60 segundos de desviación, que es exactamente lo
    // que cuesta esta cadencia (DT-05).
    schedule: 'every 1 minutes',
    timeZone: ZONA_INSTITUCIONAL,
    region: 'us-central1',
    memory: '512MiB',
    timeoutSeconds: 300,
    retryCount: 0,
  },
  async () => {
    const ahora = new Date();

    const pendientes = await db
      .collection(RUTAS.colaDespacho)
      .where('estado', 'in', ['PENDIENTE', 'TOMADO'])
      .where('ejecutarEn', '<=', aTimestamp(ahora))
      .limit(MAX_POR_CICLO * 3)
      .get();

    if (pendientes.empty) {
      return;
    }

    const items: ItemCola[] = pendientes.docs.map((d) => ({
      id: d.id,
      estado: d.get('estado'),
      ejecutarEn: (d.get('ejecutarEn') as Timestamp).toDate(),
      intentos: (d.get('intentos') as number | undefined) ?? 0,
      bloqueoHasta:
        (d.get('bloqueoHasta') as Timestamp | null)?.toDate() ?? null,
      prioridad: (d.get('prioridad') as number | undefined) ?? 0,
    }));

    // Urgentes primero, y dentro de cada prioridad las más atrasadas antes.
    // Con doscientos avisos encolados, el orden decide cuál sale ya.
    const lote = ordenarLote(items).slice(0, MAX_POR_CICLO);

    logger.info('Ciclo de despacho', { candidatos: items.length, lote: lote.length });

    for (const item of lote) {
      try {
        await procesar(item, ahora);
      } catch (e) {
        // Un ítem que falla no puede tumbar el ciclo: los demás siguen.
        logger.error('Fallo procesando ítem de la cola', {
          item: item.id,
          error: String(e),
        });
      }
    }
  },
);

async function procesar(item: ItemCola, ahora: Date): Promise<void> {
  const ref = db.collection(RUTAS.colaDespacho).doc(item.id);

  // ── Defensa 2: tomar el ítem dentro de una transacción ───────────────────
  //
  // Se relee dentro de la transacción a propósito. Entre la consulta de arriba
  // y este punto pueden haber pasado segundos, y en ese hueco cabe otra
  // ejecución del despachador.
  const tomado = await db.runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    if (!doc.exists) {
      return false;
    }

    const actual: ItemCola = {
      id: doc.id,
      estado: doc.get('estado'),
      ejecutarEn: (doc.get('ejecutarEn') as Timestamp).toDate(),
      intentos: (doc.get('intentos') as number | undefined) ?? 0,
      bloqueoHasta:
        (doc.get('bloqueoHasta') as Timestamp | null)?.toDate() ?? null,
      prioridad: (doc.get('prioridad') as number | undefined) ?? 0,
    };

    const decision = decidirSobreItem(actual, ahora);

    if (decision === 'YA_TOMADO' || decision === 'TERMINADO') {
      return false;
    }

    if (decision === 'AGOTADO') {
      tx.update(ref, { estado: 'FALLIDO', motivo: 'INTENTOS_AGOTADOS' });
      return false;
    }

    tx.update(ref, {
      estado: 'TOMADO',
      bloqueoHasta: aTimestamp(bloqueoHasta(ahora)),
      intentos: FieldValue.increment(1),
    });
    return true;
  });

  if (!tomado) {
    return;
  }

  const mensajeId = (await ref.get()).get('mensajeId') as string;
  const refMensaje = db.collection(RUTAS.mensajes).doc(mensajeId);
  const mensaje = await refMensaje.get();

  if (!mensaje.exists) {
    await ref.update({ estado: 'FALLIDO', motivo: 'MENSAJE_INEXISTENTE' });
    return;
  }

  const estadoMensaje = mensaje.get('estado') as string;
  if (estadoMensaje === 'CANCELADO' || estadoMensaje === 'SUSPENDIDO') {
    await ref.update({ estado: 'FALLIDO', motivo: estadoMensaje });
    return;
  }

  // ── RF-PRG-13: ¿todavía toca, o venció hace demasiado? ───────────────────
  //
  // Si el sistema estuvo caído dos días, nadie quiere que al volver salga de
  // golpe el aviso de un simulacro de anteayer.
  const decision = decidirDespacho(item.ejecutarEn, ahora);

  if (decision === 'ESPERAR') {
    await ref.update({ estado: 'PENDIENTE', bloqueoHasta: null });
    return;
  }

  if (decision === 'OMITIR') {
    await ref.update({ estado: 'COMPLETADO', motivo: 'OMITIDA_POR_RETRASO' });
    await escribirAsiento(
      crearAsiento({
        tipo: 'OCURRENCIA_OMITIDA',
        actor: { uid: ACTOR_SISTEMA, correo: '', rol: 'COORDINADOR' },
        entidad: 'MENSAJE',
        entidadId: mensajeId,
        resumen: `Ocurrencia omitida: venció hace ${Math.round(
          desviacionSegundos(item.ejecutarEn, ahora) / 60,
        )} minutos, más de la tolerancia`,
        datos: {
          previstaPara: item.ejecutarEn.toISOString(),
          desviacionSegundos: desviacionSegundos(item.ejecutarEn, ahora),
        },
        origen: 'PLANIFICADOR',
      }),
    );
    await programarSiguiente(refMensaje, mensajeId);
    return;
  }

  // ── Despacho real ────────────────────────────────────────────────────────
  const resultado = await despacharMensaje(refMensaje, `${item.id}`);

  await ref.update({ estado: 'COMPLETADO', bloqueoHasta: null });

  await escribirAsiento(
    crearAsiento({
      tipo: 'OCURRENCIA_DISPARADA',
      actor: { uid: ACTOR_SISTEMA, correo: '', rol: 'COORDINADOR' },
      entidad: 'MENSAJE',
      entidadId: mensajeId,
      resumen: `«${mensaje.get('titulo') as string}» despachado a ${resultado.entregados} de ${resultado.total}`,
      datos: {
        entregados: resultado.entregados,
        fallidos: resultado.fallidos,
        // Evidencia de RNF-04: cuánto se desvió del instante prometido.
        desviacionSegundos: desviacionSegundos(item.ejecutarEn, ahora),
      },
      origen: 'PLANIFICADOR',
    }),
  );

  await programarSiguiente(refMensaje, mensajeId);
}

/**
 * Encola la siguiente ocurrencia de un patrón recurrente.
 *
 * Se hace **después** de despachar y no antes: encolar primero significaría
 * que un fallo en el envío deja programada una repetición de algo que nunca
 * salió.
 */
async function programarSiguiente(
  refMensaje: DocumentReference,
  mensajeId: string,
): Promise<void> {
  const doc = await refMensaje.get();
  const modo = doc.get('programacion.modo') as string | undefined;

  if (modo !== 'RECURRENTE') {
    return;
  }

  const rec = doc.get('programacion.recurrencia') as Recurrencia | undefined;
  if (!rec) {
    return;
  }

  const generadas = (rec.ocurrenciasGeneradas ?? 0) + 1;
  const actualizada: Recurrencia = { ...rec, ocurrenciasGeneradas: generadas };

  if (recurrenciaSuspendida(actualizada)) {
    await refMensaje.update({ estado: 'SUSPENDIDO' });
    return;
  }

  // RF-PRG-14: salvaguarda contra bucles de envío.
  if (recurrenciaAgotada(actualizada)) {
    await refMensaje.update({
      estado: 'AGOTADO',
      'programacion.recurrencia.ocurrenciasGeneradas': generadas,
      proximaOcurrencia: null,
    });
    return;
  }

  const proximas = calcularProximasOcurrencias(
    actualizada,
    ZONA_INSTITUCIONAL,
    1,
    new Date(),
  );

  if (proximas.length === 0) {
    await refMensaje.update({ estado: 'AGOTADO', proximaOcurrencia: null });
    return;
  }

  const siguiente = proximas[0]!.previstaPara;

  await refMensaje.update({
    estado: 'RECURRENTE_PENDIENTE',
    'programacion.recurrencia.ocurrenciasGeneradas': generadas,
    proximaOcurrencia: aTimestamp(siguiente),
  });

  await encolar(
    mensajeId,
    siguiente,
    prioridadDeDespacho(doc.get('tipo') as TipoMensaje),
    generadas + 1,
  );
}

export { MAX_INTENTOS };
