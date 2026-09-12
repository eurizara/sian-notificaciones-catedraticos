/**
 * SIAN — Sonda de canal: comprueba que la gente siga alcanzable (DT-22, DT-18).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Un token muerto solo se descubría cuando fallaba un aviso real.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * El 7 de septiembre de 2026 el coordinador mandó un aviso a los 22
 * catedráticos y llegó a 15. Comparando persona por persona con el envío del 29
 * de agosto, **cinco que habían recibido Y CONFIRMADO aquel habían perdido el
 * canal durante los ocho días de silencio**. Nadie podía saberlo: el sistema se
 * entera de que un token murió en el momento en que lo usa.
 *
 * La variable que lo dispara es el tiempo sin mandar nada, que es la condición
 * normal de un sistema de emergencias: por definición calla hasta que hace
 * falta. Cuanto más lleva callado, menos gente le queda escuchando.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Es un envío EN SECO. No le llega nada a nadie.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * `sendEach(mensajes, true)` es el modo de validación de FCM: comprueba el token
 * y no entrega. Sin notificación, sin sonido, sin insignia — el teléfono no se
 * entera. Y devuelve los mismos códigos de error que `esTokenMuerto` ya sabe
 * leer, así que la limpieza es la de siempre.
 *
 * La alternativa evidente —mandar un aviso de canal cada cierto tiempo— **no
 * sirve**, y conviene dejarlo escrito porque es lo primero que uno intenta: en
 * web no existe la notificación invisible. El navegador exige que todo push
 * termine en algo visible, y si el worker no muestra nada lo muestra él con un
 * texto genérico. Repetirlo puede costar la suscripción: mataría justo lo que
 * pretende conservar.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * La sonda DETECTA. No revive.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Un token muerto no se arregla validándolo: hace falta que la persona abra la
 * aplicación. Por eso la mitad visible del trabajo es `dispositivosQueNecesitanAtencion`,
 * que le dice a coordinación a quién buscar antes de necesitarlo.
 */

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import { getMessaging, type TokenMessage } from 'firebase-admin/messaging';

import { exigirPermiso, recibeAvisos, type Sujeto } from '../domain/autorizacion';
import {
  decidirSobreDispositivo,
  esTokenMuerto,
  estadoDeCanal,
  GRAVEDAD_DE_CANAL,
  type DecisionDeSonda,
  type DispositivoAEvaluar,
  type EstadoDeCanal,
} from '../domain/dispositivo';
import { crearAsiento } from '../domain/bitacora';
import type { Rol } from '../domain/tipos';
import { OPCIONES_FUNCION, RUTAS, db } from '../infrastructure/firebase';
import { escribirAsiento } from '../infrastructure/repositorios';

const ZONA_INSTITUCIONAL = 'America/Guatemala';

/**
 * FCM admite 500 mensajes por lote. Con 36 dispositivos en producción sobra,
 * pero el límite se respeta igual: crecer no debe romper esto en silencio.
 */
const TAMANO_LOTE = 400;

/**
 * Cuántas entregas se leen para saber cómo le fue a cada uno la última vez.
 *
 * Con 22 destinatarios, doscientas cubren de sobra los últimos envíos. El
 * límite existe para que esto no crezca sin techo cuando el historial tenga
 * años: lo que importa es lo reciente.
 */
const LIMITE_ENTREGAS_REVISADAS = 200;

/** Un dispositivo tal como lo lee la sonda, con su ubicación en Firestore. */
interface DispositivoLeido extends DispositivoAEvaluar {
  readonly esPWAInstalada: boolean;
  readonly permisoNotificacion: string;
  readonly plataforma: string;
  readonly versionApp: string;
}

function aFecha(valor: unknown): Date | null {
  if (valor && typeof (valor as { toDate?: unknown }).toDate === 'function') {
    return (valor as { toDate: () => Date }).toDate();
  }
  return null;
}

/** Lee todos los dispositivos registrados, de todas las personas. */
async function leerDispositivos(): Promise<DispositivoLeido[]> {
  const instantanea = await db.collectionGroup('dispositivos').get();

  return instantanea.docs.map((d) => ({
    // La ruta es `usuarios/{uid}/dispositivos/{id}`.
    uid: d.ref.parent.parent?.id ?? '',
    id: d.id,
    tokenFCM: ((d.get('tokenFCM') as string | undefined) ?? d.id).trim(),
    ultimaActividad: aFecha(d.get('ultimaActividad')),
    esPWAInstalada: d.get('esPWAInstalada') === true,
    permisoNotificacion: (d.get('permisoNotificacion') as string | undefined) ?? 'pendiente',
    plataforma: (d.get('plataforma') as string | undefined) ?? '',
    versionApp: (d.get('versionApp') as string | undefined) ?? '',
  }));
}

/**
 * Pregunta a FCM cuáles de estos tokens siguen vivos, sin entregar nada.
 *
 * Devuelve el conjunto de los que FCM rechazó **por estar muertos**. Un fallo de
 * otra clase —la red, una cuota— no cuenta como muerte: retirar por eso sería
 * dejar sin avisos a alguien por un problema nuestro.
 */
async function tokensMuertos(dispositivos: readonly DispositivoLeido[]): Promise<Set<string>> {
  const muertos = new Set<string>();

  for (let i = 0; i < dispositivos.length; i += TAMANO_LOTE) {
    const lote = dispositivos.slice(i, i + TAMANO_LOTE);
    const mensajes: TokenMessage[] = lote.map((d) => ({
      token: d.tokenFCM,
      data: { sonda: '1' },
    }));

    // El `true` es todo el asunto: modo de validación, no se entrega nada.
    const respuesta = await getMessaging().sendEach(mensajes, true);

    respuesta.responses.forEach((r, indice) => {
      const dispositivo = lote[indice];
      if (dispositivo && !r.success && esTokenMuerto(r.error?.code)) {
        muertos.add(dispositivo.tokenFCM);
      }
    });
  }

  return muertos;
}

/** Retira un dispositivo, con el motivo anotado en la bitácora. */
async function retirar(
  dispositivo: DispositivoLeido,
  decision: Exclude<DecisionDeSonda, 'conservar'>,
): Promise<void> {
  await db
    .collection(RUTAS.usuarios)
    .doc(dispositivo.uid)
    .collection('dispositivos')
    .doc(dispositivo.id)
    .delete();

  await escribirAsiento(
    crearAsiento({
      tipo: 'DISPOSITIVO_RETIRADO',
      // Quien retira no es una persona: es la sonda. El rol SISTEMA existe
      // justamente para que la bitácora no tenga que inventar un responsable
      // humano en las acciones automáticas.
      actor: { uid: 'sistema', correo: 'sonda@sian', rol: 'SISTEMA' },
      entidad: 'DISPOSITIVO',
      entidadId: dispositivo.id,
      resumen:
        decision === 'retirar-por-muerto'
          ? `Retirado por token muerto (${dispositivo.plataforma})`
          : `Retirado por inactividad (${dispositivo.plataforma})`,
      datos: {
        uid: dispositivo.uid,
        motivo: decision,
        ultimaActividad: dispositivo.ultimaActividad?.toISOString() ?? null,
      },
    }),
  );
}

/**
 * Corre una vez por semana y deja el padrón de dispositivos limpio.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Semanal para empezar, y la propia sonda dirá si es la cadencia correcta.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * El tiempo de vida de un token no lo fija FCM, lo fija cada navegador, y no es
 * uno solo: Safari borra los datos de un sitio sin instalar que no se toca en
 * torno a una semana; Chrome retira permisos de sitios sin uso en meses; iOS
 * rota el token sin plazo fijo. Para iPhone con la aplicación instalada —que es
 * esta población— **no está documentado**.
 *
 * Así que se empieza por el plazo más corto conocido, y cada retiro queda
 * anotado en la bitácora con la antigüedad que tenía. Con dos o tres meses de
 * esos datos, la cadencia se ajusta con hechos de esta población en vez de con
 * cifras generales.
 */
export const sondaDeCanal = onSchedule(
  {
    schedule: 'every day 06:00',
    timeZone: ZONA_INSTITUCIONAL,
    region: 'us-central1',
    memory: '512MiB',
    timeoutSeconds: 300,
    retryCount: 0,
  },
  async () => {
    const ahora = new Date();
    const dispositivos = await leerDispositivos();

    if (dispositivos.length === 0) {
      logger.info('Sonda de canal: no hay dispositivos registrados');
      return;
    }

    const muertos = await tokensMuertos(dispositivos);

    let porMuerto = 0;
    let porInactivo = 0;

    for (const dispositivo of dispositivos) {
      const decision = decidirSobreDispositivo(
        dispositivo,
        !muertos.has(dispositivo.tokenFCM),
        ahora,
      );
      if (decision === 'conservar') {
        continue;
      }

      try {
        await retirar(dispositivo, decision);
        if (decision === 'retirar-por-muerto') {
          porMuerto += 1;
        } else {
          porInactivo += 1;
        }
      } catch (e) {
        // Que no se pueda retirar uno no puede impedir revisar los demás.
        logger.error('Sonda de canal: no se pudo retirar', {
          uid: dispositivo.uid,
          id: dispositivo.id,
          error: String(e),
        });
      }
    }

    logger.info('Sonda de canal completada', {
      revisados: dispositivos.length,
      retiradosPorMuerto: porMuerto,
      retiradosPorInactividad: porInactivo,
      quedan: dispositivos.length - porMuerto - porInactivo,
    });
  },
);

/**
 * A quién le falló el ÚLTIMO aviso que se le mandó de verdad.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Es la única señal que mira un hecho en vez de una condición.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * La validación en seco tiene un punto ciego que se descubrió probando: FCM
 * acepta el token, pero `validate_only` **nunca toca el servicio de push de
 * Apple**, que es donde muere de verdad un registro de Safari. El 10 de
 * septiembre de 2026 la sonda daba «vivo» a un iPhone al que ningún aviso
 * llegaba.
 *
 * El historial de entregas no tiene ese punto ciego, porque registra lo que
 * pasó al mandar de verdad. Y es gratis: ya está escrito.
 *
 * Se mira **el último** y no «alguna vez falló»: alguien que falló en agosto y
 * recibe desde entonces está bien, y sacarlo en la lista sería mandar a
 * coordinación a buscar a quien no hace falta.
 */
async function personasConElUltimoEnvioFallido(): Promise<Map<string, Date>> {
  const fallidos = new Map<string, Date>();

  let instantanea;
  try {
    instantanea = await db
      .collectionGroup('entregas')
      .orderBy('creadaEn', 'desc')
      .limit(LIMITE_ENTREGAS_REVISADAS)
      .get();
  } catch (e) {
    // ────────────────────────────────────────────────────────────────────────
    // Que falte esta señal no puede dejar la pantalla en blanco.
    // ────────────────────────────────────────────────────────────────────────
    //
    // Pasó el 10 de septiembre de 2026: esta consulta necesita un índice de
    // grupo de colección que todavía no existía, y en vez de faltar UNA fila la
    // pantalla entera mostró «No se pudo revisar el alcance».
    //
    // Coordinación se quedó sin ver a los que sí sabíamos detectar por otras
    // vías. Una señal que se añade para informar mejor no puede empeorar lo que
    // ya funcionaba.
    logger.error('No se pudo leer el historial de entregas', { error: String(e) });
    return fallidos;
  }

  // Se recorre de más reciente a más antigua y se conserva solo la primera de
  // cada persona: esa es «la última».
  const vistos = new Set<string>();
  for (const doc of instantanea.docs) {
    const uid = (doc.get('uid') as string | undefined) ?? doc.id;
    if (vistos.has(uid)) {
      continue;
    }
    vistos.add(uid);

    const estado = doc.get('estado') as string | undefined;
    if (estado === 'FALLIDO' || estado === 'DESCARTADO') {
      // Se guarda CUÁNDO falló, no solo que falló: hace falta para saber si la
      // persona hizo algo después y la evidencia ya no describe el presente.
      const cuando = aFecha(doc.get('creadaEn'));
      if (cuando !== null) {
        fallidos.set(uid, cuando);
      }
    }
  }

  return fallidos;
}

/**
 * La versión más alta entre los aparatos de una persona.
 *
 * Se ordena como texto y no por número de versión: con este esquema —dos
 * dígitos como mucho por tramo— coincide, y comparar versiones «de verdad»
 * traería un analizador entero para decidir un dato informativo.
 */
function versionMasReciente(dispositivos: readonly DispositivoLeido[]): string {
  return dispositivos
    .map((d) => d.versionApp.trim())
    .filter((v) => v.length > 0)
    .sort()
    .at(-1) ?? '';
}

/** Lo que la pantalla de coordinación necesita saber de cada persona. */
interface FilaDeAtencion {
  readonly uid: string;
  readonly nombre: string;
  readonly correo: string;
  readonly rol: string;
  readonly estado: EstadoDeCanal;
  readonly plataformas: string[];
  readonly ultimaActividad: string | null;

  /** La versión más reciente entre sus aparatos, vacía si no consta. */
  readonly versionApp: string;
}

function sujetoDe(peticion: {
  auth?: { uid: string; token: Record<string, unknown> };
}): Sujeto {
  if (!peticion.auth) {
    throw new HttpsError('unauthenticated', 'Hay que iniciar sesión.');
  }
  return {
    uid: peticion.auth.uid,
    rol: (peticion.auth.token.rol as Rol | undefined) ?? 'CATEDRATICO',
    activo: peticion.auth.token.activo === true,
    puedeEmitirUrgentes: peticion.auth.token.puedeEmitirUrgentes === true,
    puedeCrearRecurrentes: peticion.auth.token.puedeCrearRecurrentes === true,
  };
}

/**
 * A quién hay que buscar para que vuelva a estar alcanzable (DT-22).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * La sonda sin destinatario no sirve de nada: alguien tiene que enterarse.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Devuelve solo a quien tiene algo que corregir, ordenado **por gravedad y no
 * alfabéticamente**: primero quien no puede recibir nada. Una lista alfabética
 * obliga a leerla entera para encontrar lo urgente.
 *
 * Se excluye a quien está al día: una lista que incluye a todos es una lista que
 * nadie repasa.
 */
export const dispositivosQueNecesitanAtencion = onCall(OPCIONES_FUNCION, async (peticion) => {
  const sujeto = sujetoDe(peticion);
  // Quien puede ver esto es quien puede hacer algo con ello: los mismos que
  // emiten avisos. Es información sobre terceros y no se reparte de más.
  exigirPermiso(sujeto, 'CREAR_AVISO_INFORMATIVO');

  const ahora = new Date();
  const [usuarios, dispositivos] = await Promise.all([
    db.collection(RUTAS.usuarios).get(),
    leerDispositivos(),
  ]);

  // ──────────────────────────────────────────────────────────────────────────
  // Se le pregunta a FCM AHORA, no se confía en lo que diga el documento.
  // ──────────────────────────────────────────────────────────────────────────
  //
  // Un dispositivo puede verse impecable en Firestore —instalado, con permiso,
  // con actividad reciente— y llevar dentro un token que FCM ya rechaza. Desde
  // la base de datos son indistinguibles.
  //
  // Pasó en desarrollo el 10 de septiembre de 2026: un coordinador con un
  // iPhone instalado no recibió el aviso y esta pantalla lo daba por bien.
  //
  // La sonda semanal lo detecta, pero una pantalla que contesta «¿llegaría un
  // aviso si lo mando ahora?» no puede responder con lo que se supo el lunes.
  // Sería el mismo engaño, más lento.
  //
  // Cuesta una validación en seco por dispositivo: no se entrega nada, el
  // teléfono no se entera, y es la diferencia entre una pantalla que informa y
  // una que tranquiliza sin motivo.
  const muertos = await tokensMuertos(dispositivos);
  const falloElUltimo = await personasConElUltimoEnvioFallido();

  const porUid = new Map<string, DispositivoLeido[]>();
  for (const d of dispositivos) {
    const lista = porUid.get(d.uid) ?? [];
    lista.push(d);
    porUid.set(d.uid, lista);
  }

  const filas: FilaDeAtencion[] = [];

  for (const doc of usuarios.docs) {
    if (doc.get('activo') !== true) {
      continue;
    }
    // ────────────────────────────────────────────────────────────────────────
    // La población es EXACTAMENTE la del modo TODOS. Se usa el mismo predicado.
    // ────────────────────────────────────────────────────────────────────────
    //
    // La primera versión filtraba por `rol === 'CATEDRATICO'`, y estaba mal.
    // Quién recibe un aviso no lo decide el rol sino `recibeAvisos`, que es una
    // bandera por persona con el rol como valor por omisión: un coordinador con
    // la bandera encendida ES destinatario.
    //
    // Se vio en desarrollo el 9 de septiembre de 2026. El Alcance decía «los 4
    // catedráticos pueden recibir avisos» y un envío a todos salió a siete, con
    // dos fallos — uno de ellos justo un coordinador que la lista no miraba.
    //
    // Una pantalla que predice quién no va a recibir y calcula sobre otra
    // población no se equivoca a veces: miente siempre, y de la peor forma,
    // diciendo que todo está bien.
    if (!recibeAvisos(doc.get('rol') as Rol, doc.get('recibeAvisos') as boolean | undefined)) {
      continue;
    }

    const suyos = porUid.get(doc.id) ?? [];
    const estado = estadoDeCanal(
      suyos.map((d) => ({ ...d, tokenVivo: !muertos.has(d.tokenFCM) })),
      ahora,
      30,
      falloElUltimo.get(doc.id) ?? null,
    );
    if (estado === 'al-dia') {
      continue;
    }

    const actividades = suyos
      .map((d) => d.ultimaActividad)
      .filter((f): f is Date => f !== null)
      .sort((a, b) => b.getTime() - a.getTime());

    filas.push({
      uid: doc.id,
      nombre: (doc.get('nombre') as string | undefined) ?? '',
      correo: (doc.get('correo') as string | undefined) ?? '',
      rol: (doc.get('rol') as string | undefined) ?? '',
      estado,
      plataformas: [...new Set(suyos.map((d) => d.plataforma).filter((p) => p.length > 0))],
      ultimaActividad: actividades[0]?.toISOString() ?? null,
      versionApp: versionMasReciente(suyos),
    });
  }

  filas.sort((a, b) => {
    const porGravedad = GRAVEDAD_DE_CANAL[a.estado] - GRAVEDAD_DE_CANAL[b.estado];
    return porGravedad !== 0 ? porGravedad : a.nombre.localeCompare(b.nombre, 'es');
  });

  return {
    total: filas.length,
    // El total de destinatarios da la proporción: «5 de 22» dice mucho más que
    // «5». Sale del MISMO criterio que la lista de arriba, no de un filtro
    // parecido: si los dos números se calcularan por separado volverían a
    // discrepar en cuanto alguien cambiara uno.
    catedraticos: usuarios.docs.filter(
      (d) =>
        d.get('activo') === true &&
        recibeAvisos(d.get('rol') as Rol, d.get('recibeAvisos') as boolean | undefined),
    ).length,
    filas,
  };
});
