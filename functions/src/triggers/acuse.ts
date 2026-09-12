/**
 * SIAN — «Ya la mostré»: el acuse del service worker (DT-31, C-5).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Es una petición HTTP y no una llamada firmada, y tiene que serlo.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Quien avisa es el **service worker**, que se despierta con el push y no tiene
 * sesión de nadie: no hay token de usuario que firmar. Lo que lo identifica es
 * la seña que viajó dentro de ese mismo push y que solo conoce quien lo
 * recibió.
 *
 * Por eso esto no escribe nada con valor probatorio: no toca el estado de la
 * entrega, ni la confirmación de lectura, ni la bitácora. Solo anota una fecha
 * de diagnóstico —`mostradaEn`— y suma un contador. Lo peor que puede hacer
 * quien se invente una seña es decir que vio un aviso que era suyo.
 */

import { onRequest } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';

import { leerSeña } from '../domain/acuse';
import { ErrorDominio } from '../domain/errores';
import { FieldValue, OPCIONES_FUNCION, RUTAS, db } from '../infrastructure/firebase';

export const acuseDeNotificacion = onRequest(
  { ...OPCIONES_FUNCION, cors: true },
  async (peticion, respuesta) => {
    if (peticion.method === 'OPTIONS') {
      respuesta.status(204).send('');
      return;
    }
    if (peticion.method !== 'POST') {
      respuesta.status(405).send('');
      return;
    }

    const cuerpo = (peticion.body ?? {}) as { mensajeId?: string; ac?: string };
    const mensajeId = typeof cuerpo.mensajeId === 'string' ? cuerpo.mensajeId : '';

    try {
      const { ocurrenciaId, uid, acuseId } = leerSeña(cuerpo.ac);
      if (!/^[A-Za-z0-9_-]{1,64}$/.test(mensajeId)) {
        respuesta.status(400).send('');
        return;
      }

      const refEntrega = db
        .collection(RUTAS.mensajes)
        .doc(mensajeId)
        .collection('ocurrencias')
        .doc(ocurrenciaId)
        .collection('entregas')
        .doc(uid);

      // Una sola vez: el mismo aviso puede mostrarse en dos aparatos de la
      // misma persona, y lo que se cuenta es «a esta persona se le mostró».
      const anotado = await db.runTransaction(async (tx) => {
        const entrega = await tx.get(refEntrega);
        if (!entrega.exists || entrega.get('acuseId') !== acuseId) {
          // Seña que no corresponde. Se responde igual que en el caso bueno:
          // decir «esa entrega no existe» ya contaría algo.
          return false;
        }
        if (entrega.get('mostradaEn') != null) {
          return false;
        }
        tx.update(refEntrega, { mostradaEn: FieldValue.serverTimestamp() });
        return true;
      });

      if (anotado) {
        await db
          .collection(RUTAS.mensajes)
          .doc(mensajeId)
          .update({ 'resumenEntrega.mostrados': FieldValue.increment(1) });
      }

      respuesta.status(204).send('');
    } catch (e) {
      if (e instanceof ErrorDominio) {
        respuesta.status(400).send('');
        return;
      }
      // Que no se pueda anotar el acuse no puede romper nada: la notificación
      // ya se mostró, que es lo que importaba.
      logger.warn('No se pudo anotar el acuse', { mensajeId, error: String(e) });
      respuesta.status(204).send('');
    }
  },
);
