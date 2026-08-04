/**
 * SIAN — Superficie pública de la capa de dominio.
 *
 * Las capas de aplicación e infraestructura importan de aquí, nunca de rutas
 * internas. El dominio no importa nada de Firebase (RNF-19): si algún día
 * aparece un `import ... from 'firebase-admin'` en esta carpeta, es un defecto
 * de arquitectura, no un detalle.
 */

export * from './tipos';
export * from './errores';
export * from './objetosDeValor';
export * from './politicaContrasena';
export * from './autorizacion';
export * from './mensaje';
export * from './bitacora';
export * from './invitacion';
export * from './grupo';
export * from './estados/maquinaEstados';
export * from './recurrencia/estrategiaRecurrencia';
export * from './recurrencia/estrategias';
export * from './recurrencia/fabricaRecurrencia';
export * from './recurrencia/planificacion';
