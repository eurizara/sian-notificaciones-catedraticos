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
import 'pantalla_registro.dart';
import 'textos.dart';

class Enrutador extends ConsumerStatefulWidget {
  const Enrutador({super.key});

  @override
  ConsumerState<Enrutador> createState() => _EnrutadorState();
}

class _EnrutadorState extends ConsumerState<Enrutador> {
  /// Alterna entre ingresar y registrarse. Es la única navegación que no
  /// depende del estado de sesión, porque ocurre antes de que haya sesión.
  bool _mostrandoRegistro = false;

  /// Último rechazo recibido, si todavía no se ha reconocido.
  ///
  /// ────────────────────────────────────────────────────────────────────────
  /// Un rechazo es un EVENTO, no un estado de sesión.
  /// ────────────────────────────────────────────────────────────────────────
  ///
  /// Cuando el servidor rechaza un acceso no autorizado, **borra la credencial
  /// recién creada** para no dejar cuentas huérfanas. Eso hace que el cliente
  /// pierda la sesión por su cuenta, y la sesión anónima que llega detrás
  /// tapaba el rechazo antes de que nadie lo leyera: se veía un parpadeo y
  /// vuelta al formulario.
  ///
  /// Guardarlo aquí hace que el aviso **sobreviva a la desaparición de la
  /// sesión**, que es justo lo que RF-AUT-03 exige al pedir un rechazo
  /// explicativo. Se limpia cuando la persona lo reconoce, o en cuanto alguien
  /// entra de verdad.
  SesionRechazada? _rechazoPendiente;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Sesion>>(sesionProvider, (
      AsyncValue<Sesion>? _,
      AsyncValue<Sesion> siguiente,
    ) {
      final Sesion? s = siguiente.value;
      if (s is SesionRechazada) {
        setState(() => _rechazoPendiente = s);
      } else if (s is SesionActiva) {
        setState(() => _rechazoPendiente = null);
      }
    });

    final Sesion sesion = ref.watch(sesionActualProvider);
    final SesionRechazada? rechazo = _rechazoPendiente;

    // El rechazo tiene prioridad sobre cualquier pantalla anónima: si hay algo
    // que explicar, se explica antes de volver a pedir credenciales.
    if (rechazo != null && sesion is! SesionActiva) {
      return PantallaRechazo(
        motivo: rechazo.motivo,
        correo: rechazo.correo,
        alReconocer: () => setState(() {
          _rechazoPendiente = null;
          _mostrandoRegistro = false;
        }),
      );
    }

    return switch (sesion) {
      SesionCargando() => const _PantallaCargando(),
      SesionAnonima() => _pantallaSinSesion(),
      // Un rechazo que ya no está pendiente es un rechazo **reconocido**: la
      // persona leyó el motivo y pulsó volver. Repetírselo sería justo lo que
      // parecía un botón muerto. El estado de sesión aún dice «rechazada»
      // porque el rechazo es lo último que ocurrió, no lo que toca mostrar.
      SesionRechazada() => _pantallaSinSesion(),
      SesionActiva(:final usuario) => usuario.rol.usaPanelAdministrativo
          ? PanelAdmin(usuario: usuario)
          : BandejaDocente(usuario: usuario),
    };
  }

  Widget _pantallaSinSesion() => _mostrandoRegistro
      ? PantallaRegistro(
          alVolver: () => setState(() => _mostrandoRegistro = false),
        )
      : PantallaIngreso(
          alRegistrarse: () => setState(() => _mostrandoRegistro = true),
        );
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
