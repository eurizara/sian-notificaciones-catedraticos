/**
 * SIAN — Punto de entrada de las Cloud Functions.
 *
 * Estado: iteración 1.1 (Cimientos). Esta iteración entrega la capa de dominio
 * y las reglas de seguridad; todavía no hay disparadores desplegados, y eso es
 * intencional según el plan del documento 08:
 *
 *   · 1.2 → onNuevoUsuario, registro de dispositivo, lista blanca
 *   · 1.3 → enviarInmediato, confirmarLectura
 *   · 1.4 → programarMensaje, despachador (Cloud Scheduler), limpiarTokens
 *
 * Mientras tanto se exporta el dominio para que las pruebas y los scripts lo
 * consuman como un módulo normal.
 */

export * as dominio from './domain';
