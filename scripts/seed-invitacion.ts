/**
 * SIAN — Alta manual en la lista blanca institucional (documento 06, etapa E.5).
 *
 * La lista blanca (RF-AUT-03) controla quién puede entrar. Recién creado el
 * ambiente está vacía, así que nadie podría iniciar sesión: este script siembra
 * la primera invitación, normalmente la del coordinador.
 *
 * Uso:
 *   npm run seed:invitacion -- --correo=alguien@umg.edu.gt --rol=COORDINADOR
 *   npm run seed:invitacion -- --correo=... --rol=... --proyecto=sian-dev
 *
 * Contra un proyecto real (sin FIRESTORE_EMULATOR_HOST) exige credenciales de
 * administración: `gcloud auth application-default login`, o la variable
 * GOOGLE_APPLICATION_CREDENTIALS apuntando a una clave de cuenta de servicio.
 * Esa clave nunca se guarda dentro del repositorio (RNF-10).
 */

import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { Timestamp, getFirestore } from 'firebase-admin/firestore';

const ROLES_VALIDOS = ['COORDINADOR', 'ADMINISTRADORA', 'CATEDRATICO', 'AUDITOR'] as const;
type RolValido = (typeof ROLES_VALIDOS)[number];

function argumento(nombre: string): string | undefined {
  const prefijo = `--${nombre}=`;
  return process.argv.find((a) => a.startsWith(prefijo))?.slice(prefijo.length);
}

function abortar(mensaje: string): never {
  console.error(`\n${mensaje}\n`);
  console.error('Uso: npm run seed:invitacion -- --correo=alguien@umg.edu.gt --rol=COORDINADOR');
  console.error(`Roles válidos: ${ROLES_VALIDOS.join(' · ')}`);
  process.exit(1);
}

const correoBruto = argumento('correo');
const rolBruto = argumento('rol');
const nombre = argumento('nombre') ?? '';
const proyecto = argumento('proyecto') ?? process.env.FIREBASE_PROJECT_ID ?? 'sian-dev';

if (!correoBruto) {
  abortar('Falta --correo.');
}
if (!rolBruto) {
  abortar('Falta --rol.');
}

// Mismo criterio de normalización que el objeto de valor CorreoInstitucional:
// el id del documento ES el correo en minúsculas (documento 05, sección 2.10).
const correo = correoBruto.trim().toLowerCase();
if (!/^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$/.test(correo)) {
  abortar(`«${correoBruto}» no tiene forma de correo válido.`);
}

const rol = rolBruto.trim().toUpperCase() as RolValido;
if (!ROLES_VALIDOS.includes(rol)) {
  abortar(`Rol desconocido: «${rolBruto}».`);
}

const contraEmulador = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

async function principal(): Promise<void> {
  initializeApp(
    contraEmulador ? { projectId: proyecto } : { projectId: proyecto, credential: applicationDefault() },
  );

  const db = getFirestore();
  const ref = db.doc(`invitaciones/${correo}`);
  const existente = await ref.get();

  if (existente.exists) {
    const datos = existente.data() ?? {};
    console.log(`La invitación para ${correo} ya existía (rol ${datos.rolAsignado as string}).`);
    if (datos.consumida === true) {
      console.log('Ya fue consumida: el usuario existe. Para cambiar su rol, usa el panel.');
      return;
    }
  }

  await ref.set(
    {
      rolAsignado: rol,
      nombre,
      consumida: false,
      creadaPor: 'SCRIPT_SEED',
      creadaEn: Timestamp.now(),
    },
    { merge: true },
  );

  console.log(
    `Invitación registrada: ${correo} → ${rol} en «${proyecto}»` +
      `${contraEmulador ? ' (emulador)' : ''}.`,
  );
  console.log('Al iniciar sesión por primera vez, la Function creará su perfil y sembrará su rol.');
}

principal().catch((e: unknown) => {
  console.error('Falló el registro de la invitación:', e);
  process.exit(1);
});
