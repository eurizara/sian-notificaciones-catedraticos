/// SIAN — Textos de la interfaz.
///
/// RNF-21: la interfaz está en español, y los textos residen en archivos de
/// recursos, **nunca incrustados en el código**. Que hoy solo exista un idioma
/// no cambia la regla: agregar otro debe ser añadir un archivo, no refactorizar
/// la aplicación (deuda DT-09, en estado mitigado precisamente por esto).
library;

abstract final class Textos {
  // --- Identidad -----------------------------------------------------------
  /// Nombre corto del sistema, con la sede que le da alcance.
  static const String nombreApp = 'SIAN UMG-BDM';

  static const String nombreCompleto =
      'Sistema Institucional de Avisos y Notificaciones';

  static const String institucion = 'Universidad Mariano Gálvez de Guatemala';
  static const String sede = 'Sede Boca del Monte';

  /// Lema institucional que aparece en el escudo.
  static const String lema =
      'Y conoceréis la verdad, y la verdad os hará libres';

  // --- Inicio de sesión ----------------------------------------------------
  static const String etiquetaCorreo = 'Correo institucional';
  static const String etiquetaContrasena = 'Contraseña';
  static const String mostrarContrasena = 'Mostrar contraseña';
  static const String ocultarContrasena = 'Ocultar contraseña';
  static const String botonEntrar = 'Entrar';
  static const String botonOlvideContrasena = '¿Olvidaste tu contraseña?';
  static const String botonSalir = 'Cerrar sesión';
  static const String verificandoSesion = 'Verificando sesión…';
  static const String recuperacionEnviada =
      'Si ese correo tiene cuenta, recibirás un enlace para restablecerla.';

  static const String validacionCorreoObligatorio = 'Escribe tu correo.';
  static const String validacionCorreoInvalido = 'Ese correo no tiene forma válida.';
  static const String validacionContrasenaObligatoria = 'Escribe tu contraseña.';

  // Deliberadamente sin distinguir «no existe» de «contraseña incorrecta»:
  // hacerlo permitiría averiguar qué correos tienen cuenta probando uno a uno.
  static const String errorCredenciales = 'Correo o contraseña incorrectos.';
  static const String errorCorreoInvalido = 'Ese correo no tiene forma válida.';
  static const String errorCuentaDesactivada =
      'Esta cuenta está desactivada. Contacta a la coordinación académica.';
  static const String errorDemasiadosIntentos =
      'Demasiados intentos fallidos. Espera unos minutos antes de reintentar.';
  static const String errorSinRed =
      'Sin conexión. Revisa tu red e inténtalo de nuevo.';
  static const String errorInesperado =
      'Ocurrió un error inesperado. Inténtalo de nuevo.';
  static const String errorCorreoParaRecuperar =
      'Escribe tu correo para enviarte el enlace de recuperación.';

  // --- Rechazo de acceso (RF-AUT-03) ---------------------------------------
  static const String rechazoCorreoUsado = 'Correo con el que intentaste entrar';
  static const String botonVolverAIngreso = 'Volver al inicio de sesión';

  static const String rechazoNoAutorizadoTitulo = 'Acceso no autorizado';
  static const String rechazoNoAutorizadoExplicacion =
      'Tu autenticación fue correcta, pero este correo no está en la lista de '
      'usuarios autorizados del sistema.';
  static const String rechazoNoAutorizadoSalida =
      'Si crees que debería estarlo, pide a la coordinación académica que te '
      'registre. El intento quedó anotado en la bitácora.';

  static const String rechazoDesactivadaTitulo = 'Cuenta desactivada';
  static const String rechazoDesactivadaExplicacion =
      'Tu cuenta existe pero fue desactivada, así que ya no recibes mensajes.';
  static const String rechazoDesactivadaSalida =
      'Tu historial se conserva íntegro. Contacta a la coordinación académica '
      'para reactivarla.';

  static const String rechazoSinRolTitulo = 'Sesión sin rol asignado';
  static const String rechazoSinRolExplicacion =
      'Entraste correctamente, pero tu sesión todavía no lleva un rol.';
  static const String rechazoSinRolSalida =
      'Suele resolverse cerrando sesión y volviendo a entrar: el rol se asigna '
      'en el servidor y tu sesión puede haberse emitido antes.';

  // --- Panel de administración ---------------------------------------------
  static const String panelTitulo = 'Panel de administración';
  static const String sinSeccionesDisponibles =
      'Tu rol no tiene secciones asignadas en el panel.';

  static const String seccionMensajes = 'Mensajes';
  static const String seccionMensajesTitulo = 'Composición y envío';
  static const String seccionMensajesDescripcion =
      'Redactar avisos informativos y alertas urgentes, con texto, nota de voz '
      'e imagen. Incluye la doble confirmación obligatoria antes de que salga '
      'una alerta urgente.';

  static const String seccionProgramacion = 'Programación';
  static const String seccionProgramacionTitulo = 'Programación y recurrencia';
  static const String seccionProgramacionDescripcion =
      'Programar un mensaje a fecha y hora, o definir un patrón de repetición '
      'con vista previa de las próximas diez ocurrencias antes de guardar.';

  static const String seccionGrupos = 'Grupos';
  static const String seccionGruposTitulo = 'Grupos de destinatarios';
  static const String seccionGruposDescripcion =
      'Crear grupos, agregar y quitar catedráticos, y ver cuántos destinatarios '
      'resuelve cada uno antes de enviar.';

  static const String seccionUsuarios = 'Usuarios';
  static const String seccionUsuariosTitulo = 'Usuarios, roles e invitaciones';
  static const String seccionUsuariosDescripcion =
      'Registrar los correos institucionales autorizados, asignar roles y '
      'desactivar cuentas sin borrar su historial.';

  static const String seccionEntregas = 'Entregas';
  static const String seccionEntregasTitulo = 'Reporte de entregas';
  static const String seccionEntregasDescripcion =
      'Ver quién confirmó y quién no, con el porcentaje sobre el total de '
      'destinatarios y la trazabilidad completa de cada mensaje.';

  static const String seccionBitacora = 'Bitácora';
  static const String seccionBitacoraTitulo = 'Bitácora del sistema';
  static const String seccionBitacoraDescripcion =
      'Consultar el registro inmutable de todo evento del sistema, filtrable '
      'por fecha, tipo de evento, actor y mensaje.';

  static const String iteracion12 = 'Llega en la iteración 1.2';
  static const String iteracion13 = 'Llega en la iteración 1.3';
  static const String iteracion14 = 'Llega en la iteración 1.4';

  // --- Bandeja del catedrático ---------------------------------------------
  static const String bandejaTitulo = 'Mis mensajes';
  static const String bandejaVacia = 'No tienes mensajes todavía.';
  static const String bandejaError = 'No se pudo cargar tu historial';
  static const String bandejaPendienteUno =
      'Tienes 1 alerta urgente sin confirmar';
  static const String bandejaPendienteDetalle =
      'Las alertas urgentes siguen visibles hasta que las confirmes.';
  static const String botonConfirmarLectura = 'Confirmar lectura';
  static const String confirmacionEnIteracion14 =
      'La confirmación la escribe el servidor, y llega en la iteración 1.4.';
  static const String etiquetaUrgente = 'URGENTE';

  static String bandejaPendienteVarios(int cantidad) =>
      'Tienes $cantidad alertas urgentes sin confirmar';

  static const String estadoPendiente = 'Pendiente';
  static const String estadoEntregado = 'Entregado';
  static const String estadoAbierto = 'Abierto';
  static const String estadoConfirmado = 'Confirmado';
  static const String estadoFallido = 'Falló la entrega';
  static const String estadoDescartado = 'Descartado';

  // --- Modo demostración (solo emuladores) ---------------------------------
  static const String demoTitulo = 'Modo demostración';
  static const String demoSubtitulo =
      'Solo con emuladores. Entra con una cuenta sembrada para recorrer los '
      'casos de uso. No es una cuenta de invitado: pasa por el mismo inicio de '
      'sesión y las mismas reglas de seguridad.';
  static const String demoErrorSinSemilla =
      'No se pudo entrar. ¿Ejecutaste «npm run seed:dev» con los emuladores '
      'corriendo?';

  static const String demoCoordinador =
      'Todo el panel: usuarios, grupos, mensajes, entregas y bitácora';
  static const String demoAdministradora1 =
      'Emisora autorizada para urgentes, sin acceso a usuarios ni bitácora';
  static const String demoAdministradora2 =
      'Emisora sin autorización para urgentes: compara con la anterior';
  static const String demoCatedratico =
      'Bandeja de mensajes recibidos, con datos reales de Firestore';
  static const String demoAuditor =
      'Solo lectura: bitácora y entregas, sin poder emitir nada';

  // --- Estado del sistema --------------------------------------------------
  static const String tituloEstado = 'Estado del sistema';
  static const String subtituloEstado =
      'Iteración 1.1 completada. La autenticación llega en la 1.2.';

  static const String cimientosListos = 'Cimientos';
  static const String cimientosDetalle =
      'Dominio, reglas de seguridad e integración continua';

  static const String flutterListo = 'Aplicación Flutter';
  static const String flutterDetalle = 'Compila y sirve como PWA instalable';

  static const String firebasePendiente = 'Firebase';
  static const String firebaseDetalleEmulador =
      'Apuntando a los emuladores locales';
  static const String firebaseDetalleNube = 'Apuntando al proyecto en la nube';
  static const String firebaseDetallePendiente =
      'Sin configurar: falta ejecutar flutterfire configure';
  static const String firebaseDetalleFallido = 'No arrancó';

  static const String autenticacionPendiente = 'Autenticación';
  static const String autenticacionDetalle =
      'Google y correo/contraseña — iteración 1.2';

  static const String notificacionesPendiente = 'Notificaciones';
  static const String notificacionesDetalle =
      'Envío inmediato y recepción — iteración 1.3';

  static const String programacionPendiente = 'Programación y recurrencia';
  static const String programacionDetalle =
      'Despachador y confirmación de lectura — iteración 1.4';

  // --- Etiquetas de estado -------------------------------------------------
  static const String listo = 'Listo';
  static const String pendiente = 'Pendiente';
  static const String enCurso = 'En curso';

  // --- Avisos --------------------------------------------------------------
  static const String avisoEmuladorSinPush =
      'Los emuladores no entregan notificaciones push reales. FCM no tiene '
      'emulador: la llegada al dispositivo solo se verifica desplegando.';
}
