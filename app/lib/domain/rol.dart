/// SIAN — Roles, del lado del cliente.
///
/// El rol viaja en los *custom claims* del token, sembrados por Cloud Function
/// (documento 02, sección 9). Aquí se usa **solo para decidir qué pantalla
/// mostrar**.
///
/// La autorización de verdad ocurre en tres sitios que deben coincidir, y
/// ninguno es este: los claims del token, las reglas de Firestore y la
/// validación del servidor. Una comprobación hecha únicamente en la interfaz se
/// considera defecto de seguridad (RN-01). Si alguien manipulara el rol en el
/// navegador, vería un menú distinto y nada más: cada lectura y cada escritura
/// seguiría rebotando contra las reglas.
library;

enum Rol {
  coordinador('COORDINADOR', 'Coordinador Académico'),
  administradora('ADMINISTRADORA', 'Administradora Académica'),
  catedratico('CATEDRATICO', 'Catedrático'),
  auditor('AUDITOR', 'Auditor');

  const Rol(this.claim, this.etiqueta);

  /// Valor exacto que viaja en el custom claim `rol`.
  final String claim;

  /// Nombre legible, tal como lo nombra el documento 01, sección 2.1.
  final String etiqueta;

  /// Traduce el claim recibido en el token.
  ///
  /// Devuelve `null` ante un valor desconocido o ausente, y quien llama decide
  /// qué hacer. Inventar un rol por omisión sería concederle acceso a alguien
  /// cuyo token no dice nada.
  static Rol? desdeClaim(Object? valor) {
    if (valor is! String) {
      return null;
    }
    for (final Rol rol in Rol.values) {
      if (rol.claim == valor) {
        return rol;
      }
    }
    return null;
  }

  /// ¿Este rol trabaja en el panel de administración?
  bool get usaPanelAdministrativo => switch (this) {
    Rol.coordinador || Rol.administradora || Rol.auditor => true,
    Rol.catedratico => false,
  };

  /// ¿Puede emitir mensajes? (documento 01, sección 2.2)
  bool get esEmisor => switch (this) {
    Rol.coordinador || Rol.administradora => true,
    Rol.catedratico || Rol.auditor => false,
  };

  /// ¿Puede consultar la bitácora completa? (RF-BIT-04)
  bool get veBitacoraCompleta => switch (this) {
    Rol.coordinador || Rol.auditor => true,
    Rol.administradora || Rol.catedratico => false,
  };

  /// ¿Recibe mensajes? El auditor es de solo lectura sobre la bitácora y no
  /// entra en el reparto (documento 01, sección 2.2).
  bool get recibeMensajes => this != Rol.auditor;
}
