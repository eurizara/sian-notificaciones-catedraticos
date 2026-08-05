/// SIAN — Lo que está programado (RF-PRG-10, RF-PRG-11, RF-CNF-06, RF-CNF-07).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Suspender y cancelar no son lo mismo, y confundirlos cuesta caro.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Suspender detiene una repetición dejándola lista para volver; cancelar la
/// termina para siempre. La segunda es irreversible, así que se pide con su
/// propio diálogo y se explica la diferencia ahí mismo, no en un manual que
/// nadie va a leer con la reunión encima.
///
/// Un mensaje que ya salió no admite ninguna de las dos: RN-03. Sus botones
/// desaparecen en vez de quedarse inertes, porque un botón que no hace nada
/// invita a pulsarlo otra vez más fuerte.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/proveedores_programacion.dart';
import '../../infrastructure/firebase/repositorio_programacion.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';

class SeccionProgramacion extends ConsumerWidget {
  const SeccionProgramacion({super.key});

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
        // Los inmediatos ya enviados no son «programación»; se ven en el
        // reporte de entregas.
        final List<MensajeProgramado> programados = todos
            .where((MensajeProgramado m) => m.modo != 'INMEDIATO')
            .toList();

        if (programados.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(Textos.programadosVacia, textAlign: TextAlign.center),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            for (final MensajeProgramado m in programados) _Fila(mensaje: m),
          ],
        );
      },
    );
  }
}

class _Fila extends ConsumerWidget {
  const _Fila({required this.mensaje});

  final MensajeProgramado mensaje;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData tema = Theme.of(context);
    final DateFormat formato = DateFormat('dd/MM/yyyy · HH:mm');

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
                Chip(
                  label: Text(Textos.estadoProgramacion(mensaje.estado)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (mensaje.proximaOcurrencia != null)
              Text(
                Textos.proximaSalida(
                  formato.format(mensaje.proximaOcurrencia!),
                ),
                style: tema.textTheme.bodyMedium,
              ),

            if (mensaje.totalDestinatarios > 0) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                Textos.entregasResumen(
                  mensaje.entregados,
                  mensaje.totalDestinatarios,
                ),
                style: tema.textTheme.bodySmall,
              ),
            ],

            if (mensaje.yaSalio) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                Textos.yaEnviadoNoSeToca,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else if (mensaje.sePuedeIntervenir) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  if (mensaje.estaSuspendido)
                    FilledButton.tonalIcon(
                      onPressed: () => _actuar(context, ref, 'REANUDAR'),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text(Textos.accionReanudar),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => _actuar(context, ref, 'SUSPENDER'),
                      icon: const Icon(Icons.pause),
                      label: const Text(Textos.accionSuspender),
                    ),
                  TextButton.icon(
                    onPressed: () => _actuar(context, ref, 'CANCELAR'),
                    style: TextButton.styleFrom(
                      foregroundColor: ColoresSian.urgente,
                    ),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text(Textos.accionCancelar),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _actuar(
    BuildContext context,
    WidgetRef ref,
    String accion,
  ) async {
    // Cancelar es irreversible y se pide con su propio diálogo, que explica
    // la diferencia con suspender justo donde hay que decidirla.
    if (accion == 'CANCELAR') {
      final bool? seguro = await showDialog<bool>(
        context: context,
        builder: (BuildContext c) => AlertDialog(
          title: const Text(Textos.cancelarTitulo),
          content: const Text(Textos.cancelarAviso),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text(Textos.noCancelarNada),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ColoresSian.urgente,
              ),
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text(Textos.accionCancelar),
            ),
          ],
        ),
      );
      if (seguro != true) {
        return;
      }
    }

    if (!context.mounted) {
      return;
    }

    try {
      await ref
          .read(repositorioProgramacionProvider)
          .cambiar(mensajeId: mensaje.id, accion: accion);
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? Textos.errorInesperado),
            backgroundColor: ColoresSian.urgente,
          ),
        );
      }
    }
  }
}
