/// SIAN — Sección «Catálogos» del panel (2.0 · RF-CAT-01, RF-SED-06, RF-FAC-01).
///
/// La coordinación mantiene las facultades de su sede; la administración
/// general, además, las sedes. Cada catálogo es el mismo componente
/// ([MantenimientoCatalogo]): lo que cambia es de dónde lee y a quién llama.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_catalogos.dart';
import '../../application/proveedores_sesion.dart';
import '../../domain/rol.dart';
import '../../domain/sesion.dart';
import '../../application/proveedores_sede.dart';
import '../shared/mantenimiento_catalogo.dart';
import 'personas_y_sedes.dart';
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
        if (usuario.rol == Rol.coordinador)
          MantenimientoCatalogo(
            fuente: ref.watch(fuenteFacultadesProvider(sede)),
            titulo: Textos.catalogoFacultadesDe(nombreSede),
            elemento: 'facultad',
            explicacion: Textos.catalogoFacultadesExplicacion,
          ),
        const Divider(height: 48),
        if (usuario.adminGeneral) ...<Widget>[
          MantenimientoCatalogo(
            fuente: ref.watch(fuenteSedesProvider),
            titulo: Textos.catalogoSedes,
            elemento: 'sede',
            explicacion: Textos.catalogoSedesExplicacion,
          ),
          const Divider(height: 48),
          PersonasYSedes(miUid: usuario.uid),
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
