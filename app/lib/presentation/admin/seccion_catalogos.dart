/// SIAN — Sección «Catálogos» del panel (2.0 · RF-CAT-01, RF-SED-06, RF-FAC-01).
///
/// Solo las listas (2.0.4). Desde la 2.0.6 las facultades son un catálogo
/// único que mantiene el superadministrador, junto con las sedes; la
/// coordinación elige de él las que ofrece su sede. A qué sede
/// y facultad pertenece cada persona se decide en Usuarios. Cada bloque va
/// contraído, con lo que contiene dicho en su encabezado (2.0.3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_catalogos.dart';
import '../../application/proveedores_sede.dart';
import '../../application/proveedores_sesion.dart';
import '../../domain/rol.dart';
import '../../domain/sesion.dart';
import '../shared/mantenimiento_catalogo.dart';
import 'oferta_facultades.dart';
import '../shared/textos.dart';

class SeccionCatalogos extends ConsumerWidget {
  const SeccionCatalogos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Sesion sesion = ref.watch(sesionActualProvider);
    if (sesion is! SesionActiva) {
      return const SizedBox.shrink();
    }
    final UsuarioSesion usuario = sesion.usuario;
    // Las facultades son las de la sede donde se está trabajando (2.0).
    final String sede = ref.watch(sedeDeTrabajoProvider);
    final String nombreSede =
        ref.watch(nombreDeSedeProvider(sede)).value ?? sede;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        // El catálogo único (2.0.6): solo el superadministrador lo mantiene.
        if (usuario.adminGeneral)
          BloqueDesplegable(
            id: 'catalogo-facultades',
            icono: Icons.school_outlined,
            titulo: Textos.catalogoFacultadesUnico,
            resumen: Textos.resumenCatalogo(
              ref.watch(catalogoFacultadesProvider).value,
              'facultad',
              'facultades',
            ),
            child: MantenimientoCatalogo(
              fuente: ref.watch(fuenteCatalogoFacultadesProvider),
              titulo: Textos.catalogoFacultadesUnico,
              elemento: 'facultad',
              explicacion: Textos.catalogoFacultadesUnicoExplicacion,
              mostrarTitulo: false,
            ),
          ),
        // Qué ofrece la sede: la coordinación, la suya; el superadministrador,
        // cualquiera.
        if (usuario.rol == Rol.coordinador || usuario.adminGeneral)
          BloqueDesplegable(
            id: 'facultades',
            icono: Icons.account_tree_outlined,
            titulo: usuario.adminGeneral
                ? Textos.ofertaPorSede
                : Textos.catalogoFacultadesDe(nombreSede),
            resumen: usuario.adminGeneral
                ? Textos.catalogoFacultadesExplicacion
                : Textos.resumenOferta(
                    ref.watch(facultadesDeLaSedeProvider(sede)).value,
                  ),
            child: OfertaDeFacultades(
              key: ValueKey<String>('oferta-$sede'),
              sedeInicial: sede,
              puedeElegirSede: usuario.adminGeneral,
            ),
          ),
        if (usuario.adminGeneral) ...<Widget>[
          BloqueDesplegable(
            id: 'sedes',
            icono: Icons.location_city_outlined,
            titulo: Textos.catalogoSedes,
            resumen: Textos.resumenCatalogo(
              ref.watch(sedesProvider).value,
              'sede',
              'sedes',
            ),
            child: MantenimientoCatalogo(
              fuente: ref.watch(fuenteSedesProvider),
              titulo: Textos.catalogoSedes,
              elemento: 'sede',
              explicacion: Textos.catalogoSedesExplicacion,
              mostrarTitulo: false,
            ),
          ),
        ] else
          // Que no parezca que falta algo: se dice quién lo mantiene.
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text(Textos.catalogoSedes),
              subtitle: Text(Textos.sedesSoloAdministracionGeneral),
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }
}

/// Un bloque que se abre y se cierra, con su resumen en el encabezado.
///
/// Lleva su propia clave de almacenamiento —y otra distinta para su
/// contenido—: un bloque que cambia de alto dentro de una lista sin ella
/// atasca el desplazamiento, como pasó en Mensajes y en Respuestas (1.6.17).
class BloqueDesplegable extends StatelessWidget {
  const BloqueDesplegable({
    required this.id,
    required this.icono,
    required this.titulo,
    required this.resumen,
    required this.child,
    super.key,
  });

  final String id;
  final IconData icono;
  final String titulo;
  final String resumen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey<String>('catalogos-$id'),
        leading: Icon(icono),
        title: Text(titulo),
        subtitle: Text(resumen),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          KeyedSubtree(
            key: ValueKey<String>('catalogos-$id-contenido'),
            child: child,
          ),
        ],
      ),
    );
  }
}
