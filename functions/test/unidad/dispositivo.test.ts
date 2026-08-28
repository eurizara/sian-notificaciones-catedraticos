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
  esTokenMuerto,
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

/**
 * Retirar un token muerto — RF-USR-10.
 *
 * ────────────────────────────────────────────────────────────────────────────
 * Equivocarse duele en las dos direcciones, y de formas distintas.
 * ────────────────────────────────────────────────────────────────────────────
 *
 * Dar por muerto un token sano borra el registro de alguien que estaba bien, y
 * esa persona deja de recibir avisos hasta que vuelva a abrir la aplicación:
 * puede no notarlo en semanas. Dar por vivo uno muerto lo deja para siempre, y
 * cada aviso cuenta como fallo — es lo que pasaba en producción, con una
 * persona que tenía nueve tokens muertos y aparecía como no localizable
 * teniendo la aplicación instalada y el permiso concedido.
 */
describe('esTokenMuerto', () => {
  it('el token dado de baja por el servicio de push está muerto', () => {
    expect(esTokenMuerto('messaging/registration-token-not-registered')).toBe(true);
  });

  it('un token con forma inválida está muerto', () => {
    expect(esTokenMuerto('messaging/invalid-registration-token')).toBe(true);
  });

  it('un fallo pasajero NO mata el token', () => {
    // Estos son los que costarían caro: borrar por un problema del momento
    // deja sin avisos a alguien que estaba perfectamente bien.
    for (const pasajero of [
      'messaging/server-unavailable',
      'messaging/internal-error',
      'messaging/quota-exceeded',
      'messaging/unknown-error',
      'messaging/third-party-auth-error',
    ]) {
      expect(esTokenMuerto(pasajero)).toBe(false);
    }
  });

  it('sin código de error no se borra nada', () => {
    // Ante la duda no se borra: recuperar un token perdido exige que la
    // persona abra la aplicación; conservar uno muerto cuesta un intento.
    expect(esTokenMuerto(undefined)).toBe(false);
    expect(esTokenMuerto('')).toBe(false);
  });
});
