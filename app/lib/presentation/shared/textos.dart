/// SIAN — Textos de la interfaz.
///
/// RNF-21: la interfaz está en español, y los textos residen en archivos de
/// recursos, **nunca incrustados en el código**. Que hoy solo exista un idioma
/// no cambia la regla: agregar otro debe ser añadir un archivo, no refactorizar
/// la aplicación (deuda DT-09, en estado mitigado precisamente por esto).
library;

import 'package:flutter/material.dart' show IconData, Icons;

import '../../domain/politica_contrasena.dart';

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

  // --- Registro (RF-AUT-02, RF-AUT-06) -------------------------------------
  static const String registroTitulo = 'Crear cuenta';
  static const String botonCrearCuenta = 'Crear cuenta';
  static const String botonYaTengoCuenta = 'Ya tengo cuenta';
  static const String botonNoTengoCuenta = '¿No tienes cuenta? Regístrate';
  static const String etiquetaRepetirContrasena = 'Repite la contraseña';

  static const String registroAvisoListaBlanca =
      'Solo pueden registrarse los correos institucionales previamente '
      'autorizados por la coordinación académica. Si el tuyo no lo está, la '
      'cuenta no se creará.';
  static const String registroAyudaCorreo =
      'El mismo que autorizó la coordinación académica';
  static const String registroAyudaContrasena =
      'Mínimo 10 caracteres, con mayúscula, minúscula y un número';

  static const String registroAyudaContrasenaLarga =
      'Mínimo 10 caracteres con mayúscula, minúscula, número y símbolo. No '
      'puede contener tu nombre ni tu correo.';

  static const String fuerzaInsuficiente = 'No cumple la política';
  static const String fuerzaAceptable = 'Aceptable — alargarla la mejora mucho';
  static const String fuerzaBuena = 'Buena';
  static const String fuerzaExcelente = 'Excelente';

  /// Explica un incumplimiento en lenguaje llano.
  static String explicarIncumplimiento(IncumplimientoContrasena i) =>
      switch (i) {
        IncumplimientoContrasena.longitudMinima =>
          'Necesita al menos 10 caracteres.',
        IncumplimientoContrasena.faltaMayuscula => 'Le falta una mayúscula.',
        IncumplimientoContrasena.faltaMinuscula => 'Le falta una minúscula.',
        IncumplimientoContrasena.faltaDigito => 'Le falta un número.',
        IncumplimientoContrasena.faltaSimbolo =>
          'Le falta un símbolo, por ejemplo # o \$.',
        IncumplimientoContrasena.contieneDatosPersonales =>
          'No puede contener tu nombre ni tu correo: sería lo primero que '
              'probaría quien te conoce.',
        IncumplimientoContrasena.demasiadoComun =>
          'Es una contraseña demasiado conocida o contiene el nombre de la '
              'institución.',
        IncumplimientoContrasena.secuenciaObvia =>
          'Contiene una secuencia obvia, como «1234» o «abcd».',
        IncumplimientoContrasena.caracterRepetido =>
          'Repite el mismo carácter demasiadas veces seguidas.',
      };

  static const String validacionContrasenasNoCoinciden =
      'Las contraseñas no coinciden.';
  static const String errorCorreoYaRegistrado =
      'Ese correo ya tiene una cuenta. Inicia sesión en vez de registrarte.';
  static const String errorContrasenaDebil =
      'Esa contraseña es demasiado débil.';
  static const String errorRegistroDeshabilitado =
      'El registro con correo y contraseña no está habilitado.';

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

  // --- Administración de usuarios ------------------------------------------
  static const String pestanaInvitaciones = 'Invitaciones';
  static const String pestanaUsuarios = 'Usuarios';
  static const String botonInvitar = 'Invitar';
  static const String botonRevocar = 'Revocar';
  static const String botonCancelar = 'Cancelar';
  static const String botonCerrar = 'Cerrar';
  static const String botonVerDetalle = 'Ver detalle';
  static const String tituloInvitar = 'Invitar a una persona';
  static const String tituloCargaMasiva = 'Carga masiva por CSV';
  static const String tituloLineasRechazadas = 'Líneas rechazadas';
  static const String modoUnaAUna = 'Una a una';
  static const String modoCsv = 'CSV';
  static const String etiquetaNombre = 'Nombre';
  static const String etiquetaRol = 'Rol';
  static const String ayudaCsv =
      'Una línea por persona, con el formato «correo,rol,nombre». El '
      'encabezado es opcional. Una línea inválida no aborta la carga: se '
      'rechaza esa sola y se informa con su número.';
  static const String sinInvitaciones = 'Todavía no hay ninguna invitación.';
  static const String sinUsuarios = 'Todavía no hay ningún usuario dado de alta.';
  static const String invitacionConsumida = 'ya usada';
  static const String invitacionPendiente = 'sin usar';
  static const String invitacionRevocada = 'Invitación revocada.';
  static const String usuarioDesactivado = 'desactivada';
  static const String rolCambiado = 'Rol actualizado.';
  static const String autorizacionActualizada = 'Autorización actualizada.';
  static const String cuentaReactivada = 'Cuenta reactivada.';
  static const String cuentaDesactivada = 'Cuenta desactivada.';
  static const String cuentaActiva = 'Cuenta activa';
  static const String cuentaActivaAyuda =
      'Desactivar no borra nada: la persona deja de recibir mensajes y su '
      'historial se conserva íntegro.';
  static const String autorizacionUrgentes = 'Puede emitir alertas urgentes';
  static const String autorizacionUrgentesAyuda =
      'Autorización que concede el coordinador, según el documento 01';
  static const String autorizacionRecurrentes = 'Puede crear mensajes recurrentes';
  static const String errorOperacion = 'No se pudo completar:';
  static const String errorCargarDatos = 'No se pudieron cargar los datos';

  static String confirmarRevocar(String correo) =>
      '¿Revocar la invitación de $correo? Podrá volver a invitarse después.';
  static String cargaCorrecta(int creadas) =>
      creadas == 1 ? '1 invitación creada.' : '$creadas invitaciones creadas.';
  static String cargaParcial(int creadas, int rechazadas) =>
      '$creadas creadas, $rechazadas rechazadas.';

  // --- Bitácora ------------------------------------------------------------
  static const String filtroTipoEvento = 'Tipo de evento';
  static const String bitacoraVacia = 'No hay asientos para ese filtro.';

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

  // --- Google (RF-AUT-01) --------------------------------------------------
  static const String botonEntrarConGoogle = 'Entrar con Google';
  static const String separadorO = 'o';
  static const String errorGoogleCancelado =
      'Se cerró la ventana de Google antes de terminar.';
  static const String errorGoogleBloqueado =
      'El navegador bloqueó la ventana de Google. Permite las ventanas '
      'emergentes de este sitio e inténtalo otra vez.';

  // --- Notificaciones (RF-USR-09, RES-05, RES-07) ---------------------------
  static const String botonActivarNotificaciones = 'Activar notificaciones';
  static const String notificacionPruebaEnviada =
      'Te enviamos una notificación de prueba. Si no llega, algo falla en el '
      'canal y conviene decirlo antes de que haya un aviso real que perder.';

  static const String notifActivasTitulo = 'Notificaciones activas';
  static const String notifPendientesTitulo = 'Activa las notificaciones';
  static const String notifPendientesDetalle =
      'Sin ellas no recibirás avisos ni alertas urgentes. Es un solo toque.';
  static const String notifDenegadasTitulo = 'Notificaciones bloqueadas';
  static const String notifInstalarTitulo = 'Falta instalar la aplicación';
  static const String notifInstalarDetalle =
      'En iPhone las notificaciones solo funcionan con la aplicación añadida '
      'a la pantalla de inicio. Sin ese paso no llegará ninguna.';
  static const String notifSinSoporteTitulo = 'Este navegador no puede notificarte';
  static const String notifSinSoporteIos =
      'Tu versión de iOS es anterior a la 16.4, que es desde donde Apple '
      'permite notificaciones web. Podrás leer tus mensajes al abrir la '
      'aplicación, pero no te avisará.';
  static const String notifSinSoporteNavegador =
      'Podrás leer tus mensajes al abrir la aplicación, pero no te avisará. '
      'Prueba con Chrome, Edge, Firefox o Safari.';

  static String notifActivasDetalle(String navegador) =>
      'Recibirás avisos y alertas urgentes en este dispositivo ($navegador).';

  /// RES-07 — dónde se revierte un permiso denegado, que cambia en cada
  /// navegador. Sin esta indicación, «bloqueado» es un callejón sin salida.
  static String comoRevertirPermiso(String navegador) => switch (navegador) {
    'Chrome' || 'Brave' || 'Vivaldi' || 'Opera' =>
      'Pulsa el icono de candado a la izquierda de la dirección → '
          'Configuración del sitio → Notificaciones → Permitir. Luego recarga.',
    'Edge' =>
      'Pulsa el candado junto a la dirección → Permisos para este sitio → '
          'Notificaciones → Permitir. Luego recarga.',
    'Firefox' =>
      'Pulsa el candado junto a la dirección → Conexión segura → Más '
          'información → Permisos → Notificaciones. Luego recarga.',
    'Safari' =>
      'Ve a Ajustes de Safari → Sitios web → Notificaciones → busca este '
          'sitio y elige Permitir. Luego recarga.',
    _ =>
      'Busca los permisos de este sitio en los ajustes de tu navegador y '
          'permite las notificaciones. Luego recarga la página.',
  };

  // --- Instructivo de instalación en iOS (RES-05, R-02) ---------------------
  static const String instalarTitulo = 'Instala SIAN en tu iPhone';
  static const String instalarPorQue =
      'En iPhone, las notificaciones solo llegan si añades la aplicación a la '
      'pantalla de inicio. Sin este paso no recibirás ninguna alerta, ni '
      'siquiera las urgentes.';
  static const String instalarIosAntiguo =
      'Tu versión de iOS parece anterior a la 16.4. Las notificaciones web '
      'necesitan esa versión o superior; considera actualizar el sistema.';
  static const String botonYaLoHice = 'Ya lo hice';
  static const String botonSeguirSinInstalar = 'Seguir sin instalar';
  static const String avisoSeguirSinInstalar =
      'Podrás leer tus mensajes al abrir la aplicación, pero no te avisará de '
      'nada.';

  static String instalarSoloSafari(String navegador) =>
      'Estás usando $navegador. En iPhone, solo Safari puede añadir una '
      'aplicación a la pantalla de inicio: abre este mismo enlace en Safari.';

  static const List<({int numero, String texto, IconData icono})>
  pasosInstalacionIos = <({int numero, String texto, IconData icono})>[
    (
      numero: 1,
      texto: 'Abre este sitio en Safari, si no lo estás ya.',
      icono: Icons.public,
    ),
    (
      numero: 2,
      texto: 'Pulsa el botón Compartir, el cuadrado con la flecha hacia arriba.',
      icono: Icons.ios_share,
    ),
    (
      numero: 3,
      texto: 'Desliza y elige «Añadir a pantalla de inicio».',
      icono: Icons.add_to_home_screen,
    ),
    (numero: 4, texto: 'Confirma con «Añadir».', icono: Icons.check_circle_outline),
    (
      numero: 5,
      texto: 'Abre SIAN desde el icono nuevo y activa las notificaciones.',
      icono: Icons.notifications_active_outlined,
    ),
  ];

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
