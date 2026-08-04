/// SIAN — Estado de la sesión.
///
/// Modelado como jerarquía sellada: cada estado posible es un tipo, y el
/// `switch` que los consume falla en compilación si aparece uno nuevo sin
/// atender. Un booleano `estaAutenticado` no distinguiría «cargando» de
/// «rechazado», que es justo lo que la interfaz necesita separar.
library;

import 'rol.dart';

/// Usuario con sesión válida y rol reconocido.
class UsuarioSesion {
  const UsuarioSesion({
    required this.uid,
    required this.correo,
    required this.nombre,
    required this.rol,
    required this.activo,
    this.puedeEmitirUrgentes = false,
    this.puedeCrearRecurrentes = false,
  });

  final String uid;
  final String correo;
  final String nombre;
  final Rol rol;
  final bool activo;

  /// Autorización fina que el coordinador concede a una administradora
  /// (documento 05, sección 2.1). El servidor la vuelve a comprobar.
  final bool puedeEmitirUrgentes;
  final bool puedeCrearRecurrentes;
}

/// Por qué se rechazó un intento de entrada.
enum MotivoRechazo {
  /// El correo no está en la lista blanca institucional (RF-AUT-03).
  fueraDeListaBlanca,

  /// La cuenta existe pero fue desactivada (RF-AUT-08, RN-10).
  cuentaDesactivada,

  /// El token no trae rol. Suele significar que los claims se sembraron
  /// después de emitir el token: hace falta refrescarlo (anexo del documento
  /// 06).
  sinRolEnElToken,
}

sealed class Sesion {
  const Sesion();
}

/// Todavía no se sabe: se está resolviendo el token o el perfil.
class SesionCargando extends Sesion {
  const SesionCargando();
}

/// Nadie ha entrado.
class SesionAnonima extends Sesion {
  const SesionAnonima();
}

/// Sesión válida y operativa.
class SesionActiva extends Sesion {
  const SesionActiva(this.usuario);

  final UsuarioSesion usuario;
}

/// Autenticó contra el proveedor, pero el sistema no lo admite.
class SesionRechazada extends Sesion {
  const SesionRechazada({required this.motivo, required this.correo});

  final MotivoRechazo motivo;
  final String correo;
}
