/// SIAN — Roles, del lado del cliente.
///
/// El rol viaja en los *custom claims* del token, sembrados por Cloud Function
/// (documento 02, sección 12). Aquí se usa **solo para decidir qué pantalla
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
  // El identificador `ADMINISTRADORA` no cambia aunque cambie la etiqueta:
  // está escrito en los custom claims de cada sesión viva, en los perfiles de
  // Firestore y en la bitácora, que es inmutable. Renombrarlo obligaría a
  // migrar todo eso para ganar coherencia cosmética.
  administradora('ADMINISTRADORA', 'Administrador Académico'),
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

  /// ¿Ve los mensajes de TODO el mundo, o solo los suyos?
  ///
  /// ────────────────────────────────────────────────────────────────────────
  /// No es una preferencia de la pantalla: es lo que las reglas permiten.
  /// ────────────────────────────────────────────────────────────────────────
  ///
  /// `VER_REPORTE_ENTREGAS` tiene alcance TODO para el coordinador y el
  /// auditor, y PROPIO para el administrador académico (documento 01, §2.2).
  ///
  /// Y Firestore no evalúa las reglas fila por fila en una consulta de lista:
  /// exige que la consulta misma sea demostrablemente segura. Pedir todos los
  /// mensajes siendo administrador no devuelve «los tuyos», devuelve
  /// `permission-denied` — que es exactamente lo que ocurrió.
  bool get veMensajesDeTodos => switch (this) {
    Rol.coordinador || Rol.auditor => true,
    Rol.administradora || Rol.catedratico => false,
  };

  /// ¿Puede consultar la bitácora completa? (RF-BIT-04)
  bool get veBitacoraCompleta => switch (this) {
    Rol.coordinador || Rol.auditor => true,
    Rol.administradora || Rol.catedratico => false,
  };

  /// ¿Recibe avisos?
  ///
  /// ────────────────────────────────────────────────────────────────────────
  /// Recibir y emitir son dos preguntas distintas.
  /// ────────────────────────────────────────────────────────────────────────
  ///
  /// Solo el catedrático. Los otros tres trabajan **sobre** el sistema de
  /// avisos en vez de ser su destino: la coordinación los escribe, el
  /// administrador académico los gestiona y la auditoría los revisa.
  ///
  /// Es solo el **valor por omisión**: el coordinador puede encenderlo por
  /// persona, y entonces manda su decisión. Un catedrático nombrado
  /// administrador académico para que pueda emitir sigue dando clases, y
  /// atarlo al rol lo obligaría a tener dos cuentas — lo que rompería que una
  /// persona sea una cuenta, que es lo que sostiene la bitácora y la
  /// confirmación de lectura.
  ///
  /// Duplica `recibePorOmision` del dominio de TypeScript, que es la fuente de
  /// verdad.
  bool get recibeMensajes => this == Rol.catedratico;

  /// ¿Puede emitir alertas urgentes?
  ///
  /// ────────────────────────────────────────────────────────────────────────
  /// La bandera fina NO aplica a todos los roles.
  /// ────────────────────────────────────────────────────────────────────────
  ///
  /// La fila `CREAR_ALERTA_URGENTE` de la matriz del documento 01, sección
  /// 2.2, da al coordinador alcance **TODO** y a la administradora
  /// **CONDICIONADO**. Es decir: el coordinador puede siempre, y la bandera
  /// existe para que él decida qué administradoras pueden.
  ///
  /// Mirar solo la bandera dejaba al coordinador sin poder emitir urgentes en
  /// la interfaz, mientras el servidor se las habría aceptado. Una interfaz
  /// que contradice la matriz es tan defecto como una que se la salta.
  bool puedeEmitirUrgentes({required bool autorizacionFina}) => switch (this) {
    Rol.coordinador => true,
    Rol.administradora => autorizacionFina,
    Rol.catedratico || Rol.auditor => false,
  };

  /// ¿Puede crear mensajes recurrentes? Misma forma que las urgentes:
  /// `CREAR_RECURRENTE` es TODO para el coordinador y CONDICIONADO para la
  /// administradora. Se declara ya para que la iteración 1.4 no repita el
  /// mismo error.
  bool puedeCrearRecurrentes({required bool autorizacionFina}) =>
      switch (this) {
        Rol.coordinador => true,
        Rol.administradora => autorizacionFina,
        Rol.catedratico || Rol.auditor => false,
      };
}
