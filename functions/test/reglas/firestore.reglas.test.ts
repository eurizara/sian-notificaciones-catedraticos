/**
 * Pruebas de las reglas de seguridad de Firestore — RNF-08.
 *
 * «Ningún cliente puede leer datos de otro usuario ni escribir fuera de su
 * ámbito.» Esa frase del documento 01 es la que se verifica aquí, caso por caso
 * y rol por rol, contra el emulador.
 *
 * Ejecutar con:
 *   firebase emulators:exec --only firestore "npm --prefix functions run test:rules"
 */

import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

const ID_PROYECTO = 'sian-reglas-test';

let entorno: RulesTestEnvironment;

/** Claims tal como los siembra la Function de alta de usuario. */
function claims(rol: string, activo = true, extra: Record<string, unknown> = {}) {
  return { rol, activo, ...extra };
}

const UID = {
  coordinador: 'uid-coordinador',
  administradora: 'uid-administradora',
  catedratico: 'uid-catedratico',
  otroCatedratico: 'uid-otro-catedratico',
  auditor: 'uid-auditor',
} as const;

function contexto(uid: string, rol: string, activo = true, extra: Record<string, unknown> = {}) {
  return entorno.authenticatedContext(uid, claims(rol, activo, extra)).firestore();
}

beforeAll(async () => {
  entorno = await initializeTestEnvironment({
    projectId: ID_PROYECTO,
    firestore: {
      rules: readFileSync(join(__dirname, '../../../firestore.rules'), 'utf8'),
    },
  });
});

afterAll(async () => {
  await entorno.cleanup();
});

beforeEach(async () => {
  await entorno.clearFirestore();

  // Siembra con las reglas desactivadas: representa lo que escribe el SDK de
  // administración desde las Cloud Functions, que no pasa por estas reglas.
  await entorno.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    await setDoc(doc(db, 'usuarios', UID.catedratico), {
      correo: 'catedratico@umg.edu.gt',
      nombre: 'Catedrático de Prueba',
      rol: 'CATEDRATICO',
      activo: true,
    });
    await setDoc(doc(db, 'usuarios', UID.otroCatedratico), {
      correo: 'otro@umg.edu.gt',
      nombre: 'Otro Catedrático',
      rol: 'CATEDRATICO',
      activo: true,
    });

    await setDoc(doc(db, 'grupos', 'g-1'), { nombre: 'Facultad de Ingeniería', totalMiembros: 2 });

    // Mensaje emitido por la administradora, dirigido al catedrático.
    await setDoc(doc(db, 'mensajes', 'm-1'), {
      titulo: 'Simulacro',
      tipo: 'URGENTE',
      creadoPor: UID.administradora,
      destinatariosUids: [UID.catedratico],
    });
    await setDoc(doc(db, 'mensajes', 'm-1', 'ocurrencias', 'o-1'), { numero: 1 });
    await setDoc(doc(db, 'mensajes', 'm-1', 'ocurrencias', 'o-1', 'entregas', UID.catedratico), {
      uid: UID.catedratico,
      estado: 'ENTREGADO',
    });

    await setDoc(doc(db, 'bitacora', 'b-1'), { tipo: 'MENSAJE_CREADO', actorUid: UID.administradora });
    await setDoc(doc(db, 'cola_despacho', 'c-1'), { mensajeId: 'm-1', estado: 'PENDIENTE' });
    await setDoc(doc(db, 'invitaciones', 'nuevo@umg.edu.gt'), { rolAsignado: 'CATEDRATICO' });
    await setDoc(doc(db, 'configuracion', 'institucional'), { zonaHoraria: 'America/Guatemala' });
  });
});

describe('Acceso sin autenticar', () => {
  it('no puede leer absolutamente nada', async () => {
    const db = entorno.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'usuarios', UID.catedratico)));
    await assertFails(getDoc(doc(db, 'mensajes', 'm-1')));
    await assertFails(getDoc(doc(db, 'configuracion', 'institucional')));
    await assertFails(getDoc(doc(db, 'grupos', 'g-1')));
  });

  it('no puede escribir nada', async () => {
    const db = entorno.unauthenticatedContext().firestore();
    await assertFails(setDoc(doc(db, 'usuarios', UID.catedratico), { rol: 'COORDINADOR' }));
  });
});

describe('Perfil de usuario', () => {
  it('el catedrático lee su propio perfil pero no el de un colega', async () => {
    const db = contexto(UID.catedratico, 'CATEDRATICO');
    await assertSucceeds(getDoc(doc(db, 'usuarios', UID.catedratico)));
    await assertFails(getDoc(doc(db, 'usuarios', UID.otroCatedratico)));
  });

  it('el coordinador y el auditor leen cualquier perfil', async () => {
    await assertSucceeds(
      getDoc(doc(contexto(UID.coordinador, 'COORDINADOR'), 'usuarios', UID.catedratico)),
    );
    await assertSucceeds(
      getDoc(doc(contexto(UID.auditor, 'AUDITOR'), 'usuarios', UID.catedratico)),
    );
  });

  it('RF-USR-08 · el usuario actualiza sus datos, nunca su rol ni su estado', async () => {
    const db = contexto(UID.catedratico, 'CATEDRATICO');
    const perfil = doc(db, 'usuarios', UID.catedratico);

    await assertSucceeds(updateDoc(perfil, { nombre: 'Nombre Actualizado' }));
    await assertSucceeds(updateDoc(perfil, { unidadAcademica: 'Ingeniería en Sistemas' }));

    // Escalada de privilegios: es el ataque que estas reglas existen para parar.
    await assertFails(updateDoc(perfil, { rol: 'COORDINADOR' }));
    await assertFails(updateDoc(perfil, { activo: false }));
    await assertFails(updateDoc(perfil, { correo: 'otro@umg.edu.gt' }));
    await assertFails(updateDoc(perfil, { puedeEmitirUrgentes: true }));
    await assertFails(updateDoc(perfil, { puedeCrearRecurrentes: true }));
  });

  it('la lista blanca de campos editables falla cerrado ante un campo nuevo', async () => {
    // Si mañana el modelo de datos gana un campo y nadie se acuerda de
    // protegerlo, el cliente sigue sin poder escribirlo. Ese es todo el motivo
    // de usar `hasOnly` con lista blanca en vez de `hasAny` con lista negra.
    const db = contexto(UID.catedratico, 'CATEDRATICO');
    await assertFails(
      updateDoc(doc(db, 'usuarios', UID.catedratico), { campoInventadoEnElFuturo: 'lo que sea' }),
    );
  });

  it('nadie crea ni borra perfiles desde el cliente', async () => {
    const db = contexto(UID.coordinador, 'COORDINADOR');
    await assertFails(setDoc(doc(db, 'usuarios', 'uid-inventado'), { rol: 'COORDINADOR' }));
  });

  it('RF-USR-09 · el usuario registra sus propios dispositivos, no los ajenos', async () => {
    const db = contexto(UID.catedratico, 'CATEDRATICO');
    await assertSucceeds(
      setDoc(doc(db, 'usuarios', UID.catedratico, 'dispositivos', 't-1'), {
        tokenFCM: 'token-abc',
        plataforma: 'WEB_ANDROID',
        activo: true,
      }),
    );
    await assertFails(
      setDoc(doc(db, 'usuarios', UID.otroCatedratico, 'dispositivos', 't-2'), {
        tokenFCM: 'token-robado',
      }),
    );
  });
});

describe('Mensajes', () => {
  it('el destinatario lee el mensaje que le fue enviado', async () => {
    const db = contexto(UID.catedratico, 'CATEDRATICO');
    await assertSucceeds(getDoc(doc(db, 'mensajes', 'm-1')));
  });

  it('un catedrático que no es destinatario no lo lee', async () => {
    const db = contexto(UID.otroCatedratico, 'CATEDRATICO');
    await assertFails(getDoc(doc(db, 'mensajes', 'm-1')));
  });

  it('el emisor lee lo suyo; el coordinador y el auditor, todo', async () => {
    await assertSucceeds(
      getDoc(doc(contexto(UID.administradora, 'ADMINISTRADORA'), 'mensajes', 'm-1')),
    );
    await assertSucceeds(getDoc(doc(contexto(UID.coordinador, 'COORDINADOR'), 'mensajes', 'm-1')));
    await assertSucceeds(getDoc(doc(contexto(UID.auditor, 'AUDITOR'), 'mensajes', 'm-1')));
  });

  it('RN-03 · ningún cliente escribe mensajes, ni siquiera el coordinador', async () => {
    const db = contexto(UID.coordinador, 'COORDINADOR');
    await assertFails(setDoc(doc(db, 'mensajes', 'm-2'), { titulo: 'Directo' }));
    await assertFails(updateDoc(doc(db, 'mensajes', 'm-1'), { titulo: 'Editado' }));
  });
});

describe('Entregas y confirmación de lectura', () => {
  it('el destinatario lee su propia entrega', async () => {
    const db = contexto(UID.catedratico, 'CATEDRATICO');
    await assertSucceeds(
      getDoc(doc(db, 'mensajes', 'm-1', 'ocurrencias', 'o-1', 'entregas', UID.catedratico)),
    );
  });

  it('un catedrático no lee la entrega de otro', async () => {
    const db = contexto(UID.otroCatedratico, 'CATEDRATICO');
    await assertFails(
      getDoc(doc(db, 'mensajes', 'm-1', 'ocurrencias', 'o-1', 'entregas', UID.catedratico)),
    );
  });

  it('RF-CNF-04 · nadie confirma escribiendo directo en Firestore', async () => {
    // La confirmación tiene valor probatorio: solo la escribe el servidor.
    const db = contexto(UID.catedratico, 'CATEDRATICO');
    await assertFails(
      updateDoc(doc(db, 'mensajes', 'm-1', 'ocurrencias', 'o-1', 'entregas', UID.catedratico), {
        estado: 'CONFIRMADO',
        confirmadoEn: new Date(),
      }),
    );
  });
});

describe('Bitácora', () => {
  it('RF-BIT-04 · solo el coordinador y el auditor la leen', async () => {
    await assertSucceeds(getDoc(doc(contexto(UID.coordinador, 'COORDINADOR'), 'bitacora', 'b-1')));
    await assertSucceeds(getDoc(doc(contexto(UID.auditor, 'AUDITOR'), 'bitacora', 'b-1')));
    await assertFails(getDoc(doc(contexto(UID.catedratico, 'CATEDRATICO'), 'bitacora', 'b-1')));
    await assertFails(
      getDoc(doc(contexto(UID.administradora, 'ADMINISTRADORA'), 'bitacora', 'b-1')),
    );
  });

  it('RF-BIT-03 · es inmutable para todo cliente', async () => {
    for (const [uid, rol] of [
      [UID.coordinador, 'COORDINADOR'],
      [UID.auditor, 'AUDITOR'],
      [UID.catedratico, 'CATEDRATICO'],
    ] as const) {
      const db = contexto(uid, rol);
      await assertFails(setDoc(doc(db, 'bitacora', 'b-2'), { tipo: 'INVENTADO' }));
      await assertFails(updateDoc(doc(db, 'bitacora', 'b-1'), { tipo: 'ALTERADO' }));
    }
  });
});

describe('Cola de despacho', () => {
  it('es invisible para todos los roles, sin excepción', async () => {
    for (const [uid, rol] of [
      [UID.coordinador, 'COORDINADOR'],
      [UID.auditor, 'AUDITOR'],
      [UID.administradora, 'ADMINISTRADORA'],
      [UID.catedratico, 'CATEDRATICO'],
    ] as const) {
      const db = contexto(uid, rol);
      await assertFails(getDoc(doc(db, 'cola_despacho', 'c-1')));
      await assertFails(setDoc(doc(db, 'cola_despacho', 'c-2'), { estado: 'PENDIENTE' }));
    }
  });
});

describe('Invitaciones, grupos y configuración', () => {
  it('RF-AUT-03 · solo el coordinador consulta la lista blanca', async () => {
    await assertSucceeds(
      getDoc(doc(contexto(UID.coordinador, 'COORDINADOR'), 'invitaciones', 'nuevo@umg.edu.gt')),
    );
    await assertFails(
      getDoc(doc(contexto(UID.administradora, 'ADMINISTRADORA'), 'invitaciones', 'nuevo@umg.edu.gt')),
    );
    await assertFails(
      getDoc(doc(contexto(UID.catedratico, 'CATEDRATICO'), 'invitaciones', 'nuevo@umg.edu.gt')),
    );
  });

  it('todo usuario activo lee grupos y configuración, y ninguno los escribe', async () => {
    const db = contexto(UID.catedratico, 'CATEDRATICO');
    await assertSucceeds(getDoc(doc(db, 'grupos', 'g-1')));
    await assertSucceeds(getDoc(doc(db, 'configuracion', 'institucional')));
    await assertFails(setDoc(doc(db, 'grupos', 'g-2'), { nombre: 'Inventado' }));
    await assertFails(
      updateDoc(doc(db, 'configuracion', 'institucional'), { toleranciaRetrasoMin: 9999 }),
    );
  });
});

describe('RN-10 · usuario desactivado', () => {
  it('conserva la lectura de su perfil pero pierde el resto del sistema', async () => {
    const db = contexto(UID.catedratico, 'CATEDRATICO', false);

    // Sigue siendo dueño de su documento, así que puede verlo.
    await assertSucceeds(getDoc(doc(db, 'usuarios', UID.catedratico)));

    // Pero deja de operar: ni configuración, ni grupos, ni actualizar perfil.
    await assertFails(getDoc(doc(db, 'configuracion', 'institucional')));
    await assertFails(getDoc(doc(db, 'grupos', 'g-1')));
    await assertFails(updateDoc(doc(db, 'usuarios', UID.catedratico), { nombre: 'Nuevo' }));
  });

  it('un coordinador desactivado pierde sus privilegios de coordinador', async () => {
    const db = contexto(UID.coordinador, 'COORDINADOR', false);
    await assertFails(getDoc(doc(db, 'bitacora', 'b-1')));
    await assertFails(getDoc(doc(db, 'usuarios', UID.catedratico)));
  });
});

describe('Token sin rol', () => {
  it('un usuario autenticado sin claims no obtiene privilegios por defecto', async () => {
    const db = entorno.authenticatedContext('uid-sin-claims').firestore();
    await assertFails(getDoc(doc(db, 'bitacora', 'b-1')));
    await assertFails(getDoc(doc(db, 'grupos', 'g-1')));
    await assertFails(getDoc(doc(db, 'mensajes', 'm-1')));
  });
});
