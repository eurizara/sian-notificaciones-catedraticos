/**
 * El acuse de que el aparato mostró la notificación — DT-31, C-5.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Existe porque «entregado» resultó no querer decir lo que parecía.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * El 11 de septiembre de 2026 un aviso salió a 23 personas; el reporte dijo 18
 * entregados y varias de esas 18 nunca vieron la notificación. Lo que se prueba
 * aquí es lo que decide cuándo insistir y qué se acepta como acuse: si esto se
 * relaja, se vuelve a la situación anterior sin que nadie lo note.
 */

import {
  MINUTOS_SIN_ACUSE_PARA_REINTENTAR,
  REINTENTOS_POR_FALTA_DE_ACUSE,
  SEGUNDOS_DE_VIDA_INFORMATIVO,
  SEGUNDOS_DE_VIDA_URGENTE,
  armarSeña,
  cabecerasDeEnvio,
  leerSeña,
  necesitaReintento,
} from '../../src/domain/acuse';
import { esperarCodigo } from './ayudas';

describe('cabeceras de envío', () => {
  it('TODO aviso sale con prioridad alta, no solo el urgente', () => {
    // Con urgencia normal el servicio de push puede retener el mensaje hasta
    // que el aparato salga del reposo. Es lo que describieron varias personas:
    // no sonó, y el aviso apareció al abrir la aplicación.
    expect(cabecerasDeEnvio(false).Urgency).toBe('high');
    expect(cabecerasDeEnvio(true).Urgency).toBe('high');
  });

  it('un urgente se guarda menos tiempo que un informativo', () => {
    // Un urgente que llega seis horas tarde ya no es un urgente.
    expect(Number(cabecerasDeEnvio(true).TTL)).toBe(SEGUNDOS_DE_VIDA_URGENTE);
    expect(Number(cabecerasDeEnvio(false).TTL)).toBe(SEGUNDOS_DE_VIDA_INFORMATIVO);
    expect(SEGUNDOS_DE_VIDA_URGENTE).toBeLessThan(SEGUNDOS_DE_VIDA_INFORMATIVO);
  });

  it('siempre lleva vida útil: sin ella, FCM lo guarda cuatro semanas', () => {
    // Un «mañana hay actividades» que aparece el jueves siguiente desinforma.
    expect(cabecerasDeEnvio(false).TTL).toBeDefined();
    expect(cabecerasDeEnvio(true).TTL).toBeDefined();
  });
});

describe('la seña que viaja en el push', () => {
  it('va y vuelve entera', () => {
    const seña = armarSeña('oc-1', 'uid-catedratico', 'a1b2c3d4e5f6a7b8');
    expect(leerSeña(seña)).toEqual({
      ocurrenciaId: 'oc-1',
      uid: 'uid-catedratico',
      acuseId: 'a1b2c3d4e5f6a7b8',
    });
  });

  it('lo que no tiene su forma se rechaza', () => {
    // Estos tres valores acaban siendo una ruta de Firestore, y vienen de
    // fuera: una barra de más apuntaría a otro documento.
    for (const basura of [
      '',
      'sin-barras',
      'oc-1|uid',
      'oc-1|uid|corto',
      'oc/1|uid|a1b2c3d4e5f6a7b8',
      '../otro|uid|a1b2c3d4e5f6a7b8',
      undefined,
      42,
    ]) {
      esperarCodigo(() => leerSeña(basura), 'SEÑA_INVALIDA');
    }
  });
});

describe('cuándo se insiste', () => {
  const ahora = new Date('2026-09-11T17:30:00Z');
  const haceMinutos = (m: number) => new Date(ahora.getTime() - m * 60000);
  const base = {
    estado: 'ENTREGADO',
    mostradaEn: null,
    enviadoAFcmEn: haceMinutos(MINUTOS_SIN_ACUSE_PARA_REINTENTAR),
    reintentosPorAcuse: 0,
  };

  it('llegó, nadie dijo que se mostrara y pasaron los minutos de gracia', () => {
    expect(necesitaReintento(base, ahora)).toBe(true);
  });

  it('todavía no: puede estar por mostrarse', () => {
    expect(necesitaReintento({ ...base, enviadoAFcmEn: haceMinutos(2) }, ahora)).toBe(false);
  });

  it('si el aparato ya dijo que la mostró, no se insiste', () => {
    expect(necesitaReintento({ ...base, mostradaEn: haceMinutos(9) }, ahora)).toBe(false);
  });

  it('si la persona ya lo abrió, tampoco: ya lo vio', () => {
    // Es lo único que se perseguía. Insistir sería ruido.
    for (const estado of ['ABIERTO', 'CONFIRMADO']) {
      expect(necesitaReintento({ ...base, estado }, ahora)).toBe(false);
    }
  });

  it('lo que nunca llegó no se reintenta por aquí', () => {
    // Un fallo de entrega se resuelve con el dispositivo, no insistiendo.
    for (const estado of ['FALLIDO', 'PENDIENTE', 'ENVIADO_A_FCM', 'DESCARTADO']) {
      expect(necesitaReintento({ ...base, estado }, ahora)).toBe(false);
    }
  });

  it('se insiste UNA vez, no dos', () => {
    // Si dos empujones no aparecieron, lo que falla son los ajustes del
    // teléfono, y eso lo arregla una persona.
    expect(
      necesitaReintento({ ...base, reintentosPorAcuse: REINTENTOS_POR_FALTA_DE_ACUSE }, ahora),
    ).toBe(false);
  });

  it('sin fecha de envío no se decide nada', () => {
    expect(necesitaReintento({ ...base, enviadoAFcmEn: null }, ahora)).toBe(false);
  });
});
