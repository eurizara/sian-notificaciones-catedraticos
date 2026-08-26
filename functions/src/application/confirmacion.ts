/**
 * SIAN — Reglas de la confirmación de lectura (RF-CNF-01..07).
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * Confirmar es irreversible y tiene valor probatorio.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Cuando alguien pregunte «¿quién sabía del simulacro?», la respuesta sale de
 * aquí. Por eso una confirmación no se edita, no se deshace y no se duplica
 * (RF-CNF-04, RF-CNF-05), y por eso **abrir no es confirmar** (RF-CNF-02):
 * abrir dice que la aplicación mostró el mensaje; confirmar dice que una
 * persona declaró haberlo leído. Mezclarlos convertiría una evidencia en una
 * suposición.
 */

import { ErrorValidacion } from '../domain/errores';
import { maquinaEntrega } from '../domain/estados/maquinaEstados';
import type { EstadoEntrega } from '../domain/tipos';

export interface ResumenConfirmacion {
  readonly total: number;
  readonly entregados: number;
  readonly abiertos: number;
  readonly confirmados: number;
  readonly fallidos: number;
}

/**
 * Porcentaje de confirmación sobre el total de destinatarios (RF-CNF-07).
 *
 * El denominador es el total, no los entregados. Es deliberado y es lo único
 * honesto: a quien no le llegó el aviso tampoco lo confirmó, y esconderlo del
 * cálculo daría un 100 % con gente sin enterarse.
 */
export function porcentajeConfirmacion(resumen: ResumenConfirmacion): number {
  if (resumen.total <= 0) {
    return 0;
  }
  return Math.round((resumen.confirmados / resumen.total) * 100);
}

/**
 * ¿Se puede confirmar una entrega en este estado?
 *
 * Lanza con un motivo distinto según el caso, porque cada uno se responde
 * distinto a quien pregunte: una ya confirmada no es un error del sistema, y
 * una que nunca se entregó sí es algo que revisar.
 */
export function exigirConfirmable(estado: EstadoEntrega): void {
  if (estado === 'CONFIRMADO') {
    // RF-CNF-05. No es un fallo: es que ya estaba hecho.
    throw new ErrorValidacion(
      'YA_CONFIRMADO',
      'Este mensaje ya estaba confirmado. Una confirmación no se repite ni se deshace.',
    );
  }

  if (estado === 'PENDIENTE' || estado === 'ENVIADO_A_FCM') {
    throw new ErrorValidacion(
      'ENTREGA_NO_COMPLETADA',
      'Este mensaje todavía no consta como entregado en este dispositivo.',
      { estado },
    );
  }

  if (estado === 'FALLIDO' || estado === 'DESCARTADO') {
    throw new ErrorValidacion(
      'ENTREGA_FALLIDA',
      'Este mensaje no llegó a entregarse, así que no puede confirmarse.',
      { estado },
    );
  }
}

/**
 * Estado resultante de abrir un mensaje (RF-CNF-02).
 *
 * Abrir nunca retrocede ni adelanta: una entrega ya confirmada sigue
 * confirmada, y una que aún no llegó no se marca como abierta por el hecho de
 * que la pantalla la pintara.
 */
export function estadoTrasAbrir(actual: EstadoEntrega): EstadoEntrega {
  if (actual !== 'ENTREGADO') {
    return actual;
  }
  return maquinaEntrega.puedeTransicionar(actual, 'ABIERTO') ? 'ABIERTO' : actual;
}
