/// SIAN — Barra superior con la identidad de quien está dentro.
///
/// Mostrar el rol vigente no es decorativo: en un sistema donde lo que puedes
/// hacer depende de quién eres, tienes que poder ver quién cree el sistema que
/// eres. Es lo primero que se mira cuando algo «no aparece».
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_sesion.dart';
import '../../domain/sesion.dart';
import 'textos.dart';

class BarraSesion extends ConsumerWidget implements PreferredSizeWidget {
  const BarraSesion({required this.usuario, required this.titulo, super.key});

  final UsuarioSesion usuario;
  final String titulo;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData tema = Theme.of(context);

    return AppBar(
      title: Text(titulo),
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(usuario.nombre, style: tema.textTheme.labelLarge),
                Text(
                  usuario.rol.etiqueta,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onPrimary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: Textos.botonSalir,
          onPressed: () => ref.read(repositorioSesionProvider).salir(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
