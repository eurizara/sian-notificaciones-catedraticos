/**
 * Pruebas de dispositivos — RF-USR-09, RES-05, RN-02.
 *
 * La regla que más importa aquí no es de validación sino de plataforma: en
 * iOS, un dispositivo con permiso concedido **sigue sin poder recibir nada**
 * si la PWA no está instalada en la pantalla de inicio. Ese matiz es el que
 * convierte el instructivo de instalación en parte del producto.
 */

import {
  crearDispositivo,
  motivoPorElQueNoRecibe,
  puedeRecibirNotificaciones,
  type Dispositivo,
} from '../../src/domain/dispositivo';
import { esperarCodigo } from './ayudas';

const TOKEN = 'fcm-token-de-prueba-suficientemente-largo';

function dispositivo(parcial: Partial<Dispositivo> = {}): Dispositivo {
  return crearDispositivo({
    tokenFCM: TOKEN,
    plataforma: 'WEB_ANDROID',
    permisoNotificacion: 'concedido',
    ...parcial,
  });
}

describe('validación', () => {
  it('normaliza la plataforma y recorta el navegador', () => {
    const d = crearDispositivo({
      tokenFCM: TOKEN,
      plataforma: '  web_ios ',
      navegador: 'x'.repeat(300),
      permisoNotificacion: 'concedido',
    });
    expect(d.plataforma).toBe('WEB_IOS');
    expect(d.navegador.length).toBe(120);
  });

  it('rechaza un token que no tiene forma de token', () => {
    esperarCodigo(
      () => crearDispositivo({ tokenFCM: 'corto', plataforma: 'WEB_ANDROID' }),
      'TOKEN_FCM_INVALIDO',
    );
  });

  it('rechaza una plataforma desconocida', () => {
    esperarCodigo(
      () => crearDispositivo({ tokenFCM: TOKEN, plataforma: 'NOKIA_3310' }),
      'PLATAFORMA_INVALIDA',
    );
  });

  it('un dispositivo sin permiso nace inactivo', () => {
    expect(dispositivo({ permisoNotificacion: 'pendiente' }).activo).toBe(false);
    expect(dispositivo({ permisoNotificacion: 'denegado' }).activo).toBe(false);
    expect(dispositivo({ permisoNotificacion: 'concedido' }).activo).toBe(true);
  });
});

describe('RES-05 · iOS exige la PWA instalada', () => {
  it('en iOS con permiso pero SIN instalar, no puede recibir', () => {
    // Es el caso que más daño hace: el catedrático concedió el permiso, cree
    // que está cubierto, y no le va a llegar absolutamente nada.
    const d = dispositivo({
      plataforma: 'WEB_IOS',
      esPWAInstalada: false,
      permisoNotificacion: 'concedido',
    });
    expect(puedeRecibirNotificaciones(d)).toBe(false);
    expect(motivoPorElQueNoRecibe(d)).toBe('IOS_SIN_INSTALAR');
  });

  it('en iOS instalada y con permiso, sí puede', () => {
    const d = dispositivo({
      plataforma: 'WEB_IOS',
      esPWAInstalada: true,
      permisoNotificacion: 'concedido',
    });
    expect(puedeRecibirNotificaciones(d)).toBe(true);
    expect(motivoPorElQueNoRecibe(d)).toBeNull();
  });

  it('Android y escritorio no dependen de estar instalados', () => {
    for (const plataforma of ['WEB_ANDROID', 'WEB_ESCRITORIO'] as const) {
      const d = dispositivo({ plataforma, esPWAInstalada: false });
      expect(puedeRecibirNotificaciones(d)).toBe(true);
    }
  });
});

describe('motivo por el que no recibe', () => {
  it('distingue permiso denegado de permiso no concedido', () => {
    // No es lo mismo: uno exige ir a los ajustes del navegador, el otro solo
    // pulsar un botón (RES-07).
    expect(motivoPorElQueNoRecibe(dispositivo({ permisoNotificacion: 'denegado' }))).toBe(
      'PERMISO_DENEGADO',
    );
    expect(motivoPorElQueNoRecibe(dispositivo({ permisoNotificacion: 'pendiente' }))).toBe(
      'PERMISO_NO_CONCEDIDO',
    );
  });

  it('el permiso pesa más que la plataforma', () => {
    const d = dispositivo({
      plataforma: 'WEB_IOS',
      esPWAInstalada: false,
      permisoNotificacion: 'denegado',
    });
    // Sin permiso no llega nada, esté o no instalada: se informa lo primero
    // que hay que resolver.
    expect(motivoPorElQueNoRecibe(d)).toBe('PERMISO_DENEGADO');
  });

  it('devuelve null solo cuando de verdad puede recibir', () => {
    expect(motivoPorElQueNoRecibe(dispositivo())).toBeNull();
  });
});
