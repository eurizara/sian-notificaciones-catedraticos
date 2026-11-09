/**
 * Catálogo único de facultades contra el emulador de Firestore (2.0.6).
 *
 * Lo que solo se ve contra un Firestore de verdad: que la consulta por un
 * campo dentro de `membresias.<sede>` funciona con sedes que llevan guion
 * (`villa-nueva`), y que los nombres llegan a cada sede que ofrece la facultad.
 */

import { db } from '../../src/infrastructure/firebase';
import {
  contarPersonasConFacultad,
  propagarNombreDeFacultad,
  sedesQueOfrecen,
} from '../../src/infrastructure/sedes';

async function limpiar(): Promise<void> {
  for (const coleccion of ['usuarios', 'sedes']) {
    const docs = await db.collection(coleccion).get();
    for (const d of docs.docs) {
      const sub = await d.ref.collection('facultades').get();
      await Promise.all(sub.docs.map((x) => x.ref.delete()));
      await d.ref.delete();
    }
  }
}

describe('2.0.6 · facultades por sede, contra el emulador', () => {
  beforeEach(async () => {
    await limpiar();
    await db.doc('sedes/bdm').set({ nombre: 'Boca del Monte', activa: true });
    await db.doc('sedes/villa-nueva').set({ nombre: 'Villa Nueva', activa: true });
    await db.doc('sedes/bdm/facultades/ing-sistemas').set({ nombre: 'Ing. Sistemas', activa: true });
    await db.doc('sedes/villa-nueva/facultades/ing-sistemas').set({ nombre: 'Ing. Sistemas', activa: false });
    await db.doc('usuarios/maria').set({
      rol: 'CATEDRATICO',
      membresias: {
        bdm: { rol: 'CATEDRATICO', facultades: [] },
        'villa-nueva': { rol: 'CATEDRATICO', facultades: ['ing-sistemas'] },
      },
    });
    await db.doc('usuarios/ana').set({
      rol: 'CATEDRATICO',
      membresias: { bdm: { rol: 'CATEDRATICO', facultades: ['ing-sistemas', 'psicologia'] } },
    });
    // De antes de la 2.0: sin membresías, no tiene facultades.
    await db.doc('usuarios/viejo').set({ rol: 'CATEDRATICO' });
  });

  afterAll(limpiar);

  it('cuenta a quien tiene la facultad en ESA sede, con sedes que llevan guion', async () => {
    expect(await contarPersonasConFacultad('bdm', 'ing-sistemas')).toBe(1);
    expect(await contarPersonasConFacultad('villa-nueva', 'ing-sistemas')).toBe(1);
    expect(await contarPersonasConFacultad('bdm', 'derecho')).toBe(0);
  });

  it('solo cuenta las sedes que la ofrecen hoy, por su nombre', async () => {
    expect(await sedesQueOfrecen('ing-sistemas')).toEqual(['Boca del Monte']);
    expect(await sedesQueOfrecen('derecho')).toEqual([]);
  });

  it('el nombre nuevo llega a cada sede que la tiene, ofrecida o no, y no crea las que faltan', async () => {
    await propagarNombreDeFacultad('ing-sistemas', 'Ingeniería en Sistemas');
    expect((await db.doc('sedes/bdm/facultades/ing-sistemas').get()).get('nombre')).toBe('Ingeniería en Sistemas');
    expect((await db.doc('sedes/villa-nueva/facultades/ing-sistemas').get()).get('nombre')).toBe(
      'Ingeniería en Sistemas',
    );
    await propagarNombreDeFacultad('derecho', 'Derecho');
    expect((await db.doc('sedes/bdm/facultades/derecho').get()).exists).toBe(false);
  });
});
