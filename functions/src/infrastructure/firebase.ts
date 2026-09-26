/**
 * SIAN — Acceso a Firebase desde el servidor.
 *
 * Única puerta de entrada del SDK de administración. El dominio no importa
 * nada de esto (RNF-19), y las Functions lo consumen a través de los
 * repositorios de este archivo en lugar de hablar con Firestore directamente.
 */

import { getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import type { Firestore } from 'firebase-admin/firestore';

if (getApps().length === 0) {
  initializeApp();
}

export const db: Firestore = getFirestore();
export const auth = getAuth();
export { FieldValue, Timestamp };

/**
 * Opciones comunes de toda Function.
 *
 * `maxInstances` es control de gasto, no de rendimiento: sin tope, un bucle
 * accidental podría escalar hasta cientos de instancias y convertir el costo
 * proyectado de 0.00 USD en una factura real (documento 02, sección 12).
 *
 * La región coincide con la de Firestore a propósito: una Function en otra
 * región paga latencia en cada lectura, y a la escala de este sistema eso no
 * compra nada.
 */
export const OPCIONES_FUNCION = {
  region: 'us-central1',
  maxInstances: 10,
} as const;

/**
 * ¿Se rechaza la llamada que no trae un token válido de App Check? (DT-33)
 *
 * Todavía no: primero se **observa**. Con esto en `false`, cada llamada queda
 * en el registro con `"verifications": {"app": "VALID" | "MISSING" | "INVALID"}`
 * y nadie queda fuera. Se cambia a `true` solo cuando, durante al menos una
 * semana, todas las llamadas legítimas digan `VALID` — el procedimiento está en
 * el documento 11, «App Check».
 */
export const EXIGIR_APP_CHECK = false;

/** Opciones de toda función llamable desde la aplicación. */
export const OPCIONES_LLAMABLE = {
  ...OPCIONES_FUNCION,
  enforceAppCheck: EXIGIR_APP_CHECK,
} as const;

// ---------------------------------------------------------------------------
// Rutas de las colecciones (documento 05, sección 2)
// ---------------------------------------------------------------------------

export const RUTAS = {
  usuarios: 'usuarios',
  invitaciones: 'invitaciones',
  grupos: 'grupos',
  mensajes: 'mensajes',
  bitacora: 'bitacora',
  colaDespacho: 'cola_despacho',
  configuracion: 'configuracion',
} as const;

export const DOC_CONFIGURACION = `${RUTAS.configuracion}/institucional`;

/**
 * Convierte los `Date` del dominio en `Timestamp` de Firestore.
 *
 * Guardar fechas como cadena o como número rompería los índices y las
 * consultas por rango, que es justo lo que necesita la bitácora (RF-BIT-05).
 */
export function aTimestamp(fecha: Date): Timestamp {
  return Timestamp.fromDate(fecha);
}
