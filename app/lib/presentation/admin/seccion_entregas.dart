/// SIAN — Reporte de entregas y confirmación (RF-CNF-06, RF-CNF-07, RF-BIT-08).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Un aviso que no pedía confirmación no se mide en confirmaciones.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Mezclarlos hacía que un aviso informativo apareciera para siempre «al 0 %,
/// faltan 40 por confirmar», como si algo hubiera salido mal. No había salido
/// mal: es que nadie tenía que confirmarlo. Para esos la medida real es cuántos
/// lo recibieron — o llegó, o no llegó.
///
/// Tampoco se les pone un 100 % de confirmación, que sería igual de falso en la
/// otra dirección: afirmaría que cuarenta personas confirmaron algo que nunca
/// se les pidió, en un reporte que existe precisamente para sostener esa clase
/// de afirmación delante de quien pregunte.
///
/// Cuando SÍ hubo confirmación, el porcentaje se calcula sobre el TOTAL y no
/// sobre los entregados: a quien no le llegó el aviso tampoco lo confirmó, y
/// con el otro denominador un simulacro daría 100 % teniendo cinco personas sin
/// enterarse — que es exactamente el dato por el que se hace un simulacro.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/proveedores_programacion.dart';
import '../../infrastructure/firebase/repositorio_programacion.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';

class SeccionEntregas extends ConsumerWidget {
  const SeccionEntregas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MensajeProgramado>> lista = ref.watch(
      programadosProvider,
    );

    return lista.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace _) => Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text('$e')),
      ),
      data: (List<MensajeProgramado> todos) {
        final List<MensajeProgramado> enviados = todos
            .where((MensajeProgramado m) => m.totalDestinatarios > 0)
            .toList();

        if (enviados.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(Textos.entregasVacia, textAlign: TextAlign.center),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            for (final MensajeProgramado m in enviados) _Reporte(mensaje: m),
          ],
        );
      },
    );
  }
}

class _Reporte extends StatelessWidget {
  const _Reporte({required this.mensaje});

  final MensajeProgramado mensaje;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final DateFormat formato = DateFormat('dd/MM/yyyy · HH:mm');
    // Un aviso sin confirmación se mide por entrega; uno con ella, por
    // confirmación. Son dos preguntas distintas y no admiten la misma barra.
    final bool porConfirmacion = mensaje.requiereConfirmacion;
    final int porcentaje = porConfirmacion
        ? mensaje.porcentajeConfirmado
        : mensaje.porcentajeEntregado;
    final int pendientes = mensaje.faltanPorConfirmar;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (mensaje.esUrgente)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: ColoresSian.urgente,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      Textos.etiquetaUrgente,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    mensaje.titulo,
                    style: tema.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (mensaje.proximaOcurrencia != null)
              Text(
                formato.format(mensaje.proximaOcurrencia!),
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 12),

            Text(
              Textos.entregasResumen(
                mensaje.entregados,
                mensaje.totalDestinatarios,
              ),
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),

            // La barra usa el mismo denominador que el número: si dijeran
            // cosas distintas, la barra ganaría, porque es lo que se mira.
            LinearProgressIndicator(
              value: porcentaje / 100,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: porcentaje >= 80
                  ? ColoresSian.confirmado
                  : porcentaje >= 40
                  ? ColoresSian.dorado
                  : ColoresSian.urgente,
            ),
            const SizedBox(height: 8),

            if (porConfirmacion) ...<Widget>[
              Text(
                Textos.entregasConfirmados(
                  mensaje.confirmados,
                  mensaje.totalDestinatarios,
                  porcentaje,
                ),
                style: tema.textTheme.bodyMedium,
              ),
              if (pendientes > 0) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  Textos.entregasPendientes(pendientes),
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: ColoresSian.doradoTexto,
                  ),
                ),
              ],
            ] else
              // Ni «faltan N por confirmar» ni un 100 % inventado: se dice lo
              // que pasó, que es que nunca se pidió.
              Text(
                Textos.entregasSinConfirmacion,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
