/// SIAN — Marcador de sección todavía no construida.
///
/// Dice qué hará la sección, qué requisitos cubre y en qué iteración llega, en
/// lugar de mostrar una maqueta vacía. El documento 08 exige validar el alcance
/// «con software que funcione de verdad, no con maquetas»: una sección que
/// anuncia con precisión lo que va a hacer sirve para revisar el alcance; una
/// pantalla falsa que parece funcionar, no.
library;

import 'package:flutter/material.dart';

class SeccionPendiente extends StatelessWidget {
  const SeccionPendiente({
    required this.titulo,
    required this.descripcion,
    required this.requisitos,
    required this.iteracion,
    super.key,
  });

  final String titulo;
  final String descripcion;

  /// Identificadores del documento 01 que cubrirá esta sección.
  final List<String> requisitos;

  /// Iteración del documento 08 en la que se construye.
  final String iteracion;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(titulo, style: tema.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(descripcion, style: tema.textTheme.bodyLarge),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final String requisito in requisitos)
                    Chip(
                      label: Text(requisito),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.schedule_outlined,
                    size: 18,
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  // Flexible y no fijo: con el texto ampliado por
                  // accesibilidad (RNF-13), una fila rígida desborda.
                  Flexible(
                    child: Text(
                      iteracion,
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
