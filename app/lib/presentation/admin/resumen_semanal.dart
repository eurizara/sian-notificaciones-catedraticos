/// SIAN — Cómo llegaron los avisos de la última semana (DT-07, mejora M-1).
///
/// ────────────────────────────────────────────────────────────────────────────
/// «¿Llegó?» se contestaba abriendo mensaje por mensaje.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Entregas muestra un reporte por aviso, y es lo correcto cuando se busca uno
/// concreto. Pero la pregunta de coordinación casi nunca es sobre uno: es «¿los
/// avisos de esta semana llegaron?», y para contestarla había que abrirlos todos
/// y sumar de cabeza.
///
/// Esta tarjeta hace esa suma. No lee nada nuevo: usa los mismos contadores que
/// cada reporte ya trae, así que no puede discrepar de ellos.
///
/// ────────────────────────────────────────────────────────────────────────────
/// El denominador es siempre el total de destinatarios
/// ────────────────────────────────────────────────────────────────────────────
///
/// Es la misma regla que ya siguen los porcentajes de cada reporte: a quien no
/// le llegó el aviso tampoco lo confirmó, y medir la confirmación sobre los
/// entregados daría un 100 % con gente que ni se enteró. Cambiar la base según
/// convenga es la forma más fácil de que un reporte diga lo que uno quiere oír.
library;

import 'package:flutter/material.dart';

import '../../infrastructure/firebase/repositorio_programacion.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';

/// Cuántos días mira la tarjeta.
///
/// Una semana cubre el ritmo de trabajo de una sede —los avisos de lunes a
/// sábado— y es lo bastante corta para que un problema nuevo no quede diluido
/// entre semanas buenas.
const int diasDelResumen = 7;

/// La suma de la semana, ya calculada.
class ResumenSemanal {
  const ResumenSemanal({
    required this.avisos,
    required this.destinatarios,
    required this.entregados,
    required this.conConfirmacion,
    required this.destinatariosConConfirmacion,
    required this.confirmados,
    required this.diasDesdeElUltimo,
  });

  /// Avisos enviados en la ventana.
  final int avisos;

  /// Suma de destinatarios de esos avisos. Una misma persona cuenta una vez por
  /// aviso: lo que se mide son entregas, no personas.
  final int destinatarios;
  final int entregados;

  /// Cuántos de esos avisos pedían confirmación, y sobre cuántas personas.
  ///
  /// La tasa de confirmación se calcula SOLO sobre estos. Mezclar avisos que no
  /// la pedían la hundiría con ceros que nadie tenía obligación de poner.
  final int conConfirmacion;
  final int destinatariosConConfirmacion;
  final int confirmados;

  /// Días desde el último aviso enviado, o `null` si nunca se envió ninguno.
  final int? diasDesdeElUltimo;

  int get sinEntregar => destinatarios - entregados;

  int get porcentajeEntrega =>
      destinatarios == 0 ? 0 : ((entregados / destinatarios) * 100).round();

  int get porcentajeConfirmacion => destinatariosConConfirmacion == 0
      ? 0
      : ((confirmados / destinatariosConConfirmacion) * 100).round();

  bool get hayAvisos => avisos > 0;
}

/// Suma los avisos enviados en los últimos [diasDelResumen] días.
///
/// Es pura a propósito —recibe la lista y la hora— para poder probar cada
/// frontera sin depender del reloj ni de Firebase.
ResumenSemanal calcularResumenSemanal(
  List<MensajeProgramado> mensajes,
  DateTime ahora,
) {
  final DateTime desde = ahora.subtract(const Duration(days: diasDelResumen));

  final List<MensajeProgramado> enviados = mensajes
      .where((MensajeProgramado m) => m.enviadoEn != null && m.totalDestinatarios > 0)
      .toList();

  final List<MensajeProgramado> enLaVentana = enviados
      .where((MensajeProgramado m) => !m.enviadoEn!.isBefore(desde))
      .toList();

  final List<MensajeProgramado> conConfirmacion = enLaVentana
      .where((MensajeProgramado m) => m.requiereConfirmacion)
      .toList();

  DateTime? ultimo;
  for (final MensajeProgramado m in enviados) {
    if (ultimo == null || m.enviadoEn!.isAfter(ultimo)) {
      ultimo = m.enviadoEn;
    }
  }

  int suma(Iterable<MensajeProgramado> lista, int Function(MensajeProgramado) campo) =>
      lista.fold<int>(0, (int total, MensajeProgramado m) => total + campo(m));

  return ResumenSemanal(
    avisos: enLaVentana.length,
    destinatarios: suma(enLaVentana, (MensajeProgramado m) => m.totalDestinatarios),
    // Nunca más entregados que destinatarios: un contador desfasado por un
    // reintento no puede producir un 104 %.
    entregados: suma(
      enLaVentana,
      (MensajeProgramado m) => m.entregados.clamp(0, m.totalDestinatarios),
    ),
    conConfirmacion: conConfirmacion.length,
    destinatariosConConfirmacion: suma(
      conConfirmacion,
      (MensajeProgramado m) => m.totalDestinatarios,
    ),
    confirmados: suma(
      conConfirmacion,
      (MensajeProgramado m) => m.confirmados.clamp(0, m.totalDestinatarios),
    ),
    diasDesdeElUltimo: ultimo == null ? null : ahora.difference(ultimo).inDays,
  );
}

/// La tarjeta que encabeza Entregas.
class TarjetaResumenSemanal extends StatelessWidget {
  const TarjetaResumenSemanal({required this.resumen, super.key});

  final ResumenSemanal resumen;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(Textos.resumenTitulo, style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (!resumen.hayAvisos)
              Text(Textos.resumenSinAvisos(resumen.diasDesdeElUltimo))
            else ...<Widget>[
              Text(
                Textos.resumenEntrega(
                  resumen.porcentajeEntrega,
                  resumen.entregados,
                  resumen.destinatarios,
                ),
                style: tema.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              // Barra y cifra van juntas. La barra sola no se lee sin ver, y el
              // número solo no se compara de un vistazo.
              Semantics(
                label: Textos.resumenEntrega(
                  resumen.porcentajeEntrega,
                  resumen.entregados,
                  resumen.destinatarios,
                ),
                excludeSemantics: true,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: resumen.destinatarios == 0
                        ? 0
                        : resumen.entregados / resumen.destinatarios,
                    minHeight: 8,
                    // Dorado cuando falta alguien, verde cuando llegó a todos.
                    // Nunca rojo: está reservado a lo urgente.
                    color: resumen.sinEntregar == 0
                        ? PaletaSian.de(context).confirmado
                        : PaletaSian.de(context).dorado,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(Textos.resumenDetalle(resumen.avisos, resumen.sinEntregar)),
              if (resumen.conConfirmacion > 0) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  Textos.resumenConfirmacion(
                    resumen.porcentajeConfirmacion,
                    resumen.conConfirmacion,
                  ),
                ),
              ],
              if (resumen.sinEntregar > 0) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  Textos.resumenMirarAlcance,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
