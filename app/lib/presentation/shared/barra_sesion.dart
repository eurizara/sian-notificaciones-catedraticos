/// SIAN — Barra superior con identidad institucional y de sesión.
///
/// Mostrar el rol vigente no es decorativo: en un sistema donde lo que puedes
/// hacer depende de quién eres, tienes que poder ver quién cree el sistema que
/// eres. Es lo primero que se mira cuando algo «no aparece».
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_sesion.dart';
import '../../domain/sesion.dart';
import 'tema.dart';
import 'textos.dart';

class BarraSesion extends ConsumerWidget implements PreferredSizeWidget {
  const BarraSesion({required this.usuario, required this.titulo, super.key});

  final UsuarioSesion usuario;
  final String titulo;

  /// Por debajo de este ancho se oculta el bloque de identidad y queda solo el
  /// menú de la cuenta: en un teléfono, el nombre completo no cabe sin empujar
  /// el título fuera de la pantalla.
  static const double _anchoMinimoParaIdentidad = 600;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData tema = Theme.of(context);
    final bool hayEspacio =
        MediaQuery.sizeOf(context).width >= _anchoMinimoParaIdentidad;

    return AppBar(
      title: Row(
        // Sin esto la fila reclama todo el ancho disponible y desplaza las
        // acciones fuera de la pantalla.
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Fondo blanco tras el escudo: sobre el azul de la barra, el anillo
          // rojo perdería definición.
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const EscudoUmg(tamano: 26),
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(titulo, overflow: TextOverflow.ellipsis)),
        ],
      ),
      actions: <Widget>[
        if (hayEspacio)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    usuario.nombre,
                    overflow: TextOverflow.ellipsis,
                    style: tema.textTheme.labelLarge,
                  ),
                  Text(
                    usuario.rol.etiqueta,
                    overflow: TextOverflow.ellipsis,
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.logout),
          // En pantalla estrecha el nombre no se ve, así que quién está dentro
          // se conserva en la ayuda emergente.
          tooltip: hayEspacio
              ? Textos.botonSalir
              : '${Textos.botonSalir} · ${usuario.nombre} '
                    '(${usuario.rol.etiqueta})',
          onPressed: () => ref.read(repositorioSesionProvider).salir(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
