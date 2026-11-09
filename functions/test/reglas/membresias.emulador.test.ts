/**
 * Quitar una sede la borra de verdad — 2.0.5, contra el emulador de Firestore.
 *
 * El 08/11/2026 a María se le quitó Boca del Monte: la bitácora y su token
 * dijeron «solo Villa Nueva», y su perfil siguió con las dos. La escritura
 * fusionaba (`set` con `merge`), y fusionar un mapa no borra sus claves. Esto
 * prueba la función real del servidor contra un Firestore de verdad, que es el
 * único sitio donde ese comportamiento se ve.
 */

import { db } from '../../src/infrastructure/firebase';
import { reemplazarMembresias } from '../../src/infrastructure/repositorios';

const DOS_SEDES = {
  bdm: { rol: 'CATEDRATICO', facultades: ['psicologia'] },
  'villa-nueva': { rol: 'CATEDRATICO', facultades: [] },
};

describe('2.0.5 · membresías: quitar una sede', () => {
  it('reemplazarMembresias quita la sede, y deja solo la que queda', async () => {
    const ref = db.collection('usuarios').doc('prueba-maria');
    await ref.set({ rol: 'CATEDRATICO', membresias: DOS_SEDES });

    await reemplazarMembresias(
      'prueba-maria',
      { 'villa-nueva': { rol: 'CATEDRATICO', facultades: [] } },
      'CATEDRATICO',
    );

    expect((await ref.get()).get('membresias')).toEqual({
      'villa-nueva': { rol: 'CATEDRATICO', facultades: [] },
    });
  });

  it('la trampa que causó el defecto: fusionar NO borra la clave quitada', async () => {
    const ref = db.collection('usuarios').doc('prueba-fusion');
    await ref.set({ membresias: DOS_SEDES });

    await ref.set({ membresias: { 'villa-nueva': DOS_SEDES['villa-nueva'] } }, { merge: true });

    // Si esto deja de ser cierto algún día, la función de arriba sigue bien;
    // esta prueba solo documenta por qué no se puede volver a fusionar.
    expect(Object.keys((await ref.get()).get('membresias') as object).sort()).toEqual(['bdm', 'villa-nueva']);
  });
});
