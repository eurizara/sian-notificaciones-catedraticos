/**
 * SIAN — Punto de entrada de las Cloud Functions.
 *
 * Iteración 1.2. Lo que hay desplegado hoy:
 *
 *   · activarSesion               La puerta del sistema (RF-AUT-03)
 *   · crearInvitaciones           Lista blanca, suelta o por CSV (RF-USR-01)
 *   · revocarInvitacion
 *   · cambiarRol                  RF-USR-02
 *   · cambiarEstadoUsuario        RF-AUT-08, RN-10
 *   · cambiarAutorizacionesFinas  «Según autorización» del documento 01
 *   · guardarGrupo                RF-USR-03, RF-USR-04
 *   · registrarDispositivo        RF-USR-09, RES-05, mitigación de R-01
 *
 * Lo que llega después:
 *
 *   · 1.3 → enviarInmediato, confirmarLectura, registrarDispositivo
 *   · 1.4 → programarMensaje, despachador (Cloud Scheduler), limpiarTokens
 */

export { activarSesion } from './triggers/activarSesion';
export { registrarDispositivo } from './triggers/dispositivos';
export {
  cambiarAutorizacionesFinas,
  cambiarEstadoUsuario,
  cambiarRol,
  crearInvitaciones,
  guardarGrupo,
  revocarInvitacion,
} from './triggers/administracion';

/** El dominio se exporta para que las pruebas y los scripts lo consuman. */
export * as dominio from './domain';
