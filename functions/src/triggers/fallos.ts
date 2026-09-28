/**
 * SIAN — Los aparatos avisan de lo que les falla (DT-34).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Es una petición HTTP y no una llamada firmada, y tiene que serlo.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Lo que más interesa saber es justo lo que ocurre cuando Firebase no arrancó,
 * o antes de entrar: ahí no hay sesión ni SDK que firme nada. Por eso acepta
 * peticiones sin sesión, y por eso lo que guarda no vale nada para quien
 * quisiera abusar: un tipo de una lista cerrada, una versión, una plataforma y
 * un identificador de aparato al azar. Con tope diario (`domain/fallo.ts`).
 *
 * Nunca contesta otra cosa que 204 a un reporte aceptable, se escriba o no:
 * decir «ya llegaste al tope» no le sirve al aparato y sí a quien prueba.
 */

import { onRequest } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';

import {
  DIAS_DE_FALLOS,
  decidirEscritura,
  idDeFallo,
  leerReporte,
  resumirFallos,
  type FalloGuardado,
  type ResumenDeFallos,
} from '../domain/fallo';
import { FieldValue, OPCIONES_FUNCION, RUTAS, db, type Timestamp } from '../infrastructure/firebase';

/**
 * Solo la aplicación de los tres ambientes, y los emuladores.
 *
 * Lo hace cumplir el navegador, no el servidor: un guion puede mandar lo que
 * quiera. Aun así cierra la puerta a que otra página use a sus visitantes para
 * llenar esto.
 */
const ORIGENES_DE_LA_APP = [
  /^https:\/\/sian-umg-bdm(-dev|-qa)?\.(web\.app|firebaseapp\.com)$/,
  /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/,
];

export const reportarFallo = onRequest(
  { ...OPCIONES_FUNCION, cors: ORIGENES_DE_LA_APP },
  async (peticion, respuesta) => {
    if (peticion.method === 'OPTIONS') {
      respuesta.status(204).send('');
      return;
    }
    if (peticion.method !== 'POST') {
      respuesta.status(405).send('');
      return;
    }

    const reporte = leerReporte(peticion.body);
    if (reporte === null) {
      respuesta.status(400).send('');
      return;
    }

    const ahora = new Date();
    const id = idDeFallo(reporte, ahora);
    const dia = id.slice(0, 8);
    const refFallo = db.collection(RUTAS.fallos).doc(id);
    const refDia = db.collection(RUTAS.fallosPorDia).doc(dia);

    try {
      const decision = await db.runTransaction(async (tx) => {
        const [fallo, deHoy] = await Promise.all([tx.get(refFallo), tx.get(refDia)]);
        const ultimo = fallo.get('ultimo') as Timestamp | undefined;
        const d = decidirEscritura(
          fallo.exists && ultimo ? { ultimo: ultimo.toDate() } : null,
          (deHoy.get('documentos') as number | undefined) ?? 0,
          ahora,
        );
        if (d === 'nuevo') {
          tx.set(refFallo, { ...reporte, dia, veces: 1, primero: ahora, ultimo: ahora });
          tx.set(refDia, { dia, documentos: FieldValue.increment(1) }, { merge: true });
        } else if (d === 'sumar') {
          tx.update(refFallo, {
            veces: FieldValue.increment(1),
            ultimo: ahora,
            version: reporte.version,
            detalle: reporte.detalle,
          });
        }
        return d;
      });

      if (decision !== 'ignorar') {
        // En el registro también: es donde se mira cuando algo no cuadra, y
        // ahí queda aunque la sonda ya haya borrado el documento.
        logger.warn('Fallo reportado por un aparato', {
          que: reporte.que,
          version: reporte.version,
          plataforma: reporte.plataforma,
          detalle: reporte.detalle,
        });
      }
    } catch (e) {
      logger.error('No se pudo anotar el fallo de un aparato', { que: reporte.que, error: String(e) });
    }
    respuesta.status(204).send('');
  },
);

/** Lo que ve Alcance: las últimas 24 horas. Si no se puede leer, ceros. */
export async function fallosDeLasUltimas24Horas(ahora: Date): Promise<ResumenDeFallos> {
  try {
    const desde = new Date(ahora.getTime() - 24 * 3_600_000);
    const instantanea = await db.collection(RUTAS.fallos).where('ultimo', '>=', desde).get();
    const fallos: FalloGuardado[] = instantanea.docs.map((d) => ({
      aparato: (d.get('aparato') as string | undefined) ?? '',
      que: (d.get('que') as string | undefined) ?? '',
      ultimo: (d.get('ultimo') as Timestamp).toDate(),
      veces: (d.get('veces') as number | undefined) ?? 1,
      plataforma: (d.get('plataforma') as string | undefined) ?? 'OTRA',
      version: (d.get('version') as string | undefined) ?? '',
      detalle: (d.get('detalle') as string | undefined) ?? '',
    }));
    return resumirFallos(fallos, ahora);
  } catch (e) {
    logger.error('Alcance: no se pudieron leer los fallos de los aparatos', { error: String(e) });
    return { aparatos: 0, reportes: 0, porTipo: [] };
  }
}

/** La sonda diaria olvida lo de más de 30 días. Devuelve cuántos borró. */
export async function olvidarFallosViejos(ahora: Date): Promise<number> {
  const limite = new Date(ahora.getTime() - DIAS_DE_FALLOS * 86_400_000);
  const diaLimite = limite.toISOString().slice(0, 10).replace(/-/g, '');
  const [viejos, dias] = await Promise.all([
    db.collection(RUTAS.fallos).where('ultimo', '<', limite).limit(400).get(),
    db.collection(RUTAS.fallosPorDia).where('dia', '<', diaLimite).limit(50).get(),
  ]);
  if (viejos.empty && dias.empty) {
    return 0;
  }
  const lote = db.batch();
  for (const d of [...viejos.docs, ...dias.docs]) {
    lote.delete(d.ref);
  }
  await lote.commit();
  return viejos.size;
}
