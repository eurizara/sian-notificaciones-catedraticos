/**
 * SIAN — Datos de prueba para desarrollo (documento 06, etapa D.4).
 *
 * Crea: un coordinador, dos administradoras, diez catedráticos ficticios,
 * dos grupos y tres mensajes de ejemplo en distintos estados.
 *
 * Solo se ejecuta contra los emuladores. Sembrar datos ficticios en un proyecto
 * real es la clase de accidente que no se deshace, así que el script se niega
 * a arrancar si no detecta el emulador.
 *
 * Uso:  npm run seed:dev      (con los emuladores corriendo)
 */

import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { Timestamp, getFirestore } from 'firebase-admin/firestore';

const PROYECTO = process.env.FIREBASE_PROJECT_ID ?? 'sian-dev';
const ZONA = process.env.ZONA_HORARIA ?? 'America/Guatemala';

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error(
    [
      'Este script solo siembra datos en los emuladores.',
      '',
      'No se detectó FIRESTORE_EMULATOR_HOST. Levanta los emuladores primero:',
      '',
      '  npm run emu',
      '',
      'y vuelve a ejecutar `npm run seed:dev` en otra terminal.',
    ].join('\n'),
  );
  process.exit(1);
}

// Contra el emulador no hacen falta credenciales: basta con el id de proyecto.
initializeApp({ projectId: PROYECTO });

const db = getFirestore();
const auth = getAuth();

interface UsuarioSemilla {
  uid: string;
  correo: string;
  nombre: string;
  rol: 'COORDINADOR' | 'ADMINISTRADORA' | 'CATEDRATICO' | 'AUDITOR';
  puedeEmitirUrgentes?: boolean;
  puedeCrearRecurrentes?: boolean;
}

const USUARIOS: UsuarioSemilla[] = [
  {
    uid: 'seed-coordinador',
    correo: 'coordinacion@umg.edu.gt',
    nombre: 'Coordinación Académica',
    rol: 'COORDINADOR',
    puedeEmitirUrgentes: true,
    puedeCrearRecurrentes: true,
  },
  {
    uid: 'seed-admin-1',
    correo: 'admin1@umg.edu.gt',
    nombre: 'Administradora Uno',
    rol: 'ADMINISTRADORA',
    puedeEmitirUrgentes: true,
    puedeCrearRecurrentes: false,
  },
  {
    uid: 'seed-admin-2',
    correo: 'admin2@umg.edu.gt',
    nombre: 'Administradora Dos',
    rol: 'ADMINISTRADORA',
    puedeEmitirUrgentes: false,
    puedeCrearRecurrentes: false,
  },
  { uid: 'seed-auditor', correo: 'auditoria@umg.edu.gt', nombre: 'Auditoría Interna', rol: 'AUDITOR' },
  ...Array.from({ length: 10 }, (_, i) => ({
    uid: `seed-catedratico-${i + 1}`,
    correo: `catedratico${i + 1}@umg.edu.gt`,
    nombre: `Catedrático ${i + 1}`,
    rol: 'CATEDRATICO' as const,
  })),
];

async function sembrarUsuarios(): Promise<void> {
  for (const u of USUARIOS) {
    await auth
      .createUser({
        uid: u.uid,
        email: u.correo,
        emailVerified: true,
        password: 'Simulacro2026',
        displayName: u.nombre,
      })
      .catch(() => undefined); // ya existía: no es un error al re-sembrar

    // Los custom claims son la fuente de autorización que leen las reglas
    // (documento 02, sección 9).
    await auth.setCustomUserClaims(u.uid, {
      rol: u.rol,
      activo: true,
      puedeEmitirUrgentes: u.puedeEmitirUrgentes ?? false,
      puedeCrearRecurrentes: u.puedeCrearRecurrentes ?? false,
    });

    await db.doc(`usuarios/${u.uid}`).set({
      correo: u.correo,
      nombre: u.nombre,
      rol: u.rol,
      activo: true,
      proveedorAuth: 'password',
      puedeEmitirUrgentes: u.puedeEmitirUrgentes ?? false,
      puedeCrearRecurrentes: u.puedeCrearRecurrentes ?? false,
      zonaHoraria: ZONA,
      creadoEn: Timestamp.now(),
      actualizadoEn: Timestamp.now(),
    });

    await db.doc(`invitaciones/${u.correo}`).set({
      rolAsignado: u.rol,
      nombre: u.nombre,
      consumida: true,
      consumidaPor: u.uid,
      creadaPor: 'seed-coordinador',
      creadaEn: Timestamp.now(),
    });
  }
  console.log(`  ✓ ${USUARIOS.length} usuarios con rol, perfil e invitación consumida`);
}

async function sembrarGrupos(): Promise<void> {
  const catedraticos = USUARIOS.filter((u) => u.rol === 'CATEDRATICO').map((u) => u.uid);
  const mitad = Math.ceil(catedraticos.length / 2);

  const grupos = [
    { id: 'grupo-ingenieria', nombre: 'Facultad de Ingeniería', miembros: catedraticos.slice(0, mitad) },
    { id: 'grupo-humanidades', nombre: 'Facultad de Humanidades', miembros: catedraticos.slice(mitad) },
  ];

  for (const g of grupos) {
    await db.doc(`grupos/${g.id}`).set({
      nombre: g.nombre,
      descripcion: `Catedráticos de ${g.nombre}`,
      miembros: g.miembros,
      totalMiembros: g.miembros.length,
      creadoPor: 'seed-coordinador',
      creadoEn: Timestamp.now(),
      activo: true,
    });
  }
  console.log(`  ✓ ${grupos.length} grupos`);
}

async function sembrarConfiguracion(): Promise<void> {
  await db.doc('configuracion/institucional').set({
    zonaHoraria: ZONA,
    toleranciaRetrasoMin: 30,
    maxOcurrenciasPorMensaje: 500,
    tamanoLoteFCM: 500,
    maxReintentosEntrega: 3,
    retencionBitacoraMeses: 24,
    nombreInstitucion: 'Universidad Mariano Gálvez',
    urlLogo: '',
  });
  console.log('  ✓ configuración institucional');
}

async function sembrarMensajes(): Promise<void> {
  const catedraticos = USUARIOS.filter((u) => u.rol === 'CATEDRATICO').map((u) => u.uid);
  const ahora = Timestamp.now();

  // 1 · Borrador sin enviar.
  await db.doc('mensajes/seed-msg-borrador').set({
    titulo: 'Reunión de claustro',
    cuerpo: 'Se convoca a reunión ordinaria de claustro el próximo viernes.',
    tipo: 'INFORMATIVO',
    formato: ['TEXTO'],
    requiereConfirmacion: false,
    estado: 'BORRADOR',
    destinatarios: { modo: 'GRUPOS', gruposIds: ['grupo-ingenieria'] },
    programacion: { modo: 'INMEDIATO', zonaHoraria: ZONA },
    creadoPor: 'seed-admin-1',
    creadoEn: ahora,
  });

  // 2 · Urgente ya enviado, con entregas y una confirmación.
  await db.doc('mensajes/seed-msg-urgente').set({
    titulo: 'Simulacro de evacuación',
    cuerpo: 'Simulacro a las 10:00. Diríjase al punto de reunión más cercano.',
    tipo: 'URGENTE',
    formato: ['TEXTO'],
    requiereConfirmacion: true,
    estado: 'ENVIADO',
    destinatarios: { modo: 'TODOS' },
    destinatariosUids: catedraticos,
    totalDestinatarios: catedraticos.length,
    resumenEntrega: { entregados: catedraticos.length, fallidos: 0, abiertos: 2, confirmados: 1 },
    programacion: { modo: 'INMEDIATO', zonaHoraria: ZONA },
    creadoPor: 'seed-coordinador',
    creadoEn: ahora,
    enviadoEn: ahora,
  });

  await db.doc('mensajes/seed-msg-urgente/ocurrencias/o-1').set({
    numero: 1,
    previstaPara: ahora,
    ejecutadaEn: ahora,
    desviacionSeg: 0,
    estado: 'COMPLETADA',
    totalDestinatarios: catedraticos.length,
    totalEntregados: catedraticos.length,
    totalFallidos: 0,
  });

  for (const [i, uid] of catedraticos.entries()) {
    await db.doc(`mensajes/seed-msg-urgente/ocurrencias/o-1/entregas/${uid}`).set({
      uid,
      mensajeId: 'seed-msg-urgente',
      estado: i === 0 ? 'CONFIRMADO' : i === 1 ? 'ABIERTO' : 'ENTREGADO',
      enviadoAFcmEn: ahora,
      entregadoEn: ahora,
      ...(i <= 1 ? { abiertoEn: ahora } : {}),
      ...(i === 0 ? { confirmadoEn: ahora, dispositivoConfirmacion: 'seed-dispositivo' } : {}),
      intentos: 1,
    });
  }

  // 3 · Recurrente programado, pendiente de disparar.
  const inicio = new Date(Date.now() + 5 * 60_000);
  const fin = new Date(Date.now() + 30 * 24 * 60 * 60_000);
  await db.doc('mensajes/seed-msg-recurrente').set({
    titulo: 'Recordatorio de registro de notas',
    cuerpo: 'Recuerde registrar las notas parciales antes del cierre semanal.',
    tipo: 'INFORMATIVO',
    formato: ['TEXTO'],
    requiereConfirmacion: false,
    estado: 'PROGRAMADO',
    destinatarios: { modo: 'TODOS' },
    programacion: {
      modo: 'RECURRENTE',
      zonaHoraria: ZONA,
      recurrencia: {
        fechaInicio: inicio.toISOString(),
        fechaFin: fin.toISOString(),
        unidadIntervalo: 'DIAS',
        valorIntervalo: 1,
        diasSemana: [1, 3, 5],
        horaDelDia: '07:30',
        maxOcurrencias: 500,
        ocurrenciasGeneradas: 0,
        suspendida: false,
      },
    },
    creadoPor: 'seed-coordinador',
    creadoEn: ahora,
  });

  await db.collection('cola_despacho').doc('seed-cola-1').set({
    mensajeId: 'seed-msg-recurrente',
    ocurrenciaId: 'o-1',
    ejecutarEn: Timestamp.fromDate(inicio),
    estado: 'PENDIENTE',
    intentos: 0,
    prioridad: 0,
    creadoEn: ahora,
  });

  await db.collection('bitacora').add({
    tipo: 'MENSAJE_CREADO',
    actorUid: 'seed-coordinador',
    actorCorreo: 'coordinacion@umg.edu.gt',
    actorRol: 'COORDINADOR',
    entidad: 'MENSAJE',
    entidadId: 'seed-msg-urgente',
    resumen: 'Datos de siembra para desarrollo',
    ocurridoEn: ahora,
    origen: 'PANEL_WEB',
  });

  console.log('  ✓ 3 mensajes (borrador, urgente enviado, recurrente programado)');
}

async function principal(): Promise<void> {
  console.log(`Sembrando datos de desarrollo en «${PROYECTO}» (emulador)…`);
  await sembrarUsuarios();
  await sembrarGrupos();
  await sembrarConfiguracion();
  await sembrarMensajes();
  console.log('\nListo. Entra con cualquier correo sembrado y la contraseña Simulacro2026.');
  console.log('Interfaz de emuladores: http://localhost:4000');
}

principal().catch((e: unknown) => {
  console.error('Falló la siembra:', e);
  process.exit(1);
});
