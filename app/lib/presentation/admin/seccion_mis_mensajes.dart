/// SIAN — La bandeja propia, dentro del panel (RF-ENT-12).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Quien emite avisos también puede ser destinatario de ellos.
/// ────────────────────────────────────────────────────────────────────────────
///
/// Un catedrático a quien se nombra administrador académico para que pueda
/// emitir sigue dando clases. Sin esta sección tendría que salir del panel y
/// entrar con otra cuenta para leer lo que le mandan, y eso obligaría a que
/// una persona tuviera dos cuentas — lo que rompe la bitácora, que registraría
/// dos identidades para un mismo humano, y la confirmación de lectura, que la
/// firmaría la cuenta equivocada.
///
/// Reutiliza la bandeja del catedrático tal cual. Los avisos se leen igual sin
/// importar qué más haga uno en el sistema, y mantener dos pantallas que
/// muestran lo mismo es cómo se llega a que una se quede atrás.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_sesion.dart';
import '../../domain/sesion.dart';
import '../docente/bandeja_docente.dart';

class SeccionMisMensajes extends ConsumerWidget {
  const SeccionMisMensajes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Sesion sesion = ref.watch(sesionActualProvider);

    if (sesion is! SesionActiva) {
      return const Center(child: CircularProgressIndicator());
    }

    // Sin barra propia: ya está la del panel, y dos cabeceras apiladas roban
    // media pantalla en un teléfono.
    return BandejaDocente(usuario: sesion.usuario, conBarraPropia: false);
  }
}
