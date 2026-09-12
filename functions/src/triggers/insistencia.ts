/**
 * SIAN — Insistir cuando el aparato no mostró el aviso (DT-31, C-5).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Es lo único de C-5 que ACTÚA. El resto solo mide.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Con el acuse ya se sabe a quién le llegó el push y nunca se le mostró. Diez
 * minutos después, se empuja una segunda vez. No es magia: el servicio de push
 * puede haber retenido el primero por el modo de reposo del aparato, y el
 * segundo llega cuando la pantalla ya despertó.
 *
 * **Una vez y no más.** Si dos empujones no aparecieron, lo que falla no es la
 * entrega sino los ajustes del teléfono —modos de concentración, notificaciones
 * apagadas, Chrome silenciando el sitio—, y eso no lo arregla un tercer
 * intento: lo arregla una persona. Para eso está la lista de Alcance.
 *
 * Va montado sobre el despachador, que ya corre cada minuto. Un trabajo
 * programado más habría costado otra cuota de Cloud Scheduler en cada uno de
 * los tres ambientes, para hacer lo mismo un minuto más tarde.
 */

import { logger } from 'firebase-functions/v2';
import { getMessaging, type TokenMessage } from 'firebase-admin/messaging';
import type { Timestamp } from 'firebase-admin/firestore';

import {
  MINUTOS_SIN_ACUSE_PARA_REINTENTAR,
  armarSeña,
  cabecerasDeEnvio,
  necesitaReintento,
} from '../domain/acuse';
import { esTokenMuerto } from '../domain/dispositivo';
import { FieldValue, RUTAS, aTimestamp, db } from '../infrastructure/firebase';
import { retirarTokensMuertos, tokensDe } from './envio';

/** Cuántas entregas se reintentan por ciclo. */
const MAX_POR_CICLO = 30;

/**
 * Más allá de esto no se insiste: un aviso de ayer que aparece hoy confunde más
 * de lo que informa, y su vida útil en el servicio de push ya venció.
 */
const HORAS_HACIA_ATRAS = 6;

export async function insistirDondeNoHuboAcuse(ahora: Date): Promise<number> {
  const desde = new Date(ahora.getTime() - HORAS_HACIA_ATRAS * 60 * 60 * 1000);
  const hasta = new Date(ahora.getTime() - MINUTOS_SIN_ACUSE_PARA_REINTENTAR * 60 * 1000);

  // `mostradaEn == null` encuentra solo los documentos donde el campo existe y
  // vale nulo: por eso las entregas se crean con el campo puesto. Los avisos
  // anteriores a C-5 no lo tienen, y quedan fuera, que es lo correcto — nadie
  // les pidió acuse.
  const candidatas = await db
    .collectionGroup('entregas')
    .where('estado', '==', 'ENTREGADO')
    .where('mostradaEn', '==', null)
    .where('reintentosPorAcuse', '==', 0)
    .where('enviadoAFcmEn', '>=', aTimestamp(desde))
    .where('enviadoAFcmEn', '<=', aTimestamp(hasta))
    .orderBy('enviadoAFcmEn', 'asc')
    .limit(MAX_POR_CICLO)
    .get();

  if (candidatas.empty) {
    return 0;
  }

  const contenidos = new Map<string, Record<string, string> | null>();
  let insistidos = 0;

  for (const entrega of candidatas.docs) {
    try {
      const uid = (entrega.get('uid') as string | undefined) ?? entrega.id;
      const mensajeId = (entrega.get('mensajeId') as string | undefined) ?? '';
      const acuseId = (entrega.get('acuseId') as string | undefined) ?? '';
      const ocurrenciaId = entrega.ref.parent.parent?.id ?? '';

      // La decisión, otra vez y con el documento en la mano: entre la consulta
      // y esta línea la persona pudo abrir el aviso.
      const procede = necesitaReintento(
        {
          estado: (entrega.get('estado') as string | undefined) ?? '',
          mostradaEn: (entrega.get('mostradaEn') as Timestamp | null)?.toDate() ?? null,
          enviadoAFcmEn:
            (entrega.get('enviadoAFcmEn') as Timestamp | null)?.toDate() ?? null,
          reintentosPorAcuse: (entrega.get('reintentosPorAcuse') as number | undefined) ?? 0,
        },
        ahora,
      );
      if (!procede || !mensajeId || !acuseId || !ocurrenciaId) {
        continue;
      }

      if (!contenidos.has(mensajeId)) {
        const mensaje = await db.collection(RUTAS.mensajes).doc(mensajeId).get();
        contenidos.set(
          mensajeId,
          mensaje.exists
            ? {
                tipo: (mensaje.get('tipo') as string | undefined) ?? 'INFORMATIVO',
                titulo: (mensaje.get('titulo') as string | undefined) ?? '',
                cuerpo: (mensaje.get('cuerpo') as string | undefined) ?? '',
                mensajeId,
                formato: ((mensaje.get('formato') as string[] | undefined) ?? []).join(','),
              }
            : null,
        );
      }
      const carga = contenidos.get(mensajeId);
      if (!carga) {
        continue;
      }

      const tokens = await tokensDe(uid);
      // Se marca el intento aunque no haya a dónde mandarlo: sin dispositivo no
      // hay nada que insistir, y volver a mirarlo cada minuto no lo cambia.
      await entrega.ref.update({
        reintentosPorAcuse: FieldValue.increment(1),
        reintentadoEn: FieldValue.serverTimestamp(),
      });
      if (tokens.length === 0) {
        continue;
      }

      const mensajes: TokenMessage[] = tokens.map((token) => ({
        token,
        data: { ...carga, ac: armarSeña(ocurrenciaId, uid, acuseId) },
        webpush: {
          headers: cabecerasDeEnvio(carga.tipo === 'URGENTE'),
          fcmOptions: { link: '/' },
        },
      }));

      const respuesta = await getMessaging().sendEach(mensajes);
      const muertos: { uid: string; token: string }[] = [];
      respuesta.responses.forEach((r, i) => {
        const token = tokens[i];
        if (!r.success && token !== undefined && esTokenMuerto(r.error?.code)) {
          muertos.push({ uid, token });
        }
      });
      await retirarTokensMuertos(muertos);
      insistidos += 1;
    } catch (e) {
      // Una entrega que falla no puede tumbar el ciclo del despachador.
      logger.warn('No se pudo insistir en una entrega', {
        entrega: entrega.ref.path,
        error: String(e),
      });
    }
  }

  if (insistidos > 0) {
    logger.info('Se insistió en avisos sin acuse', { cuantos: insistidos });
  }
  return insistidos;
}
