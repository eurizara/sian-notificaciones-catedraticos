/**
 * SIAN — Catálogo de facultades y lo que ofrece cada sede (2.0 RF-FAC-01; 2.0.6).
 */

import { FieldPath, type QuerySnapshot } from 'firebase-admin/firestore';

import type { FacultadResuelta } from '../application/resolverDestinatarios';
import type { ElementoCatalogo } from '../domain/catalogo';
import { RUTAS, db } from './firebase';

function leer(instantanea: QuerySnapshot): ElementoCatalogo[] {
  return instantanea.docs.map((d) => ({
    id: d.id,
    nombre: (d.get('nombre') as string | undefined) ?? d.id,
    activa: d.get('activa') !== false,
  }));
}

/** Las facultades que ofrece una sede (RF-FAC-01). */
export async function leerFacultades(sedeId: string): Promise<FacultadResuelta[]> {
  const instantanea = await db
    .collection(RUTAS.sedes)
    .doc(sedeId)
    .collection(RUTAS.facultades)
    .get();
  return instantanea.docs.map((d) => ({ id: d.id, activa: d.get('activa') !== false }));
}

/** El nombre visible de una sede («Villa Nueva»); si no se puede leer, su identificador. */
export async function nombreDeSede(sedeId: string): Promise<string> {
  const d = await db.collection(RUTAS.sedes).doc(sedeId).get();
  return (d.get('nombre') as string | undefined) ?? sedeId;
}

/** El catálogo único de facultades (2.0.6). */
export async function leerCatalogoDeFacultades(): Promise<ElementoCatalogo[]> {
  return leer(await db.collection(RUTAS.catalogoFacultades).get());
}

/**
 * Cuántas personas tienen esa facultad en esa sede. Mira el perfil, que es
 * donde se guarda (`membresias.<sede>.facultades`); un perfil de antes de la
 * 2.0 no tiene facultades, así que no cuenta.
 */
export async function contarPersonasConFacultad(sedeId: string, facultadId: string): Promise<number> {
  const conteo = await db
    .collection(RUTAS.usuarios)
    .where(new FieldPath('membresias', sedeId, 'facultades'), 'array-contains', facultadId)
    .count()
    .get();
  return conteo.data().count;
}

/** Cuántos grupos de esa sede son de esa facultad (2.0.7). */
export async function contarGruposConFacultad(sedeId: string, facultadId: string): Promise<number> {
  const conteo = await db
    .collection(RUTAS.grupos)
    .where('sedeId', '==', sedeId)
    .where('facultadId', '==', facultadId)
    .count()
    .get();
  return conteo.data().count;
}

/** Los nombres de las sedes que hoy ofrecen esa facultad. */
export async function sedesQueOfrecen(facultadId: string): Promise<string[]> {
  const sedes = await db.collection(RUTAS.sedes).get();
  if (sedes.empty) {
    return [];
  }
  const ofertas = await db.getAll(
    ...sedes.docs.map((s) => s.ref.collection(RUTAS.facultades).doc(facultadId)),
  );
  return ofertas
    .map((o, i) => (o.exists && o.get('activa') !== false ? ((sedes.docs[i]?.get('nombre') as string | undefined) ?? sedes.docs[i]?.id ?? '') : ''))
    .filter((n) => n !== '');
}

/**
 * Lleva el nombre nuevo de una facultad a cada sede que la tiene: allí se
 * guarda una copia para que lo que lee esa lista no tenga que buscarlo.
 */
export async function propagarNombreDeFacultad(facultadId: string, nombre: string): Promise<void> {
  const sedes = await db.collection(RUTAS.sedes).get();
  const ofertas = sedes.empty
    ? []
    : await db.getAll(...sedes.docs.map((s) => s.ref.collection(RUTAS.facultades).doc(facultadId)));
  const lote = db.batch();
  let n = 0;
  for (const o of ofertas) {
    if (o.exists) {
      lote.update(o.ref, { nombre });
      n += 1;
    }
  }
  if (n > 0) {
    await lote.commit();
  }
}
