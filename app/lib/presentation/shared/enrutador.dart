/// SIAN — Enrutado por estado de sesión.
///
/// Una sola decisión, en un solo sitio: qué pantalla corresponde según quién
/// está dentro. Ninguna pantalla navega por su cuenta tras iniciar sesión; se
/// limitan a cambiar el estado, y aquí se decide la consecuencia.
///
/// El `switch` sobre la jerarquía sellada `Sesion` no lleva `default`: si
/// mañana aparece un estado nuevo, esto deja de compilar hasta que alguien
/// decida qué hacer con él.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/proveedores_sesion.dart';
import '../../domain/sesion.dart';
import '../admin/panel_admin.dart';
import '../docente/bandeja_docente.dart';
import 'pantalla_ingreso.dart';
import 'pantalla_rechazo.dart';
import 'textos.dart';

class Enrutador extends ConsumerWidget {
  const Enrutador({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Sesion sesion = ref.watch(sesionActualProvider);

    return switch (sesion) {
      SesionCargando() => const _PantallaCargando(),
      SesionAnonima() => const PantallaIngreso(),
      SesionRechazada(:final motivo, :final correo) => PantallaRechazo(
        motivo: motivo,
        correo: correo,
      ),
      SesionActiva(:final usuario) => usuario.rol.usaPanelAdministrativo
          ? PanelAdmin(usuario: usuario)
          : BandejaDocente(usuario: usuario),
    };
  }
}

class _PantallaCargando extends StatelessWidget {
  const _PantallaCargando();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(Textos.verificandoSesion),
          ],
        ),
      ),
    );
  }
}
