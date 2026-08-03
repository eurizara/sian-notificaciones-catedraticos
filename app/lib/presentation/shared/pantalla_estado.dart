/// SIAN — Pantalla de estado del sistema.
///
/// Es la pantalla provisional de la iteración 1.1: dice con honestidad qué
/// está construido y qué no, en lugar de fingir una interfaz que todavía no
/// existe. La sustituye la pantalla de inicio de sesión en la iteración 1.2.
library;

import 'package:flutter/material.dart';

import '../../core/entorno.dart';
import 'textos.dart';

enum EstadoPieza { listo, enCurso, pendiente }

@immutable
class Pieza {
  const Pieza({
    required this.nombre,
    required this.detalle,
    required this.estado,
  });

  final String nombre;
  final String detalle;
  final EstadoPieza estado;
}

class PantallaEstado extends StatelessWidget {
  const PantallaEstado({super.key});

  List<Pieza> _piezas() => <Pieza>[
    const Pieza(
      nombre: Textos.cimientosListos,
      detalle: Textos.cimientosDetalle,
      estado: EstadoPieza.listo,
    ),
    const Pieza(
      nombre: Textos.flutterListo,
      detalle: Textos.flutterDetalle,
      estado: EstadoPieza.listo,
    ),
    Pieza(
      nombre: Textos.firebasePendiente,
      detalle: Entorno.usaEmulador
          ? Textos.firebaseDetalleEmulador
          : (Entorno.configuracionCompleta
                ? Textos.firebaseDetalleNube
                : Textos.firebaseDetallePendiente),
      estado: Entorno.configuracionCompleta
          ? EstadoPieza.enCurso
          : EstadoPieza.pendiente,
    ),
    const Pieza(
      nombre: Textos.autenticacionPendiente,
      detalle: Textos.autenticacionDetalle,
      estado: EstadoPieza.pendiente,
    ),
    const Pieza(
      nombre: Textos.notificacionesPendiente,
      detalle: Textos.notificacionesDetalle,
      estado: EstadoPieza.pendiente,
    ),
    const Pieza(
      nombre: Textos.programacionPendiente,
      detalle: Textos.programacionDetalle,
      estado: EstadoPieza.pendiente,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(Textos.nombreApp),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                Textos.nombreCompleto,
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              Text(Textos.tituloEstado, style: tema.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                Textos.subtituloEstado,
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              for (final Pieza pieza in _piezas())
                _FilaPieza(key: ValueKey<String>(pieza.nombre), pieza: pieza),
              if (Entorno.usaEmulador) ...<Widget>[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.info_outline,
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(Textos.avisoEmuladorSinPush),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaPieza extends StatelessWidget {
  const _FilaPieza({required this.pieza, super.key});

  final Pieza pieza;

  ({IconData icono, Color color, String etiqueta}) _aspecto(ColorScheme c) =>
      switch (pieza.estado) {
        EstadoPieza.listo => (
          icono: Icons.check_circle,
          color: c.primary,
          etiqueta: Textos.listo,
        ),
        EstadoPieza.enCurso => (
          icono: Icons.autorenew,
          color: c.tertiary,
          etiqueta: Textos.enCurso,
        ),
        EstadoPieza.pendiente => (
          icono: Icons.radio_button_unchecked,
          color: c.outline,
          etiqueta: Textos.pendiente,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final aspecto = _aspecto(tema.colorScheme);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(aspecto.icono, color: aspecto.color),
        title: Text(pieza.nombre),
        subtitle: Text(pieza.detalle),
        trailing: Text(
          aspecto.etiqueta,
          style: tema.textTheme.labelLarge?.copyWith(color: aspecto.color),
        ),
      ),
    );
  }
}
