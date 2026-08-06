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
 *   · enviarInmediato            RF-PRG-01, RF-ENT-01..06
 *   · contarDestinatarios        RF-USR-07
 *   · cambiarEstadoGrupo         RF-USR-04
 *
 * Iteración 1.4:
 *
 *   · programarMensaje           RF-PRG-02, 05
 *   · vistaPreviaOcurrencias     RF-PRG-09
 *   · cambiarProgramacion        RF-PRG-10, 11
 *   · despachador                RF-PRG-12, 13, 14 · RES-04
 *   · marcarAbierto              RF-CNF-02
 *   · confirmarLectura           RF-CNF-01, 03, 04, 05
 */

export { activarSesion } from './triggers/activarSesion';
export { registrarDispositivo } from './triggers/dispositivos';
export { contarDestinatarios, enviarInmediato } from './triggers/envio';
export {
  cambiarProgramacion,
  programarMensaje,
  vistaPreviaOcurrencias,
} from './triggers/programacion';
export { despachador } from './triggers/despachador';
export {
  confirmarLectura,
  detalleEntregas,
  marcarAbierto,
} from './triggers/confirmacion';
export {
  cambiarAutorizacionesFinas,
  cambiarEstadoGrupo,
  cambiarEstadoUsuario,
  cambiarRol,
  crearInvitaciones,
  guardarGrupo,
  revocarInvitacion,
} from './triggers/administracion';

/** El dominio se exporta para que las pruebas y los scripts lo consuman. */
export * as dominio from './domain';
