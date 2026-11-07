/// La sede de trabajo de la sesión (2.0 · RF-SED-04).
///
/// Es la elegida en el selector —que solo aparece con más de una sede— si
/// sigue siendo una de las suyas, y si no la principal. Se recuerda en este
/// navegador para la próxima vez; si se pierde, no pasa nada: vuelve a la
/// principal.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/plataforma/almacen_local.dart';
import '../core/sede_de_trabajo.dart';
import '../domain/sesion.dart';
import 'proveedores_sesion.dart';

const String _claveSede = 'sian.sede';

class SedeDeTrabajoNotifier extends Notifier<String> {
  @override
  String build() {
    final Sesion sesion = ref.watch(sesionActualProvider);
    if (sesion is! SesionActiva) {
      SedeDeTrabajo.fijar(null);
      return sedeInicial;
    }
    final UsuarioSesion usuario = sesion.usuario;
    final String? guardada = leerLocal(_claveSede);
    final String sede = guardada != null && usuario.sedes.containsKey(guardada)
        ? guardada
        : usuario.sedePrincipal;
    SedeDeTrabajo.fijar(sede);
    return sede;
  }

  /// Cambia de sede. Una que no es suya se ignora: el selector solo ofrece las
  /// suyas, y el servidor lo vuelve a comprobar.
  void elegir(String sede) {
    final Sesion sesion = ref.read(sesionActualProvider);
    if (sesion is! SesionActiva || !sesion.usuario.sedes.containsKey(sede)) {
      return;
    }
    guardarLocal(_claveSede, sede);
    SedeDeTrabajo.fijar(sede);
    state = sede;
  }
}

final NotifierProvider<SedeDeTrabajoNotifier, String> sedeDeTrabajoProvider =
    NotifierProvider<SedeDeTrabajoNotifier, String>(SedeDeTrabajoNotifier.new);
