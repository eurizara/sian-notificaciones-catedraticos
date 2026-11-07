/**
 * SIAN — Catálogo de facultades de una sede (2.0, RF-FAC-01).
 */

import type { FacultadResuelta } from '../application/resolverDestinatarios';
import { RUTAS, db } from './firebase';

/** Las facultades del catálogo de una sede (RF-FAC-01). */
export async function leerFacultades(sedeId: string): Promise<FacultadResuelta[]> {
  const instantanea = await db
    .collection(RUTAS.sedes)
    .doc(sedeId)
    .collection(RUTAS.facultades)
    .get();
  return instantanea.docs.map((d) => ({ id: d.id, activa: d.get('activa') !== false }));
}
