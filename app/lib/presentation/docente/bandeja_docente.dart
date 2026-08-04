/// SIAN — Bandeja del catedrático (RF-ENT-12).
///
/// Lee de verdad contra Firestore: es la primera pantalla del sistema que
/// muestra datos reales pasando por las reglas de seguridad. Si un catedrático
/// ve aquí un mensaje, es porque las reglas lo dejaron leerlo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/entorno.dart';
import '../../domain/repositorios.dart';
import '../../domain/sesion.dart';
import '../../infrastructure/firebase/repositorio_bandeja.dart';
import '../shared/barra_sesion.dart';
import '../shared/tema.dart';
import '../shared/textos.dart';

final Provider<RepositorioBandeja> repositorioBandejaProvider =
    Provider<RepositorioBandeja>((Ref ref) => RepositorioBandejaFirebase());

final historialProvider =
    StreamProvider.family<List<MensajeRecibido>, String>((Ref ref, String uid) {
      return ref.watch(repositorioBandejaProvider).observarHistorial(uid);
    });

class BandejaDocente extends ConsumerWidget {
  const BandejaDocente({required this.usuario, super.key});

  final UsuarioSesion usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MensajeRecibido>> historial = ref.watch(
      historialProvider(usuario.uid),
    );

    return Scaffold(
      appBar: BarraSesion(
        usuario: usuario,
        titulo: Textos.bandejaTitulo,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: historial.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, StackTrace _) => _Error(detalle: e.toString()),
            data: (List<MensajeRecibido> mensajes) => mensajes.isEmpty
                ? const _BandejaVacia()
                : _Lista(mensajes: mensajes),
          ),
        ),
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.mensajes});

  final List<MensajeRecibido> mensajes;

  @override
  Widget build(BuildContext context) {
    final int sinConfirmar = mensajes
        .where((MensajeRecibido m) => m.exigeAtencion)
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (sinConfirmar > 0)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.priority_high),
              title: Text(
                sinConfirmar == 1
                    ? Textos.bandejaPendienteUno
                    : Textos.bandejaPendienteVarios(sinConfirmar),
              ),
              subtitle: const Text(Textos.bandejaPendienteDetalle),
            ),
          ),
        for (final MensajeRecibido mensaje in mensajes)
          _Fila(key: ValueKey<String>(mensaje.mensajeId), mensaje: mensaje),
        if (Entorno.usaEmulador)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              Textos.avisoEmuladorSinPush,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.mensaje, super.key});

  final MensajeRecibido mensaje;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    // Patrón numérico a propósito: `DateFormat` con nombre de locale exige
    // inicializar los datos de `intl`, y sin eso lanza en tiempo de ejecución.
    // La localización completa entra con RNF-21 en la iteración 1.3.
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
              ],
            ),
            const SizedBox(height: 8),
            Text(mensaje.cuerpo),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Icon(
                  _iconoDeEstado(mensaje.estado),
                  size: 16,
                  color: mensaje.estaConfirmado
                      ? ColoresSian.confirmado
                      : tema.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  _etiquetaDeEstado(mensaje.estado),
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: mensaje.estaConfirmado
                        ? ColoresSian.confirmado
                        : tema.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (mensaje.entregadoEn != null)
                  Text(
                    formato.format(mensaje.entregadoEn!),
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (mensaje.requiereConfirmacion && !mensaje.estaConfirmado) ...[
              const SizedBox(height: 12),
              // Deshabilitado a propósito: confirmar es un acto irreversible
              // con valor probatorio, y solo lo escribe el servidor
              // (RF-CNF-04). La Function llega en la iteración 1.4.
              FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.check),
                label: const Text(Textos.botonConfirmarLectura),
              ),
              const SizedBox(height: 4),
              Text(
                Textos.confirmacionEnIteracion14,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconoDeEstado(String estado) => switch (estado) {
    'CONFIRMADO' => Icons.verified_outlined,
    'ABIERTO' => Icons.drafts_outlined,
    'ENTREGADO' => Icons.mark_email_unread_outlined,
    'FALLIDO' || 'DESCARTADO' => Icons.error_outline,
    _ => Icons.schedule_outlined,
  };

  String _etiquetaDeEstado(String estado) => switch (estado) {
    'CONFIRMADO' => Textos.estadoConfirmado,
    'ABIERTO' => Textos.estadoAbierto,
    'ENTREGADO' => Textos.estadoEntregado,
    'FALLIDO' => Textos.estadoFallido,
    'DESCARTADO' => Textos.estadoDescartado,
    _ => Textos.estadoPendiente,
  };
}

class _BandejaVacia extends StatelessWidget {
  const _BandejaVacia();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.inbox_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          const Text(Textos.bandejaVacia),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.detalle});

  final String detalle;

  @override
  Widget build(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 48, color: tema.colorScheme.error),
            const SizedBox(height: 16),
            Text(Textos.bandejaError, style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            // El detalle se muestra tal cual: en desarrollo, «falta el índice»
            // o «permiso denegado» es exactamente lo que hay que leer.
            Text(
              detalle,
              textAlign: TextAlign.center,
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
