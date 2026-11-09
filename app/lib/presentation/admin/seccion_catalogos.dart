/// SIAN — Sección «Catálogos» del panel (2.0 · RF-CAT-01, RF-SED-06, RF-FAC-01).
///
/// La coordinación mantiene las facultades de su sede; quien tiene la
/// administración general —que le da la coordinación a quien decida—, además,
/// las sedes y en qué sedes está cada persona. Cada bloque va contraído, con lo
/// que contiene dicho en su encabezado: se abre el que se va a usar (2.0.3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_catalogos.dart';
import '../../application/proveedores_sede.dart';
import '../../application/proveedores_sesion.dart';
import '../../domain/rol.dart';
import '../../domain/sesion.dart';
import '../shared/mantenimiento_catalogo.dart';
import '../shared/textos.dart';
import 'personas_y_sedes.dart';

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
        if (usuario.rol == Rol.coordinador)
          BloqueDesplegable(
            id: 'facultades',
            icono: Icons.school_outlined,
            titulo: Textos.catalogoFacultadesDe(nombreSede),
            resumen: Textos.resumenCatalogo(
              ref.watch(facultadesDeLaSedeProvider(sede)).value,
              'facultad',
              'facultades',
            ),
            child: MantenimientoCatalogo(
              fuente: ref.watch(fuenteFacultadesProvider(sede)),
              titulo: Textos.catalogoFacultadesDe(nombreSede),
              elemento: 'facultad',
              explicacion: Textos.catalogoFacultadesExplicacion,
              mostrarTitulo: false,
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
          BloqueDesplegable(
            id: 'personas-y-sedes',
            icono: Icons.manage_accounts_outlined,
            titulo: Textos.personasYSedes,
            resumen: Textos.resumenPersonas(
              ref.watch(usuariosDeTodasLasSedesProvider).value?.length,
            ),
            child: PersonasYSedes(miUid: usuario.uid, mostrarTitulo: false),
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
