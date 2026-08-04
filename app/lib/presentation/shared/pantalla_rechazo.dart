/// SIAN — Rechazo de acceso (RF-AUT-03).
///
/// Criterio de aceptación de RF-AUT-03: quien complete correctamente el flujo
/// de autenticación pero no esté autorizado recibe un **rechazo explicativo**,
/// no se le crea perfil, y el intento queda registrado en la bitácora.
///
/// Esta pantalla cubre la parte explicativa. El registro en bitácora lo escribe
/// la Cloud Function, porque el cliente no puede escribir ahí (RF-BIT-03).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_sesion.dart';
import '../../domain/sesion.dart';
import 'textos.dart';

class PantallaRechazo extends ConsumerWidget {
  const PantallaRechazo({required this.motivo, required this.correo, super.key});

  final MotivoRechazo motivo;
  final String correo;

  ({String titulo, String explicacion, String salida}) _contenido() =>
      switch (motivo) {
        MotivoRechazo.fueraDeListaBlanca => (
          titulo: Textos.rechazoNoAutorizadoTitulo,
          explicacion: Textos.rechazoNoAutorizadoExplicacion,
          salida: Textos.rechazoNoAutorizadoSalida,
        ),
        MotivoRechazo.cuentaDesactivada => (
          titulo: Textos.rechazoDesactivadaTitulo,
          explicacion: Textos.rechazoDesactivadaExplicacion,
          salida: Textos.rechazoDesactivadaSalida,
        ),
        MotivoRechazo.sinRolEnElToken => (
          titulo: Textos.rechazoSinRolTitulo,
          explicacion: Textos.rechazoSinRolExplicacion,
          salida: Textos.rechazoSinRolSalida,
        ),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData tema = Theme.of(context);
    final contenido = _contenido();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Icon(
                  Icons.no_accounts_outlined,
                  size: 56,
                  color: tema.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  contenido.titulo,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  contenido.explicacion,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.alternate_email),
                    title: Text(correo),
                    subtitle: const Text(Textos.rechazoCorreoUsado),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  contenido.salida,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyMedium?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.tonal(
                  onPressed: () => ref.read(repositorioSesionProvider).salir(),
                  child: const Text(Textos.botonVolverAIngreso),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
