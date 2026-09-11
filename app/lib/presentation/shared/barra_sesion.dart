/// SIAN — Barra superior con identidad institucional y de sesión.
///
/// Mostrar el rol vigente no es decorativo: en un sistema donde lo que puedes
/// hacer depende de quién eres, tienes que poder ver quién cree el sistema que
/// eres. Es lo primero que se mira cuando algo «no aparece».
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_sesion.dart';
import '../../core/plataforma/manual.dart';
import '../../core/plataforma/recarga.dart';
import '../../core/ruta_manual.dart';
import '../../domain/sesion.dart';
import 'apariencia.dart';
import 'tema.dart';
import 'textos.dart';

class BarraSesion extends ConsumerWidget implements PreferredSizeWidget {
  const BarraSesion({
    required this.usuario,
    required this.titulo,
    this.recargar = recargarAplicacion,
    this.abrirManualDe = abrirManual,
    super.key,
  });

  final UsuarioSesion usuario;
  final String titulo;

  /// Inyectable: en las pruebas no hay navegador que recargar.
  final void Function() recargar;

  /// Inyectable por el mismo motivo: en las pruebas no hay pestaña que abrir.
  final void Function(String ruta) abrirManualDe;

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
    // El color de lo que va en la barra sale del tema de la barra, no de
    // `onPrimary`: en el tema claro son el mismo blanco, pero en el oscuro la
    // barra es de color superficie y `onPrimary` es azul marino — el nombre y
    // el rol se escribían oscuro sobre oscuro.
    final Color sobreBarra =
        tema.appBarTheme.foregroundColor ?? tema.colorScheme.onSurface;

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
                    style: tema.textTheme.labelLarge?.copyWith(
                      color: sobreBarra,
                    ),
                  ),
                  Text(
                    usuario.rol.etiqueta,
                    overflow: TextOverflow.ellipsis,
                    style: tema.textTheme.bodySmall?.copyWith(
                      // Sin transparencia: al 85 % sobre el azul daba 4.28:1, por
                      // debajo de AA. La jerarquía ya la marca el tamaño.
                      color: sobreBarra,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // ────────────────────────────────────────────────────────────────────
        // RECARGAR, A LA IZQUIERDA DE SALIR.
        // ────────────────────────────────────────────────────────────────────
        //
        // Cerrar sesión se queda en el borde, donde ya estaba: cambiarlo de
        // sitio haría que quien lo busca sin mirar pulse lo que no quería. Y
        // entre los dos hay una separación, porque uno se deshace pulsándolo
        // otra vez y el otro obliga a volver a entrar.
        // ────────────────────────────────────────────────────────────────────
        // EL MANUAL, A LA IZQUIERDA DE RECARGAR (DT-28).
        // ────────────────────────────────────────────────────────────────────
        //
        // Sigue la misma lógica que ya ordena esta barra: cuanto más inocua la
        // acción, más lejos del borde donde está salir. Abrir el manual no
        // cambia nada de la aplicación, así que es la que va más lejos.
        //
        // Es la heurística de Nielsen de ayuda y documentación: la ayuda tiene
        // que estar donde surge la duda. Antes había que conocer la dirección o
        // buscarla en un correo viejo, que es tanto como no tenerla.
        //
        // `IconButton` como los otros dos, y no un widget distinto por ser
        // nuevo: la consistencia también es una heurística. Su `tooltip` es el
        // nombre accesible, y ese nombre dice dónde se abre: en el navegador,
        // en otra pestaña; instalada, en la misma ventana y con un botón para
        // volver.
        IconButton(
          icon: const Icon(Icons.menu_book_outlined),
          tooltip: manualSeAbreEnOtraPestana()
              ? Textos.botonManual
              : Textos.botonManualInstalada,
          onPressed: () => abrirManualDe(rutaDelManual(usuario.rol)),
        ),
        // ────────────────────────────────────────────────────────────────────
        // EN UN TELÉFONO, TRES BOTONES Y NO CUATRO.
        // ────────────────────────────────────────────────────────────────────
        //
        // Con el de apariencia (DT-21) eran cuatro, y el título quedaba en
        // «Mis mensa…». Lo que se usa una vez —la apariencia— y lo que no
        // conviene pulsar sin querer —cerrar sesión— van juntos en el botón
        // de la cuenta, que es donde casi todas las aplicaciones los ponen.
        // El manual y recargar se quedan a un toque.
        //
        // En pantalla ancha sobra sitio y cada cosa sigue en su botón.
        if (hayEspacio) ...<Widget>[
          // La apariencia, entre el manual y recargar: cambia cómo se ve la
          // aplicación, pero se deshace en el mismo sitio y no toca datos.
          const SelectorApariencia(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: Textos.botonRecargar,
            onPressed: recargar,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: Textos.botonSalir,
            onPressed: () => ref.read(repositorioSesionProvider).salir(),
          ),
        ] else ...<Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: Textos.botonRecargar,
            onPressed: recargar,
          ),
          MenuCuenta(usuario: usuario),
        ],
        const SizedBox(width: 8),
      ],
    );
  }
}

enum _AccionCuenta { salir }

/// El botón de la cuenta, en pantalla estrecha: quién está dentro, la
/// apariencia y cerrar sesión.
///
/// Cerrar sesión pasa a pedir dos toques en el teléfono. No es un estorbo: es
/// lo único de la barra que obliga a volver a entrar, y en el borde de la
/// pantalla es fácil pulsarlo con el pulgar sin querer.
class MenuCuenta extends ConsumerWidget {
  const MenuCuenta({required this.usuario, super.key});

  final UsuarioSesion usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData tema = Theme.of(context);
    final PreferenciaTema actual = ref.watch(aparienciaProvider);

    return PopupMenuButton<Object>(
      icon: const Icon(Icons.account_circle_outlined),
      // En pantalla estrecha el nombre no se ve en la barra: quién está dentro
      // se conserva en el nombre accesible del botón.
      tooltip: Textos.botonCuenta(usuario.nombre, usuario.rol.etiqueta),
      onSelected: (Object opcion) {
        if (opcion is PreferenciaTema) {
          ref.read(aparienciaProvider.notifier).elegir(opcion);
        } else if (opcion == _AccionCuenta.salir) {
          ref.read(repositorioSesionProvider).salir();
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<Object>>[
        PopupMenuItem<Object>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                usuario.nombre,
                style: tema.textTheme.titleSmall?.copyWith(
                  color: tema.colorScheme.onSurface,
                ),
              ),
              Text(
                usuario.rol.etiqueta,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<Object>(
          enabled: false,
          height: 32,
          child: Text(
            Textos.apariencia,
            style: tema.textTheme.labelMedium?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final PreferenciaTema p in PreferenciaTema.values)
          CheckedPopupMenuItem<Object>(
            value: p,
            checked: p == actual,
            child: Text(p.etiqueta),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<Object>(
          value: _AccionCuenta.salir,
          child: Row(
            children: <Widget>[
              Icon(Icons.logout),
              SizedBox(width: 12),
              Text(Textos.botonSalir),
            ],
          ),
        ),
      ],
    );
  }
}

