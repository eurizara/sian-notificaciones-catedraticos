/**
 * SIAN — Envío inmediato (RF-PRG-01, RF-ENT-01..06, RF-ENT-10, RF-ENT-11).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Aquí el sistema deja de prometer y entrega.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Todo pasa por el servidor y nada por el cliente. No es ceremonia: RN-03 dice
 * que un mensaje enviado no se edita ni se borra, y eso no puede quedar a
 * criterio de quien tiene abierta la consola del navegador. El cliente propone;
 * aquí se valida, se resuelve a quién, se despacha y se deja constancia.
 *
 * El orden de las escrituras está elegido, no es casual:
 *
 *   1. Se crea el mensaje y sus entregas ANTES de tocar FCM. Si el proceso
 *      muriera a mitad, queda un mensaje con entregas pendientes —recuperable—
 *      y no un aviso entregado del que no hay rastro.
 *   2. Se despacha por lotes.
 *   3. Se anota el resultado de cada entrega y el resumen del mensaje.
 *
 * Un fallo de FCM para una persona no cancela el envío a las demás: en una
 * emergencia, que a uno no le llegue no puede impedir que le llegue al resto
 * (RF-ENT-11).
 */

import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import type { DocumentReference } from 'firebase-admin/firestore';
import { getMessaging, type TokenMessage } from 'firebase-admin/messaging';

import {
  resolverDestinatarios,
  type CandidatoDestinatario,
  type GrupoResuelto,
} from '../application/resolverDestinatarios';
import { crearAsiento } from '../domain/bitacora';
import { exigirPermiso, type Sujeto } from '../domain/autorizacion';
import { ErrorAutorizacion, ErrorDominio } from '../domain/errores';
import { MensajeFactory, type Mensaje } from '../domain/mensaje';
import type { Adjuntos, Destinatarios, Rol, TipoMensaje } from '../domain/tipos';
import { FieldValue, OPCIONES_FUNCION, RUTAS, aTimestamp, db } from '../infrastructure/firebase';
import { escribirAsiento } from '../infrastructure/repositorios';

/** FCM admite 500 mensajes por lote. Se deja margen. */
const TAMANO_LOTE = 400;

/** Identificador de la ocurrencia de un envío inmediato: solo hay una. */
const OCURRENCIA_INMEDIATA = 'inmediata';

interface PeticionEnvio {
  titulo?: string;
  cuerpo?: string;
  tipo?: TipoMensaje;
  requiereConfirmacion?: boolean;
  destinatarios?: Destinatarios;
  confirmacionUrgente?: boolean;
  /**
   * Identificador reservado por el cliente ANTES de subir los adjuntos.
   *
   * Los adjuntos viven en `mensajes/{id}/…` y las reglas de Storage dependen
   * de esa ruta, pero el mensaje se crea aquí, después. Por eso el cliente lo
   * reserva y lo declara. Se escribe con `create`, que falla si el documento
   * ya existe: sin eso, pasar el identificador de un mensaje ajeno lo pisaría.
   */
  mensajeId?: string;
  adjuntos?: Adjuntos;
}

/** Lee el sujeto del token. La fuente de verdad son los custom claims (RN-01). */
function sujetoDe(peticion: { auth?: { uid: string; token: Record<string, unknown> } }): Sujeto {
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

/** Lee de Firestore lo que la resolución pura necesita para decidir. */
async function leerPadron(
  destinatarios: Destinatarios,
): Promise<{ usuarios: CandidatoDestinatario[]; grupos: GrupoResuelto[] }> {
  const instantanea = await db.collection(RUTAS.usuarios).get();

  const usuarios: CandidatoDestinatario[] = instantanea.docs.map((d) => ({
    uid: d.id,
    activo: d.get('activo') === true,
    rol: (d.get('rol') as Rol | undefined) ?? 'CATEDRATICO',
  }));

  if (destinatarios.modo !== 'GRUPOS') {
    return { usuarios, grupos: [] };
  }

  const ids = destinatarios.gruposIds ?? [];
  const documentos = await Promise.all(
    ids.map((id) => db.collection(RUTAS.grupos).doc(id).get()),
  );

  const grupos: GrupoResuelto[] = documentos
    .filter((d) => d.exists)
    .map((d) => ({
      id: d.id,
      activo: d.get('activo') === true,
      miembros: (d.get('miembros') as string[] | undefined) ?? [],
    }));

  return { usuarios, grupos };
}

/**
 * Cuenta destinatarios sin enviar nada (RF-USR-07).
 *
 * Existe porque enseñar «esto va a 47 personas» **antes** de pulsar enviar es
 * la única oportunidad de detectar que el grupo elegido no era el que se creía.
 * Después ya no hay vuelta atrás: RN-03 lo impide.
 */
export const contarDestinatarios = onCall(OPCIONES_FUNCION, async (peticion) => {
  const sujeto = sujetoDe(peticion);

  try {
    exigirPermiso(sujeto, 'CREAR_AVISO_INFORMATIVO');

    const destinatarios = (peticion.data as { destinatarios?: Destinatarios }).destinatarios;
    if (!destinatarios) {
      throw new HttpsError('invalid-argument', 'Faltan los destinatarios.');
    }

    const { usuarios, grupos } = await leerPadron(destinatarios);
    const resultado = resolverDestinatarios(destinatarios, usuarios, grupos);

    return {
      total: resultado.uids.length,
      excluidos: resultado.excluidos.length,
      // Se detallan los motivos: «43 de 45» sin decir por qué no ayuda a nadie.
      motivos: resultado.excluidos.reduce<Record<string, number>>((acc, e) => {
        acc[e.motivo] = (acc[e.motivo] ?? 0) + 1;
        return acc;
      }, {}),
    };
  } catch (e) {
    throw traducirError(e);
  }
});

/**
 * Redacta, despacha y deja constancia, en una sola llamada.
 *
 * No se parte en «crear» y «enviar» a propósito: un mensaje creado y no
 * despachado por un fallo intermedio es exactamente el estado ambiguo que
 * RN-03 quiere evitar. Aquí, o hay mensaje con entregas, o no hay nada.
 */
export const enviarInmediato = onCall(OPCIONES_FUNCION, async (peticion) => {
  const sujeto = sujetoDe(peticion);
  const datos = peticion.data as PeticionEnvio;
  const correo = (peticion.auth?.token.email as string | undefined) ?? '';

  try {
    const tipo = datos.tipo ?? 'INFORMATIVO';

    // La autorización se comprueba aquí aunque la interfaz ya la respete: una
    // comprobación hecha solo en la interfaz es un defecto de seguridad.
    exigirPermiso(
      sujeto,
      tipo === 'URGENTE' ? 'CREAR_ALERTA_URGENTE' : 'CREAR_AVISO_INFORMATIVO',
    );

    if (datos.requiereConfirmacion === true) {
      exigirPermiso(sujeto, 'EXIGIR_CONFIRMACION');
    }

    if (datos.adjuntos?.audio || datos.adjuntos?.imagen) {
      exigirPermiso(sujeto, 'ADJUNTAR_MULTIMEDIA');
    }

    // RN-06 / RF-MSG-13. El diálogo de la interfaz no basta: quien llame a la
    // Function directamente tiene que pasar por lo mismo.
    if (tipo === 'URGENTE' && datos.confirmacionUrgente !== true) {
      throw new ErrorAutorizacion(
        'FALTA_CONFIRMACION_URGENTE',
        'Una alerta urgente exige una segunda confirmación explícita (RN-06).',
      );
    }

    const destinatarios = datos.destinatarios;
    if (!destinatarios) {
      throw new HttpsError('invalid-argument', 'Faltan los destinatarios.');
    }

    // La fábrica valida longitudes y coherencia. Si algo está mal, lanza aquí
    // y no se escribe nada.
    const mensaje: Mensaje = MensajeFactory.crear({
      titulo: datos.titulo ?? '',
      cuerpo: datos.cuerpo ?? '',
      tipo,
      // La fábrica valida peso, duración y formato (RF-MSG-07, RF-MSG-08) y
      // deduce el `formato` de lo que haya: es imposible declarar «lleva voz»
      // y no adjuntarla.
      adjuntos: datos.adjuntos,
      requiereConfirmacion: datos.requiereConfirmacion ?? false,
      destinatarios,
      programacion: { modo: 'INMEDIATO', zonaHoraria: 'America/Guatemala' },
      creadoPor: sujeto.uid,
    });

    const { usuarios, grupos } = await leerPadron(destinatarios);
    const resolucion = resolverDestinatarios(destinatarios, usuarios, grupos);

    if (resolucion.uids.length === 0) {
      throw new ErrorAutorizacion(
        'SIN_DESTINATARIOS',
        'Nadie recibiría este mensaje. Revisa los destinatarios antes de enviarlo.',
      );
    }

    // Si el cliente reservó identificador para subir adjuntos, se respeta.
    const refMensaje = datos.mensajeId
      ? db.collection(RUTAS.mensajes).doc(datos.mensajeId)
      : db.collection(RUTAS.mensajes).doc();

    // Primero el mensaje y sus entregas; después FCM. Si esto muriera a mitad,
    // queda algo recuperable en vez de un aviso entregado sin rastro.
    //
    // `create` y no `set`: falla si el documento ya existe, que es lo que
    // impide pisar un mensaje ajeno pasando su identificador.
    await refMensaje.create({
      ...mensaje,
      creadoEn: aTimestamp(mensaje.creadoEn),
      estado: 'EN_ENVIO',
      // Lista plana para que las reglas puedan decidir si quien lee es
      // destinatario, cosa que no pueden hacer consultando otra colección
      // (documento 05, sección 2.4).
      destinatariosUids: resolucion.uids,
      totalDestinatarios: resolucion.uids.length,
      resumenEntrega: { entregados: 0, fallidos: 0, abiertos: 0, confirmados: 0 },
      enviadoEn: null,
    });

    // Se anota la creación ANTES de despachar. Si el envío fallara entero,
    // sigue constando quién quiso mandar qué y a cuántos: una bitácora que
    // solo registra lo que salió bien no sirve para investigar nada.
    await escribirAsiento(
      crearAsiento({
        tipo: 'MENSAJE_CREADO',
        actor: { uid: sujeto.uid, correo, rol: sujeto.rol },
        entidad: 'MENSAJE',
        entidadId: refMensaje.id,
        resumen: `${tipo === 'URGENTE' ? 'Alerta urgente' : 'Aviso'} «${mensaje.titulo}» para ${resolucion.uids.length} destinatarios`,
        datos: {
          tipo,
          totalDestinatarios: resolucion.uids.length,
          excluidos: resolucion.excluidos.length,
          requiereConfirmacion: mensaje.requiereConfirmacion,
          modoDestinatarios: destinatarios.modo,
        },
        origen: 'PANEL_WEB',
      }),
    );

    const { entregados, fallidos, estadoFinal } = await ejecutarDespacho(
      refMensaje,
      OCURRENCIA_INMEDIATA,
      mensaje,
      resolucion.uids,
    );

    await escribirAsiento(
      crearAsiento({
        tipo: 'ENVIO_COMPLETADO',
        actor: { uid: sujeto.uid, correo, rol: sujeto.rol },
        entidad: 'MENSAJE',
        entidadId: refMensaje.id,
        resumen: `«${mensaje.titulo}» entregado a ${entregados} de ${resolucion.uids.length}${fallidos > 0 ? `, ${fallidos} sin entregar` : ''}`,
        datos: {
          tipo,
          totalDestinatarios: resolucion.uids.length,
          entregados,
          fallidos,
          excluidos: resolucion.excluidos.length,
          estadoFinal,
        },
        origen: 'PANEL_WEB',
      }),
    );

    return {
      mensajeId: refMensaje.id,
      estado: estadoFinal,
      total: resolucion.uids.length,
      entregados,
      fallidos,
      excluidos: resolucion.excluidos.length,
    };
  } catch (e) {
    throw traducirError(e);
  }
});

/**
 * Crea todas las entregas en estado PENDIENTE antes de tocar FCM.
 *
 * El identificador del documento es el UID: así es imposible por construcción
 * que exista una entrega duplicada para el mismo destinatario.
 */
async function escribirEntregasPendientes(
  refOcurrencia: DocumentReference,
  mensajeId: string,
  uids: readonly string[],
): Promise<void> {
  // Firestore admite 500 operaciones por lote.
  for (let i = 0; i < uids.length; i += TAMANO_LOTE) {
    const lote = db.batch();
    for (const uid of uids.slice(i, i + TAMANO_LOTE)) {
      lote.set(refOcurrencia.collection('entregas').doc(uid), {
        // Duplica el identificador del documento a propósito: las consultas
        // por grupo de colección no pueden filtrar por id, y el historial del
        // catedrático es exactamente esa consulta (documento 05, 2.7).
        uid,
        mensajeId,
        estado: 'PENDIENTE',
        intentos: 0,
        creadaEn: FieldValue.serverTimestamp(),
      });
    }
    await lote.commit();
  }
}

/**
 * Manda el aviso a todos los dispositivos de cada destinatario.
 *
 * Va por lotes de FCM, no de uno en uno: con 200 catedráticos la diferencia
 * entre un envío y doscientos es la diferencia entre cumplir RNF-01 —30
 * segundos— y no cumplirlo.
 */
async function despachar(
  refOcurrencia: DocumentReference,
  mensajeId: string,
  mensaje: {
    titulo: string;
    cuerpo: string;
    tipo: TipoMensaje;
    formato: readonly string[];
  },
  uids: readonly string[],
): Promise<{ entregados: number; fallidos: number }> {
  const esUrgente = mensaje.tipo === 'URGENTE';

  // Solo datos: así el prefijo «URGENTE» y el `requireInteraction` los decide
  // el service worker y no el navegador. Es lo que hace que una alerta se
  // distinga en iOS, donde no se puede definir sonido propio (DT-02).
  const carga: Record<string, string> = {
    tipo: mensaje.tipo,
    titulo: mensaje.titulo,
    cuerpo: mensaje.cuerpo,
    mensajeId,
    // Para que la notificación pueda decir «lleva nota de voz» sin abrir nada.
    formato: mensaje.formato.join(','),
  };

  let entregados = 0;
  let fallidos = 0;

  for (let i = 0; i < uids.length; i += TAMANO_LOTE) {
    const tanda = uids.slice(i, i + TAMANO_LOTE);

    const conTokens = await Promise.all(
      tanda.map(async (uid) => ({
        uid,
        tokens: await tokensDe(uid),
      })),
    );

    const envios: { uid: string; mensaje: TokenMessage }[] = [];
    const sinDispositivo: string[] = [];

    for (const { uid, tokens } of conTokens) {
      if (tokens.length === 0) {
        // No tiene dónde recibir. Se marca como fallido con motivo, que es lo
        // que el emisor necesita ver en el reporte: no es que FCM fallara, es
        // que esa persona nunca registró un dispositivo (RN-02).
        sinDispositivo.push(uid);
        continue;
      }
      for (const token of tokens) {
        envios.push({
          uid,
          mensaje: {
            token,
            data: carga,
            webpush: {
              headers: { Urgency: esUrgente ? 'high' : 'normal' },
              fcmOptions: { link: '/' },
            },
          },
        });
      }
    }

    await marcarSinDispositivo(refOcurrencia, sinDispositivo);
    fallidos += sinDispositivo.length;

    if (envios.length === 0) {
      continue;
    }

    const respuesta = await getMessaging().sendEach(envios.map((e) => e.mensaje));

    // Un destinatario puede tener varios dispositivos: le basta con que uno
    // reciba. Se agrupa por persona antes de decidir si le llegó.
    const porUid = new Map<string, { ok: boolean; error?: string }>();
    respuesta.responses.forEach((r, indice) => {
      const envio = envios[indice];
      /* istanbul ignore next — sendEach devuelve una respuesta por mensaje */
      if (envio === undefined) {
        return;
      }
      const uid = envio.uid;
      const previo = porUid.get(uid);
      porUid.set(uid, {
        ok: (previo?.ok ?? false) || r.success,
        error: r.success ? previo?.error : (r.error?.code ?? 'desconocido'),
      });
    });

    const lote = db.batch();
    for (const [uid, resultado] of porUid) {
      if (resultado.ok) {
        entregados += 1;
      } else {
        fallidos += 1;
      }
      lote.update(refOcurrencia.collection('entregas').doc(uid), {
        estado: resultado.ok ? 'ENTREGADO' : 'FALLIDO',
        enviadoAFcmEn: FieldValue.serverTimestamp(),
        ...(resultado.ok ? { entregadoEn: FieldValue.serverTimestamp() } : {}),
        intentos: FieldValue.increment(1),
        ...(resultado.ok ? {} : { ultimoError: resultado.error ?? 'desconocido' }),
      });
    }
    await lote.commit();
  }

  return { entregados, fallidos };
}

async function marcarSinDispositivo(
  refOcurrencia: DocumentReference,
  uids: readonly string[],
): Promise<void> {
  if (uids.length === 0) {
    return;
  }
  const lote = db.batch();
  for (const uid of uids) {
    lote.update(refOcurrencia.collection('entregas').doc(uid), {
      estado: 'FALLIDO',
      ultimoError: 'SIN_DISPOSITIVO_REGISTRADO',
      intentos: FieldValue.increment(1),
    });
  }
  await lote.commit();
}

/** Identificadores de notificación activos de un usuario (RF-USR-10). */
async function tokensDe(uid: string): Promise<string[]> {
  const instantanea = await db
    .collection(RUTAS.usuarios)
    .doc(uid)
    .collection('dispositivos')
    .where('activo', '==', true)
    .get();

  return instantanea.docs.map((d) => d.id);
}

/** Traduce los errores del dominio a los que entiende el cliente. */
function traducirError(e: unknown): HttpsError {
  if (e instanceof HttpsError) {
    return e;
  }
  if (e instanceof ErrorAutorizacion) {
    return new HttpsError('permission-denied', e.message, { codigo: e.codigo });
  }
  if (e instanceof ErrorDominio) {
    return new HttpsError('invalid-argument', e.message, { codigo: e.codigo });
  }
  logger.error('Fallo enviando el mensaje', { error: String(e) });
  return new HttpsError('internal', 'No se pudo enviar el mensaje.');
}

/**
 * Despacha una ocurrencia concreta de un mensaje que ya existe.
 *
 * ───────────────────────────────────────────────────────────────────────────
 * Los destinatarios se resuelven AHORA, no cuando se programó.
 * ───────────────────────────────────────────────────────────────────────────
 *
 * Entre programar un simulacro y el día del simulacro puede entrar personal
 * nuevo o desactivarse una cuenta. Lo que importa es quién está cuando el
 * aviso sale, no quién estaba cuando alguien lo escribió.
 *
 * La usa el despachador programado (RF-PRG-12) y la comparte con el envío
 * inmediato, para que una alerta programada y una inmediata lleguen
 * exactamente igual.
 */
export async function despacharMensaje(
  refMensaje: DocumentReference,
  ocurrenciaId: string,
): Promise<{ total: number; entregados: number; fallidos: number }> {
  const doc = await refMensaje.get();

  const mensaje = {
    titulo: doc.get('titulo') as string,
    cuerpo: doc.get('cuerpo') as string,
    tipo: doc.get('tipo') as TipoMensaje,
    formato: (doc.get('formato') as string[] | undefined) ?? ['TEXTO'],
  };

  const destinatarios = doc.get('destinatarios') as Destinatarios;
  const { usuarios, grupos } = await leerPadron(destinatarios);
  const resolucion = resolverDestinatarios(destinatarios, usuarios, grupos);

  if (resolucion.uids.length === 0) {
    await refMensaje.update({ estado: 'FALLIDO' });
    return { total: 0, entregados: 0, fallidos: 0 };
  }

  // La lista plana se actualiza en cada ocurrencia: es lo que permite a las
  // reglas decidir si quien lee es destinatario (documento 05, 2.4).
  await refMensaje.update({
    destinatariosUids: resolucion.uids,
    totalDestinatarios: resolucion.uids.length,
  });

  const { entregados, fallidos } = await ejecutarDespacho(
    refMensaje,
    ocurrenciaId,
    mensaje,
    resolucion.uids,
  );

  return { total: resolucion.uids.length, entregados, fallidos };
}

/** Crea la ocurrencia, sus entregas, despacha y deja el resultado escrito. */
async function ejecutarDespacho(
  refMensaje: DocumentReference,
  ocurrenciaId: string,
  mensaje: {
    titulo: string;
    cuerpo: string;
    tipo: TipoMensaje;
    formato: readonly string[];
  },
  uids: readonly string[],
): Promise<{ entregados: number; fallidos: number; estadoFinal: string }> {
  const refOcurrencia = refMensaje.collection('ocurrencias').doc(ocurrenciaId);

  await refOcurrencia.set({
    estado: 'EN_ENVIO',
    programadaPara: FieldValue.serverTimestamp(),
    totalDestinatarios: uids.length,
  });

  await escribirEntregasPendientes(refOcurrencia, refMensaje.id, uids);

  const { entregados, fallidos } = await despachar(
    refOcurrencia,
    refMensaje.id,
    mensaje,
    uids,
  );

  const estadoFinal = fallidos === 0 ? 'ENVIADO' : 'ENVIADO_CON_FALLOS';

  await refMensaje.update({
    estado: estadoFinal,
    enviadoEn: FieldValue.serverTimestamp(),
    'resumenEntrega.entregados': FieldValue.increment(entregados),
    'resumenEntrega.fallidos': FieldValue.increment(fallidos),
  });
  await refOcurrencia.update({
    estado: fallidos === 0 ? 'COMPLETADA' : 'COMPLETADA_CON_FALLOS',
  });

  return { entregados, fallidos, estadoFinal };
}
