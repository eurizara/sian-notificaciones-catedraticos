/// SIAN — Textos de la interfaz.
///
/// RNF-21: la interfaz está en español, y los textos residen en archivos de
/// recursos, **nunca incrustados en el código**. Que hoy solo exista un idioma
/// no cambia la regla: agregar otro debe ser añadir un archivo, no refactorizar
/// la aplicación (deuda DT-09, en estado mitigado precisamente por esto).
library;

import 'package:flutter/material.dart' show IconData, Icons;

import '../../core/audio/grabacion.dart';
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

  /// Recarga de verdad, la del navegador: descarta lo acumulado y trae la
  /// versión desplegada más reciente, que en una aplicación instalada puede
  /// llevar días sin renovarse.
  static const String botonRecargar = 'Recargar la aplicación';
  static const String verificandoSesion = 'Verificando sesión…';
  static const String recuperacionEnviada =
      'Si ese correo tiene cuenta, recibirás un enlace para restablecerla.';

  static const String validacionCorreoObligatorio = 'Escribe tu correo.';
  static const String validacionCorreoInvalido =
      'Ese correo no tiene forma válida.';
  static const String validacionContrasenaObligatoria =
      'Escribe tu contraseña.';

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
  static const String rechazoCorreoUsado =
      'Correo con el que intentaste entrar';
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

  static const String seccionMisMensajes = 'Mis mensajes';
  static const String seccionMisMensajesTitulo = 'Mis mensajes';
  static const String seccionMisMensajesDescripcion =
      'Los avisos que recibes tú. Aparece porque la coordinación te tiene '
      'marcado como destinatario, además de emisor.';

  static const String etiquetaRecibeAvisos = 'Recibe avisos';
  static const String detalleRecibeAvisos =
      'Además de gestionar el sistema, le llegan los avisos como a un '
      'catedrático. Útil para quien da clases y también emite.';

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
  static const String sinUsuarios =
      'Todavía no hay ningún usuario dado de alta.';
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
  static const String autorizacionRecurrentes =
      'Puede crear mensajes recurrentes';
  static const String errorOperacion = 'No se pudo completar:';
  static const String errorCargarDatos = 'No se pudieron cargar los datos';

  static String confirmarRevocar(String correo) =>
      '¿Revocar la invitación de $correo? Podrá volver a invitarse después.';
  /// Resumen de una carga, contando cada cosa por su nombre.
  ///
  /// Antes decía «N invitaciones creadas» con el total de líneas válidas, así
  /// que volver a cargar una lista de doscientos correos anunciaba doscientas
  /// altas aunque ciento noventa ya estuvieran. Quien carga necesita saber
  /// **qué cambió**, no cuántas líneas se leyeron.
  static String resumenCarga({
    required int creadas,
    required int actualizadas,
    required int yaEntraron,
    required int rechazadas,
  }) {
    final List<String> partes = <String>[];
    if (creadas > 0) {
      partes.add(creadas == 1 ? '1 invitación nueva' : '$creadas invitaciones nuevas');
    }
    if (actualizadas > 0) {
      partes.add(
        actualizadas == 1 ? '1 actualizada' : '$actualizadas actualizadas',
      );
    }
    if (yaEntraron > 0) {
      partes.add(
        yaEntraron == 1 ? '1 sin tocar porque ya entró' : '$yaEntraron sin tocar porque ya entraron',
      );
    }
    if (rechazadas > 0) {
      partes.add(rechazadas == 1 ? '1 rechazada' : '$rechazadas rechazadas');
    }
    if (partes.isEmpty) {
      return 'No había nada que cargar.';
    }
    return '${partes.join(' · ')}.';
  }

  static const String tituloYaEntraron = 'Correos que ya habían entrado';
  static const String explicacionYaEntraron =
      'Estas personas ya usaron su invitación, así que no se tocó. Para '
      'cambiarles el rol, hazlo desde la lista de usuarios: ahí sí les cambia '
      'el rol de verdad.';

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
  static const String notifInstalarTitulo = 'Ábrela desde la pantalla de inicio';

  /// Habla de ESTA pestaña, no del teléfono.
  ///
  /// Decía «sin ese paso no llegará ninguna», que es una afirmación sobre el
  /// dispositivo — y era falsa para quien ya la tenía instalada y sí recibía
  /// avisos. Un mensaje que asegura que el sistema no funciona, cuando
  /// funciona, gasta la confianza que hará falta el día que de verdad falle.
  static const String notifInstalarDetalle =
      'Estás viendo SIAN en una pestaña de Safari, y ahí iPhone no permite '
      'notificaciones. Si ya añadiste SIAN a la pantalla de inicio, ábrela '
      'desde ese icono y recibirás los avisos con normalidad. Si aún no lo '
      'hiciste, es el único paso que falta.';
  static const String notifSinSoporteTitulo =
      'Este navegador no puede notificarte';
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

  static const String botonCerrarAviso = 'Cerrar';

  // --- Composición y envío (ronda 4, iteración 1.3) --------------------------
  static const int limiteTitulo = 80;
  static const int limiteCuerpo = 500;

  static const String redactarTitulo = 'Redactar aviso';
  static const String etiquetaTituloMensaje = 'Título';
  static const String etiquetaCuerpoMensaje = 'Mensaje';
  static const String etiquetaTipo = 'Clasificación';
  static const String tipoInformativo = 'Informativo';
  static const String tipoUrgente = 'Urgente';
  static const String tipoInformativoDetalle =
      'Aviso ordinario. Llega como una notificación normal.';
  static const String tipoUrgenteDetalle =
      'Alerta institucional. Se muestra con «URGENTE» delante y no se descarta sola.';
  static const String etiquetaDestinatarios = 'Destinatarios';
  static const String destinatariosTodos = 'Todos los catedráticos';
  static const String destinatariosGrupos = 'Grupos concretos';
  static const String exigirConfirmacion = 'Exigir confirmación de lectura';
  static const String exigirConfirmacionDetalle =
      'El catedrático tendrá que confirmar que lo leyó. Deja constancia con valor probatorio.';
  static const String botonEnviarAhora = 'Enviar ahora';
  static const String botonRevisarDestinatarios = 'Revisar destinatarios';

  static const String sinGruposTodavia =
      'No hay grupos creados. Puedes enviar a todos los catedráticos.';
  static const String noPuedeUrgentes =
      'Tu cuenta no tiene autorización para emitir alertas urgentes. Pídesela a la coordinación.';

  static const String validacionTituloObligatorio = 'El título es obligatorio.';
  static const String validacionCuerpoObligatorio =
      'El mensaje no puede ir vacío.';
  static const String validacionElijeGrupo = 'Elige al menos un grupo.';

  static String validacionTituloLargo(int actual) =>
      'El título tiene $actual caracteres y el máximo son $limiteTitulo.';
  static String validacionCuerpoLargo(int actual) =>
      'El mensaje tiene $actual caracteres y el máximo son $limiteCuerpo.';
  static String contador(int actual, int maximo) => '$actual / $maximo';

  // Conteo previo (RF-USR-07)
  static const String confirmarEnvioTitulo = 'Antes de enviar';
  static const String confirmarUrgenteTitulo = '¿Enviar una ALERTA URGENTE?';
  static const String botonConfirmarEnvio = 'Sí, enviar';
  static const String botonConfirmarUrgente = 'Sí, enviar la alerta urgente';
  static const String urgenteAdvertencia =
      'Sonará en el teléfono de cada catedrático, aunque tengan la aplicación cerrada. '
      'Un aviso enviado no se puede editar ni borrar.';
  static const String contandoDestinatarios = 'Contando destinatarios…';

  static String conteoDestinatarios(int total) => total == 1
      ? 'Este aviso llegará a 1 persona.'
      : 'Este aviso llegará a $total personas.';
  static String conteoExcluidos(int cuantos) => cuantos == 1
      ? '1 persona queda fuera:'
      : '$cuantos personas quedan fuera:';

  /// Se dice aquí, antes de enviar, y no después en un reporte.
  ///
  /// Quien queda fuera NO genera entrega: no aparecerá como «pendiente de
  /// confirmar» en un reporte que nadie podría cerrar. Pero el emisor tiene
  /// que saberlo mientras aún puede cambiar los destinatarios.
  static const String exclusionNoQuedaPendiente =
      'No se les crea entrega, así que no aparecerán como pendientes en el '
      'reporte.';
  static String motivoExclusion(String motivo, int cuantos) => switch (motivo) {
    'CUENTA_DESACTIVADA' => '$cuantos con la cuenta desactivada',
    'SIN_PERFIL' => '$cuantos sin perfil en el sistema',
    'ROL_NO_RECIBE' =>
      '$cuantos por su rol: solo los catedráticos reciben avisos',
    _ => '$cuantos por «$motivo»',
  };

  static const String envioSinDestinatarios =
      'Nadie recibiría este mensaje. Revisa los destinatarios.';

  static String envioCorrecto(int entregados, int total) =>
      'Enviado. Llegó a $entregados de $total.';
  static String envioConFallos(int entregados, int total, int fallidos) =>
      'Enviado a $entregados de $total. $fallidos sin entregar: '
      'revisa en la bitácora quién no tiene dispositivo registrado.';
  static const String envioFallido =
      'No se pudo enviar. Nada quedó registrado.';

  // --- Adjuntos: nota de voz e imagen (RF-MSG-03, 04, 07, 08) ---------------
  static const String etiquetaAdjuntos = 'Nota de voz e imagen';
  static const String adjuntosDetalle =
      'Opcionales. La voz sirve cuando escribir con prisa no es realista, '
      'y la imagen para un plano o una indicación visual.';
  static const String vozGrabar = 'Grabar nota de voz';
  static const String imagenElegir = 'Adjuntar imagen';
  static const String quitarAdjunto = 'Quitar';

  static const String vozSinSoporte =
      'Este navegador no puede grabar audio. Puedes adjuntar una imagen.';
  static const String vozSinContenido =
      'No se grabó nada. Comprueba que el micrófono funciona.';
  static const String vozMuyPesada =
      'La grabación pesa más de 2 MB. Graba una nota más corta.';
  static const String vozCortadaPorLimite =
      'Se detuvo al llegar al máximo de 60 segundos. La grabación se conservó.';

  static String vozDetener(int segundos) => 'Detener · ${segundos}s';
  static String vozRestantes(int segundos) => segundos <= 10
      ? 'Quedan $segundos segundos'
      : 'Máximo 60 segundos · quedan $segundos';
  static String vozAdjunta(int segundos) => 'Nota de voz · ${segundos}s';

  static String explicarFalloVoz(FalloGrabacion f) => switch (f) {
    FalloGrabacion.sinSoporte =>
      'Este navegador no puede grabar audio. Prueba con Chrome o Safari.',
    FalloGrabacion.permisoDenegado =>
      'No diste permiso al micrófono. Búscalo en los ajustes del sitio, '
          'permítelo y vuelve a intentarlo.',
    FalloGrabacion.sinMicrofono => 'No se encontró ningún micrófono conectado.',
    FalloGrabacion.error =>
      'No se pudo iniciar la grabación. Inténtalo de nuevo.',
  };

  static String explicarRechazoImagen(String motivo) => switch (motivo) {
    'VACIA' => 'Ese archivo está vacío.',
    'MUY_PESADA' => 'La imagen pesa más de 5 MB. Elige una más ligera.',
    'FORMATO' => 'Solo se admiten imágenes JPEG, PNG o WebP.',
    _ => 'No se pudo adjuntar esa imagen.',
  };

  static String pesoLegible(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).round()} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static const String subiendoAdjuntos = 'Subiendo adjuntos…';

  /// Lo que un aviso trae, dicho en la fila plegada.
  ///
  /// Sustituye a la vista previa del cuerpo: una línea cortada a media frase
  /// casi nunca resume el aviso, y saber que hay una nota de voz sí ayuda a
  /// decidir cuál abrir primero.
  /// Filtro de la pantalla de entregas. El número va en la propia pestaña:
  /// «Pendientes (3)» dice de un vistazo si hay algo que perseguir.
  static String filtroTodos(int n) => 'Todos ($n)';
  static String filtroPendientes(int n) => 'Pendientes ($n)';
  static String filtroCompletos(int n) => 'Completos ($n)';
  static const String entregasSinEsteEstado =
      'No hay avisos en este estado.';

  /// Pestañas de la bandeja. El número va dentro: un filtro sin contador
  /// obliga a entrar para descubrir que está vacío.
  static String filtroBandeja(String cual, int n) => switch (cual) {
    'sinLeer' => 'Sin leer ($n)',
    'sinConfirmar' => 'Sin confirmar ($n)',
    'leidos' => 'Leídos ($n)',
    _ => 'Todos ($n)',
  };

  /// Una bandeja vacía tiene que decir POR QUÉ lo está: si no, se lee como que
  /// algo se perdió, cuando es justo lo contrario.
  static String filtroVacio(String cual) => switch (cual) {
    'sinLeer' => 'Está al día: no tiene mensajes sin abrir.',
    'sinConfirmar' => 'No tiene nada pendiente de confirmar.',
    'leidos' => 'Todavía no ha terminado con ningún mensaje.',
    _ => 'No hay mensajes.',
  };

  static const String filtroVerTodos = 'Ver todos los mensajes';

  static const String traeVoz = 'Nota de voz';
  static const String traeImagen = 'Imagen';

  /// Quién firma el aviso.
  ///
  /// Ante un mensaje que pide salir del edificio, saber quién lo manda es
  /// parte de decidir si obedecerlo. Y en las listas del emisor —entregas,
  /// programados— es lo primero que se pregunta cuando varias personas
  /// comparten el panel.
  static String enviadoPor(String nombre) => 'De $nombre';

  /// Un botón que ya no puede añadir nada lo dice en su etiqueta. Pulsarlo y
  /// que no pase nada es peor que no ofrecerlo.
  static const String vozAlMaximo = 'Ya van 2 notas de voz';
  static const String imagenAlMaximo = 'Ya van 3 imágenes';
  static const String adjuntosMuyPesados =
      'Los adjuntos sumarían más de 10 MB. Quita alguno: con una conexión '
      'mala, un mensaje así no llega.';

  /// El orden importa, y quien redacta tiene que saber que importa.
  static String adjuntosOrden(String peso) =>
      'Se verán en este orden. En total, $peso.';

  /// Por qué el botón de enviar no se puede pulsar ahora mismo.
  ///
  /// Lo dice el propio botón. Uno gris y mudo deja a la persona intentándolo
  /// sin saber qué le falta.
  static const String adjuntoAMedias = 'Termina el adjunto antes de enviar';

  /// Qué va adjunto, dicho en la confirmación previa al envío.
  ///
  /// Enviar es irreversible, así que lo que se lleva el mensaje tiene que
  /// verse ANTES, junto al número de destinatarios y por la misma razón: es la
  /// última ocasión de notar que falta algo que se creía puesto.
  static const String resumenSinAdjuntos = 'Va solo con texto.';

  /// Dice **cuántos** de cada cosa, no solo que los hay.
  ///
  /// Con varios adjuntos, «va con imagen» no permite notar que falta la
  /// segunda, que es justo lo que este resumen existe para evitar.
  static String resumenAdjuntos({required int voces, required int imagenes}) {
    String plural(int n, String uno, String varios) =>
        n == 1 ? '1 $uno' : '$n $varios';

    final List<String> partes = <String>[
      if (voces > 0) plural(voces, 'nota de voz', 'notas de voz'),
      if (imagenes > 0) plural(imagenes, 'imagen', 'imágenes'),
    ];
    return 'Va con ${partes.join(' y ')}.';
  }

  /// Una subida que falla dice CUÁL falló.
  ///
  /// «No se pudo enviar» deja a la persona sin saber si repetir el mensaje
  /// entero o solo volver a adjuntar.
  static const String falloSubidaVoz =
      'No se pudo subir la nota de voz, así que no se envió nada. '
      'Vuelve a intentarlo.';
  static const String falloSubidaImagen =
      'No se pudo subir la imagen, así que no se envió nada. '
      'Vuelve a intentarlo o quita la imagen para enviar el resto.';

  // --- Grupos de destinatarios (RF-USR-03, RF-USR-04, DT-08) ----------------
  static const String grupoNuevo = 'Nuevo grupo';
  static const String grupoEditar = 'Editar grupo';
  static const String grupoNombre = 'Nombre del grupo';
  static const String grupoDescripcion = 'Descripción (opcional)';
  static const String grupoBuscar = 'Buscar por nombre o correo';
  static const String grupoQuitarTodos = 'Quitar todos';
  static const String grupoGuardar = 'Guardar';
  static const String grupoGuardando = 'Guardando…';
  static const String grupoDesactivar = 'Desactivar';
  static const String grupoReactivar = 'Reactivar';
  static const String grupoDesactivarTitulo = '¿Desactivar el grupo?';
  static const String grupoSinElegibles =
      'No hay personas disponibles. Invítalas primero desde Usuarios.';
  static const String grupoNinguno =
      'Todavía no hay grupos. Créalos para poder enviar avisos a un conjunto '
      'concreto de catedráticos en vez de a todos.';
  static const String grupoErrorGuardar =
      'No se pudo guardar el grupo. Inténtalo de nuevo.';
  static const String grupoValidacionNombre = 'El grupo necesita un nombre.';
  static const String grupoValidacionSinMiembros =
      'Elige al menos una persona. Un grupo vacío no le llegaría a nadie.';

  static String grupoMiembros(int cuantos) =>
      cuantos == 1 ? '1 miembro' : '$cuantos miembros';
  static String grupoInactivo(int cuantos) =>
      'Desactivado · ${grupoMiembros(cuantos)}';
  static String grupoElegidos(int cuantos) =>
      cuantos == 0 ? 'Nadie elegido todavía' : '$cuantos elegidos';
  static String grupoRozaElLimite(int maximo) =>
      'Este grupo se acerca al máximo de $maximo miembros.';
  static String grupoDesactivarAviso(String nombre) =>
      'No se borra: «$nombre» dejará de aparecer al redactar, pero se conserva '
      'para que los avisos ya enviados sigan diciendo a quién fueron. '
      'Puedes reactivarlo cuando quieras.';

  // --- Detalle del mensaje (RF-ENT-07, 08, 09) ------------------------------
  static const String detalleTitulo = 'Detalle del aviso';
  static const String detalleNotaDeVoz = 'Nota de voz';
  static const String detalleImagen = 'Imagen adjunta';
  static const String detalleSinAdjuntos = 'Este aviso es solo de texto.';
  // --- Programación y recurrencia (RF-PRG-02..11) ---------------------------
  static const String cuandoEnviar = '¿Cuándo se envía?';
  static const String cuandoAhora = 'Ahora mismo';
  static const String cuandoProgramado = 'En una fecha y hora';
  static const String cuandoRecurrente = 'Repetido cada cierto tiempo';
  static const String elegirFecha = 'Elegir fecha';
  static const String elegirHora = 'Elegir hora';
  static const String botonProgramar = 'Programar envío';
  static const String programandoEnvio = 'Programando…';

  static const String repetirCada = 'Repetir cada';
  static const String repetirDesde = 'Desde';
  static const String repetirHasta = 'Hasta';
  static const String repetirHora = 'A las';
  static const String repetirDias = 'Solo estos días';
  static const String repetirTodosLosDias = 'Sin restricción: todos los días';
  static const String vistaPreviaTitulo = 'Próximas ocurrencias';
  static const String vistaPreviaCalcular = 'Ver las próximas fechas';
  static const String vistaPreviaCalculando = 'Calculando…';
  static const String vistaPreviaVacia =
      'Ese patrón no produce ninguna fecha. Revisa el rango, los días y la hora.';
  static const String vistaPreviaPorQue =
      'Un patrón de repetición es fácil de equivocar. Diez fechas concretas '
      'contestan lo que ninguna descripción contesta.';
  static const String vistaPreviaObligatoria =
      'Mira las próximas fechas antes de programar la repetición.';

  static const String validacionFechaObligatoria = 'Elige la fecha y la hora.';
  static const String validacionFechaPasada =
      'Esa fecha y hora ya pasaron. Elige un momento futuro.';
  static const String validacionRangoInvalido =
      'La fecha de fin tiene que ser posterior a la de inicio.';
  static const String recurrenciaFinObligatoria =
      'Toda repetición necesita una fecha de fin. Sin ella sería un envío sin '
      'freno esperando a que alguien se acuerde de pararlo.';

  static String diaSemanaCorto(int dia) => switch (dia) {
    1 => 'Lun',
    2 => 'Mar',
    3 => 'Mié',
    4 => 'Jue',
    5 => 'Vie',
    6 => 'Sáb',
    _ => 'Dom',
  };

  static String programadoCorrecto(String cuando) =>
      'Programado. Saldrá el $cuando.';
  static String recurrenteCorrecto(String primera) =>
      'Repetición programada. La primera vez será el $primera.';

  // --- Lista de programados (RF-PRG-10, 11) ---------------------------------
  static const String programadosTitulo = 'Mensajes programados';
  static const String programadosVacia =
      'No hay nada programado. Los envíos que dejes preparados aparecerán aquí, '
      'con su próxima fecha.';
  static const String accionSuspender = 'Suspender';
  static const String accionReanudar = 'Reanudar';
  static const String accionCancelar = 'Cancelar';
  static const String cancelarTitulo = '¿Cancelar la programación?';

  /// El botón de descartar el diálogo NO puede decir «Cancelar».
  ///
  /// En el diálogo de cancelar una programación habría dos botones diciendo
  /// lo mismo con significados opuestos: uno cancela la programación y el
  /// otro cancela la cancelación. Se nombra por lo que hace.
  static const String noCancelarNada = 'No, dejarla activa';
  static const String cancelarAviso =
      'Cancelar es definitivo: la programación se detiene y no se puede '
      'retomar. Si solo quieres pausarla, usa Suspender.';
  static const String suspenderAviso =
      'Se detiene sin perderse. Puedes reanudarla cuando quieras.';
  static const String yaEnviadoNoSeToca =
      'Ya se envió. Lo enviado no se cancela ni se edita.';

  static String proximaSalida(String cuando) => 'Próxima salida: $cuando';

  static const String destinatariosTodosCorto = 'A todos los catedráticos';
  static const String destinatariosIndividual = 'A personas concretas';
  static const String llevaNotaDeVoz = 'Nota de voz';
  static const String llevaImagenAdjunta = 'Imagen';
  static const String pideConfirmacion = 'Pide confirmación';

  static String destinatariosGruposCorto(List<String> nombres) =>
      nombres.isEmpty
      ? 'A grupos'
      : nombres.length == 1
      ? 'Al grupo ${nombres.first}'
      : 'A ${nombres.length} grupos: ${nombres.join(', ')}';
  static String estadoProgramacion(String estado) => switch (estado) {
    'PROGRAMADO' => 'Programado',
    'RECURRENTE_PENDIENTE' => 'Repitiéndose',
    'SUSPENDIDO' => 'Suspendido',
    'CANCELADO' => 'Cancelado',
    'ENVIADO' => 'Enviado',
    'ENVIADO_CON_FALLOS' => 'Enviado con fallos',
    'AGOTADO' => 'Repeticiones agotadas',
    'EN_ENVIO' => 'Enviando…',
    'FALLIDO' => 'Falló',
    _ => estado,
  };

  // --- Confirmación de lectura (RF-CNF-01..07) ------------------------------
  static const String confirmandoLectura = 'Confirmando…';
  static const String confirmacionHecha =
      'Confirmado. Queda constancia de que lo leíste.';
  static const String confirmacionYaHecha =
      'Este mensaje ya estaba confirmado. Una confirmación no se repite.';
  static const String confirmarTitulo = '¿Confirmar que lo leíste?';
  static const String confirmarAviso =
      'Queda registrado con tu nombre, la hora exacta y este dispositivo. '
      'No se puede deshacer.';
  static const String confirmarSi = 'Sí, lo leí';

  static const String entregasTitulo = 'Reporte de entregas';
  static const String entregasVacia =
      'Todavía no hay mensajes enviados. Aquí verás quién recibió cada aviso y '
      'quién lo confirmó.';
  static String enviadoEl(String cuando) => 'Enviado el $cuando';
  static String ultimaSalidaEl(String cuando) => 'Última salida el $cuando';
  static const String sinFechaDeEnvio = 'Todavía sin enviar';

  static const String verQuienFalta = 'Ver quién falta';
  static const String ocultarQuienFalta = 'Ocultar la lista';
  static const String cargandoDestinatarios = 'Cargando destinatarios…';
  static const String nadiePendiente = 'Todos confirmaron.';
  static const String estadoNoLeLlego = 'No le llegó';
  static const String estadoSinConfirmar = 'Sin confirmar';
  static const String errorDetalleEntregas =
      'No se pudo cargar la lista de destinatarios.';
  static const String detalleFallidosPrimero =
      'Primero quienes no lo recibieron, después quienes no lo han '
      'confirmado. Los dos casos se resuelven distinto.';

  static const String entregasSinConfirmacion =
      'Este aviso no exigía confirmación.';

  /// La apertura, dicha con el peso que tiene y no más.
  ///
  /// ──────────────────────────────────────────────────────────────────────────
  /// «Abrió» NO es «confirmó», y el reporte no puede insinuar que sí.
  /// ──────────────────────────────────────────────────────────────────────────
  ///
  /// Abrir dice que la aplicación mostró el mensaje delante de la persona.
  /// Confirmar dice que esa persona declaró haberlo leído, con su nombre y la
  /// hora. Lo primero es un indicio; lo segundo, evidencia. Escribirlos con la
  /// misma contundencia sería convertir uno en el otro.
  static String entregasAbiertos(int abiertos, int total, int porcentaje) =>
      'Abierto por $abiertos de $total · $porcentaje %';

  static String entregasSinAbrir(int cuantos) => cuantos == 1
      ? '1 lo recibió y no lo ha abierto'
      : '$cuantos lo recibieron y no lo han abierto';

  static const String entregasAbrirNoEsConfirmar =
      'Abrir no es confirmar: indica que el mensaje se mostró, no que alguien '
      'declarara haberlo leído.';

  static const String detalleNoAbrio = 'No lo ha abierto';
  static const String detalleAbrio = 'Lo abrió';
  static const String detalleAbrioSinConfirmar = 'Lo abrió, sin confirmar';

  static String entregasResumen(int entregados, int total) =>
      'Entregado a $entregados de $total';
  static String entregasConfirmados(
    int confirmados,
    int total,
    int porcentaje,
  ) => 'Confirmado por $confirmados de $total · $porcentaje %';
  static String entregasPendientes(int cuantos) =>
      cuantos == 1 ? 'Falta 1 por confirmar' : 'Faltan $cuantos por confirmar';

  // --- Búsqueda y paginación ------------------------------------------------
  static const String volverArriba = 'Volver arriba';
  static const String etiquetaSinLeer = 'Sin leer';
  static const String etiquetaSinConfirmar = 'Falta confirmar';
  static const String verDetalle = 'Ver detalle';
  static const String ocultarDetalle = 'Ocultar';
  static const String plegarTodo = 'Plegar todo';
  static const String desplegarTodo = 'Desplegar todo';

  static const String buscarMensajes = 'Buscar en título y mensaje';
  static const String buscarBitacora = 'Buscar en la bitácora';
  static const String buscarProgramados = 'Buscar por título o grupo';
  static const String buscarEntregas = 'Buscar por título o grupo';
  static const String buscarLimpiar = 'Limpiar búsqueda';
  static const String verMas = 'Ver más';
  static const String cargandoMas = 'Cargando…';

  static String sinResultados(String termino) =>
      'Nada coincide con «$termino».';
  static String mostrandoDe(int mostrados, int total) =>
      'Mostrando $mostrados de $total';
  static String coincidencias(int cuantas) =>
      cuantas == 1 ? '1 coincidencia' : '$cuantas coincidencias';

  static const String imagenTocarParaVer = 'Ver imagen adjunta';
  static const String imagenCargando = 'Cargando imagen…';
  static const String imagenTocarParaAmpliar = 'Toca para ampliar';

  static const String detalleErrorAdjunto =
      'No se pudo cargar el adjunto. Revisa tu conexión.';

  // --- Instructivo de instalación en iOS (RES-05, R-02) ---------------------
  static const String ingresoInstalarTitulo = 'Instálala en tu iPhone';
  static const String ingresoInstalarDetalle =
      'En iPhone no hay botón de instalar: se hace desde Compartir, en Safari. '
      'Sin ese paso no te llegará ninguna notificación. Toca para ver cómo.';

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
      texto:
          'Pulsa el botón Compartir, el cuadrado con la flecha hacia arriba.',
      icono: Icons.ios_share,
    ),
    (
      numero: 3,
      texto: 'Desliza y elige «Añadir a pantalla de inicio».',
      icono: Icons.add_to_home_screen,
    ),
    (
      numero: 4,
      texto: 'Confirma con «Añadir».',
      icono: Icons.check_circle_outline,
    ),
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
