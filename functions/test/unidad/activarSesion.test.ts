/**
 * Pruebas del alta contra la lista blanca — RF-AUT-03.
 *
 * Es la regla más delicada del sistema: decide quién entra. Por eso se prueban
 * los seis caminos posibles, y se verifica **el criterio de aceptación
 * completo**, no solo que rechace:
 *
 *   · rechazo explicativo
 *   · no se le crea perfil
 *   · el intento queda registrado en la bitácora
 */

import {
  claimsDe,
  decidirActivacion,
  type PerfilUsuario,
  type SolicitudActivacion,
} from '../../src/application/activarSesion';
import type { Invitacion } from '../../src/domain/invitacion';

const ZONA = 'America/Guatemala';
const AHORA = new Date('2026-08-03T13:00:00.000Z');

function invitacion(parcial: Partial<Invitacion> = {}): Invitacion {
  return {
    correo: 'nueva@umg.edu.gt',
    rolAsignado: 'CATEDRATICO',
    nombre: 'Persona Invitada',
    consumida: false,
    creadaPor: 'uid-coordinador',
    creadaEn: AHORA,
    ...parcial,
  };
}

function perfil(parcial: Partial<PerfilUsuario> = {}): PerfilUsuario {
  return {
    uid: 'uid-1',
    correo: 'existente@umg.edu.gt',
    nombre: 'Persona Existente',
    rol: 'CATEDRATICO',
    activo: true,
    proveedorAuth: 'password',
    puedeEmitirUrgentes: false,
    puedeCrearRecurrentes: false,
    zonaHoraria: ZONA,
    ...parcial,
  };
}

function solicitud(parcial: Partial<SolicitudActivacion> = {}): SolicitudActivacion {
  return {
    uid: 'uid-1',
    correo: 'nueva@umg.edu.gt',
    proveedorAuth: 'password',
    invitacion: null,
    perfilExistente: null,
    zonaHorariaInstitucional: ZONA,
    ahora: AHORA,
    ...parcial,
  };
}

describe('Camino 3 · primer acceso con invitación válida', () => {
  it('crea el perfil con el rol que dice la invitación', () => {
    const r = decidirActivacion(
      solicitud({ invitacion: invitacion({ rolAsignado: 'ADMINISTRADORA' }) }),
    );

    expect(r.tipo).toBe('PERFIL_CREADO');
    if (r.tipo !== 'PERFIL_CREADO') return;

    expect(r.perfil.rol).toBe('ADMINISTRADORA');
    expect(r.perfil.activo).toBe(true);
    expect(r.perfil.correo).toBe('nueva@umg.edu.gt');
    expect(r.invitacionConsumida).toBe('nueva@umg.edu.gt');
  });

  it('nadie nace pudiendo emitir urgentes ni crear recurrentes', () => {
    // Las autorizaciones finas las concede el coordinador después, desde el
    // panel. Que una administradora recién dada de alta pudiera lanzar una
    // alerta urgente el primer día sería un defecto, no una comodidad.
    const r = decidirActivacion(
      solicitud({ invitacion: invitacion({ rolAsignado: 'ADMINISTRADORA' }) }),
    );
    if (r.tipo !== 'PERFIL_CREADO') throw new Error('debió crear el perfil');

    expect(r.perfil.puedeEmitirUrgentes).toBe(false);
    expect(r.perfil.puedeCrearRecurrentes).toBe(false);
    expect(r.claims.puedeEmitirUrgentes).toBe(false);
  });

  it('normaliza el correo igual que la clave de la lista blanca', () => {
    const r = decidirActivacion(
      solicitud({ correo: '  Nueva@UMG.EDU.GT ', invitacion: invitacion() }),
    );
    if (r.tipo !== 'PERFIL_CREADO') throw new Error('debió crear el perfil');

    expect(r.perfil.correo).toBe('nueva@umg.edu.gt');
  });

  it('usa el nombre de la invitación y, si falta, el del proveedor', () => {
    const conNombre = decidirActivacion(
      solicitud({ invitacion: invitacion({ nombre: 'Ana Pérez' }) }),
    );
    if (conNombre.tipo !== 'PERFIL_CREADO') throw new Error('debió crear');
    expect(conNombre.perfil.nombre).toBe('Ana Pérez');

    const sinNombre = decidirActivacion(
      solicitud({
        invitacion: invitacion({ nombre: '' }),
        nombreDelProveedor: 'Ana P. (Google)',
      }),
    );
    if (sinNombre.tipo !== 'PERFIL_CREADO') throw new Error('debió crear');
    expect(sinNombre.perfil.nombre).toBe('Ana P. (Google)');
  });

  it('deja asiento USUARIO_CREADO en la bitácora', () => {
    const r = decidirActivacion(solicitud({ invitacion: invitacion() }));
    if (r.tipo !== 'PERFIL_CREADO') throw new Error('debió crear el perfil');

    expect(r.asiento.tipo).toBe('USUARIO_CREADO');
    expect(r.asiento.entidad).toBe('USUARIO');
    expect(r.asiento.entidadId).toBe('uid-1');
    expect(r.asiento.actorCorreo).toBe('nueva@umg.edu.gt');
    expect(r.asiento.ocurridoEn).toEqual(AHORA);
  });
});

describe('RF-AUT-03 · criterio de aceptación del rechazo', () => {
  it('un correo fuera de la lista blanca es rechazado', () => {
    const r = decidirActivacion(solicitud({ correo: 'ajeno@gmail.com' }));

    expect(r.tipo).toBe('RECHAZADO');
    if (r.tipo !== 'RECHAZADO') return;
    expect(r.motivo).toBe('FUERA_DE_LISTA_BLANCA');
  });

  it('no se le crea perfil', () => {
    const r = decidirActivacion(solicitud({ correo: 'ajeno@gmail.com' }));

    // El tipo del resultado no tiene siquiera un campo `perfil`: es imposible
    // por construcción que un rechazo devuelva uno.
    expect(r).not.toHaveProperty('perfil');
    expect(r).not.toHaveProperty('claims');
  });

  it('el intento queda registrado en la bitácora, con el correo usado', () => {
    const r = decidirActivacion(solicitud({ correo: 'ajeno@gmail.com' }));
    if (r.tipo !== 'RECHAZADO') throw new Error('debió rechazar');

    expect(r.asiento.tipo).toBe('SESION_RECHAZADA');
    expect(r.asiento.actorCorreo).toBe('ajeno@gmail.com');
    expect(r.asiento.resumen).toContain('ajeno@gmail.com');
    expect(r.asiento.datos).toMatchObject({ motivo: 'FUERA_DE_LISTA_BLANCA' });
  });

  it('la credencial huérfana se borra', () => {
    // Sin esto quedaría una cuenta autenticable, sin perfil y sin rol, que
    // volvería a intentarlo indefinidamente.
    const r = decidirActivacion(solicitud({ correo: 'ajeno@gmail.com' }));
    if (r.tipo !== 'RECHAZADO') throw new Error('debió rechazar');

    expect(r.borrarCredencial).toBe(true);
  });

  it('rechaza también un correo con forma inválida', () => {
    const r = decidirActivacion(solicitud({ correo: 'esto-no-es-un-correo' }));
    expect(r.tipo).toBe('RECHAZADO');
  });
});

describe('Camino 5 · invitación ya consumida por otra cuenta', () => {
  it('se rechaza en lugar de crear una segunda cuenta para el mismo correo', () => {
    const r = decidirActivacion(
      solicitud({
        uid: 'uid-nuevo',
        invitacion: invitacion({ consumida: true, consumidaPor: 'uid-original' }),
      }),
    );

    expect(r.tipo).toBe('RECHAZADO');
    if (r.tipo !== 'RECHAZADO') return;
    expect(r.borrarCredencial).toBe(true);
    expect(r.asiento.datos).toMatchObject({ consumidaPor: 'uid-original' });
  });

  it('pero el dueño legítimo puede volver a entrar', () => {
    const r = decidirActivacion(
      solicitud({
        uid: 'uid-original',
        invitacion: invitacion({ consumida: true, consumidaPor: 'uid-original' }),
      }),
    );

    expect(r.tipo).toBe('PERFIL_CREADO');
  });
});

describe('Camino 1 · usuario que ya tiene perfil', () => {
  it('acepta la sesión y refresca los claims desde el perfil', () => {
    const existente = perfil({ rol: 'COORDINADOR', puedeEmitirUrgentes: true });
    const r = decidirActivacion(solicitud({ perfilExistente: existente }));

    expect(r.tipo).toBe('SESION_ACEPTADA');
    if (r.tipo !== 'SESION_ACEPTADA') return;

    expect(r.claims).toEqual(claimsDe(existente));
    expect(r.claims.rol).toBe('COORDINADOR');
    expect(r.claims.puedeEmitirUrgentes).toBe(true);
    expect(r.asiento.tipo).toBe('SESION_INICIADA');
  });

  it('el perfil manda sobre la invitación si ambos existen', () => {
    // Un cambio de rol hecho por el coordinador no puede quedar revertido
    // porque la invitación original dijera otra cosa.
    const r = decidirActivacion(
      solicitud({
        perfilExistente: perfil({ rol: 'AUDITOR' }),
        invitacion: invitacion({ rolAsignado: 'CATEDRATICO' }),
      }),
    );
    if (r.tipo !== 'SESION_ACEPTADA') throw new Error('debió aceptar');

    expect(r.claims.rol).toBe('AUDITOR');
  });
});

describe('Camino 2 · RN-10 · cuenta desactivada', () => {
  it('se rechaza con motivo propio, distinto de «no autorizado»', () => {
    const r = decidirActivacion(
      solicitud({ perfilExistente: perfil({ activo: false }) }),
    );

    expect(r.tipo).toBe('RECHAZADO');
    if (r.tipo !== 'RECHAZADO') return;
    expect(r.motivo).toBe('CUENTA_DESACTIVADA');
  });

  it('NO se borra la credencial: la cuenta puede reactivarse', () => {
    // RN-10: un usuario desactivado deja de recibir mensajes pero conserva
    // íntegro su historial. Borrar su credencial rompería la reactivación.
    const r = decidirActivacion(
      solicitud({ perfilExistente: perfil({ activo: false }) }),
    );
    if (r.tipo !== 'RECHAZADO') throw new Error('debió rechazar');

    expect(r.borrarCredencial).toBe(false);
  });

  it('deja asiento con el rol que tenía', () => {
    const r = decidirActivacion(
      solicitud({ perfilExistente: perfil({ activo: false, rol: 'ADMINISTRADORA' }) }),
    );
    if (r.tipo !== 'RECHAZADO') throw new Error('debió rechazar');

    expect(r.asiento.actorRol).toBe('ADMINISTRADORA');
  });
});
