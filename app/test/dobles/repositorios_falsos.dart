/// Dobles de prueba en memoria.
///
/// Documento 02, sección 3: el patrón Repository existe precisamente para
/// «permitir pruebas con repositorios en memoria». Ninguna prueba de este
/// paquete toca la red, Firebase ni un emulador.
library;

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sian/domain/repositorios.dart';
import 'package:sian/core/navegador.dart';
import 'package:sian/infrastructure/firebase/repositorio_administracion.dart';
import 'package:sian/infrastructure/firebase/repositorio_dispositivos.dart';
import 'package:sian/infrastructure/firebase/repositorio_adjuntos.dart';
import 'package:sian/infrastructure/firebase/repositorio_envio.dart';
import 'package:sian/infrastructure/firebase/repositorio_grupos.dart';
import 'package:sian/infrastructure/firebase/repositorio_programacion.dart';
import 'package:sian/domain/rol.dart';
import 'package:sian/domain/sesion.dart';

class RepositorioSesionFalso implements RepositorioSesion {
  RepositorioSesionFalso({Sesion inicial = const SesionAnonima()})
    : _ultima = inicial;

  final StreamController<Sesion> _controlador =
      StreamController<Sesion>.broadcast();

  /// Último estado emitido.
  ///
  /// Un `broadcast` no guarda nada: quien se suscriba después de una emisión
  /// no la recibe jamás. Firebase sí entrega el estado actual al suscribirse,
  /// así que el doble tiene que hacer lo mismo o mentiría sobre el
  /// comportamiento que imita.
  Sesion _ultima;

  /// Credenciales aceptadas: correo → sesión resultante.
  final Map<String, Sesion> credenciales = <String, Sesion>{};

  /// Registro de lo ocurrido, para poder afirmar sobre ello.
  final List<String> correosIntentados = <String>[];
  final List<String> correosRecuperados = <String>[];
  int vecesQueSalio = 0;

  /// Rechazo sin reconocer. Misma regla que el repositorio real: una sesión
  /// anónima que llega tras un rechazo no lo borra, porque la credencial
  /// desaparece precisamente a causa del rechazo.
  SesionRechazada? _rechazoSinReconocer;

  /// ¿Queda credencial viva en «Firebase»?
  ///
  /// ──────────────────────────────────────────────────────────────────────
  /// Un rechazo deja al cliente SIN credencial.
  /// ──────────────────────────────────────────────────────────────────────
  ///
  /// El servidor borra la credencial recién creada para no dejar cuentas
  /// huérfanas. Importa reproducirlo porque `authStateChanges` solo avisa de
  /// **cambios**: cerrar una sesión que ya estaba cerrada no emite nada, y
  /// este doble tiene que callarse igual que Firebase o dejaría pasar
  /// justamente el fallo que dejó muerto el botón «Volver al inicio de
  /// sesión».
  bool _hayCredencial = false;

  /// Empuja un estado de sesión, como si Firebase hubiera cambiado.
  void emitir(Sesion sesion) {
    Sesion efectiva = sesion;

    if (sesion is SesionRechazada) {
      _rechazoSinReconocer = sesion;
      _hayCredencial = false;
    } else if (sesion is SesionActiva) {
      _rechazoSinReconocer = null;
      _hayCredencial = true;
    } else if (sesion is SesionAnonima) {
      _hayCredencial = false;
      if (_rechazoSinReconocer != null) {
        efectiva = _rechazoSinReconocer!;
      }
    }

    _ultima = efectiva;
    if (_controlador.hasListener) {
      _controlador.add(efectiva);
    }
  }

  @override
  Stream<Sesion> observar() async* {
    yield _ultima;
    yield* _controlador.stream;
  }

  @override
  Future<void> entrarConCorreo({
    required String correo,
    required String contrasena,
  }) async {
    correosIntentados.add(correo);
    final Sesion? resultado = credenciales[correo.trim().toLowerCase()];
    if (resultado == null) {
      throw StateError('credenciales no válidas');
    }
    emitir(resultado);
  }

  /// Correos que el doble acepta registrar. Los demás se rechazan, como haría
  /// la lista blanca.
  final Set<String> correosInvitados = <String>{};

  final List<String> correosRegistrados = <String>[];

  /// Sesión que devuelve el inicio con Google, si se configuró.
  Sesion? resultadoGoogle;
  int vecesQueEntroConGoogle = 0;

  @override
  Future<void> entrarConGoogle() async {
    vecesQueEntroConGoogle += 1;
    final Sesion? r = resultadoGoogle;
    if (r != null) {
      emitir(r);
    }
  }

  @override
  Future<void> registrarConCorreo({
    required String correo,
    required String contrasena,
  }) async {
    final String normalizado = correo.trim().toLowerCase();
    correosRegistrados.add(normalizado);

    if (!correosInvitados.contains(normalizado)) {
      // Igual que en producción: la credencial se crea, pero el servidor la
      // rechaza y la borra por no estar en la lista blanca.
      emitir(
        SesionRechazada(
          motivo: MotivoRechazo.fueraDeListaBlanca,
          correo: normalizado,
        ),
      );
      return;
    }

    final Sesion? resultado = credenciales[normalizado];
    if (resultado != null) {
      emitir(resultado);
    }
  }

  @override
  Future<void> recuperarContrasena(String correo) async {
    correosRecuperados.add(correo);
  }

  @override
  Future<void> salir() async {
    vecesQueSalio += 1;
    _rechazoSinReconocer = null;

    // Si no quedaba credencial, Firebase no emite nada: no hay cambio que
    // anunciar. Callarse aquí es lo fiel, y es lo que obliga a que volver del
    // rechazo funcione sin depender de un evento que nunca llega.
    if (_hayCredencial) {
      emitir(const SesionAnonima());
    }
  }

  Future<void> cerrar() => _controlador.close();
}

class RepositorioBandejaFalso implements RepositorioBandeja {
  RepositorioBandejaFalso(this.mensajes);

  final List<MensajeRecibido> mensajes;

  /// UIDs con los que se consultó el historial. Sirve para verificar que la
  /// bandeja pide **su** historial y no el de otro.
  final List<String> uidsConsultados = <String>[];

  @override
  Stream<List<MensajeRecibido>> observarHistorial(String uid) {
    uidsConsultados.add(uid);
    return Stream<List<MensajeRecibido>>.value(mensajes);
  }
}

/// Usuario de prueba con valores por omisión razonables.
UsuarioSesion usuarioDePrueba({
  required Rol rol,
  String uid = 'uid-1',
  String nombre = 'Persona de Prueba',
  String correo = 'prueba@umg.edu.gt',
  bool puedeEmitirUrgentes = false,
  bool puedeCrearRecurrentes = false,
}) {
  return UsuarioSesion(
    uid: uid,
    correo: correo,
    nombre: nombre,
    rol: rol,
    activo: true,
    puedeEmitirUrgentes: puedeEmitirUrgentes,
    puedeCrearRecurrentes: puedeCrearRecurrentes,
  );
}

/// Copia un usuario cambiando solo si recibe avisos.
extension ConRecepcion on UsuarioSesion {
  UsuarioSesion conRecepcion(bool recibe) => UsuarioSesion(
    uid: uid,
    correo: correo,
    nombre: nombre,
    rol: rol,
    activo: activo,
    puedeEmitirUrgentes: puedeEmitirUrgentes,
    puedeCrearRecurrentes: puedeCrearRecurrentes,
    recibeAvisos: recibe,
  );
}

/// Doble del repositorio de administración.
///
/// Extiende el real en lugar de reimplementarlo: solo se sustituyen las
/// lecturas, que son las únicas que una prueba de widget necesita. Las
/// escrituras van a Cloud Functions y no se ejercitan aquí.
class RepositorioAdminFalso extends RepositorioAdministracion {
  RepositorioAdminFalso({
    this.invitaciones = const <InvitacionVista>[],
    this.usuarios = const <UsuarioVista>[],
    this.asientos = const <AsientoVista>[],
  });

  final List<InvitacionVista> invitaciones;
  final List<UsuarioVista> usuarios;
  final List<AsientoVista> asientos;

  @override
  Stream<List<InvitacionVista>> observarInvitaciones() =>
      Stream<List<InvitacionVista>>.value(invitaciones);

  @override
  Stream<List<UsuarioVista>> observarUsuarios() =>
      Stream<List<UsuarioVista>>.value(usuarios);

  @override
  Stream<List<AsientoVista>> observarBitacora({
    String? tipo,
    int limite = 100,
  }) => Stream<List<AsientoVista>>.value(
    tipo == null || tipo.isEmpty
        ? asientos
        : asientos.where((AsientoVista a) => a.tipo == tipo).toList(),
  );
}

/// Doble del repositorio de dispositivos.
///
/// Extiende el real y sustituye únicamente lo que habla con Firebase Cloud
/// Messaging, que no existe en la máquina virtual de las pruebas.
class RepositorioDispositivosFalso extends RepositorioDispositivos {
  RepositorioDispositivosFalso({
    required EntornoNavegador entorno,
    this.permiso = EstadoPermiso.pendiente,
    this.resultado,
  }) : super(entorno: entorno);

  EstadoPermiso permiso;
  ResultadoRegistro? resultado;
  int vecesQuePidioPermiso = 0;

  /// Mensajes que llegan con la aplicación en primer plano.
  ///
  /// El repositorio real devuelve `FirebaseMessaging.onMessage`, que en las
  /// pruebas no existe. Este controlador permite empujar uno a mano y
  /// comprobar que la aplicación lo hace visible — porque el navegador no lo
  /// hace, y durante una ronda entera nadie estaba escuchando.
  // ignore: close_sinks — lo cierra cada prueba en su `tearDown`.
  final StreamController<RemoteMessage> mensajes =
      StreamController<RemoteMessage>.broadcast();

  @override
  Stream<RemoteMessage> mensajesEnPrimerPlano() => mensajes.stream;

  /// Lo llama el `tearDown` de la prueba.
  Future<void> cerrar() => mensajes.close();

  @override
  Future<EstadoPermiso> consultarPermiso() async => permiso;

  /// Cuántas veces se pidió con notificación de prueba. Es lo que se disparaba
  /// de más al desplazar la pantalla.
  int vecesConPrueba = 0;

  @override
  Future<ResultadoRegistro> pedirPermisoYRegistrar({
    bool enviarPrueba = true,
  }) async {
    vecesQuePidioPermiso += 1;
    if (enviarPrueba) {
      vecesConPrueba += 1;
    }
    final ResultadoRegistro r =
        resultado ??
        const ResultadoRegistro(
          permiso: EstadoPermiso.concedido,
          registrado: true,
          puedeRecibir: true,
          pruebaEnviada: true,
        );
    permiso = r.permiso;
    refrescado = true;
    return r;
  }

  bool refrescado = false;

  @override
  bool get yaRefrescado => refrescado;
}

/// Doble del repositorio de envío: registra lo que se le pidió.
class RepositorioEnvioFalso extends RepositorioEnvio {
  RepositorioEnvioFalso({this.conteo = 3});

  final int conteo;

  Map<String, int> motivos = <String, int>{};
  int excluidos = 0;

  int vecesQueConto = 0;
  int vecesQueEnvio = 0;
  bool? ultimaUrgente;
  bool? ultimaConfirmacionUrgente;
  String? ultimoTitulo;
  AdjuntoSubido? ultimaVoz;
  AdjuntoSubido? ultimaImagen;
  ResultadoEnvio? resultado;

  @override
  Future<ConteoDestinatarios> contar(Destinatarios destinatarios) async {
    vecesQueConto += 1;
    return ConteoDestinatarios(
      total: conteo,
      excluidos: excluidos,
      motivos: motivos,
    );
  }

  @override
  Future<ResultadoEnvio> enviarInmediato({
    required String titulo,
    required String cuerpo,
    required bool urgente,
    required bool requiereConfirmacion,
    required Destinatarios destinatarios,
    bool confirmacionUrgente = false,
    String? mensajeId,
    AdjuntoSubido? voz,
    AdjuntoSubido? imagen,
  }) async {
    vecesQueEnvio += 1;
    ultimaVoz = voz;
    ultimaImagen = imagen;
    ultimaUrgente = urgente;
    ultimaConfirmacionUrgente = confirmacionUrgente;
    ultimoTitulo = titulo;

    return resultado ??
        ResultadoEnvio(
          mensajeId: 'm1',
          estado: 'ENVIADO',
          total: conteo,
          entregados: conteo,
          fallidos: 0,
        );
  }
}

/// Doble del repositorio de grupos.
///
/// Extiende el real: solo se sustituyen la lectura y las dos escrituras, que
/// es todo lo que una prueba de widget necesita.
class RepositorioGruposFalso extends RepositorioGrupos {
  RepositorioGruposFalso({
    this.grupos = const <GrupoDetalle>[],
    this.personas = const <Elegible>[],
  });

  final List<GrupoDetalle> grupos;

  /// Quiénes se pueden agrupar. Los devuelve el servidor ya filtrados: un
  /// administrador académico no puede leer el padrón.
  final List<Elegible> personas;

  @override
  Future<List<Elegible>> elegibles() async => personas;

  int vecesQueGuardo = 0;
  String? ultimoNombre;
  List<String>? ultimosMiembros;
  String? ultimoGrupoId;

  final List<({String grupoId, bool activo})> cambiosDeEstado =
      <({String grupoId, bool activo})>[];

  @override
  Stream<List<GrupoDetalle>> observarGrupos() =>
      Stream<List<GrupoDetalle>>.value(grupos);

  @override
  Future<String> guardar({
    required String nombre,
    required String descripcion,
    required List<String> miembros,
    String? grupoId,
  }) async {
    vecesQueGuardo += 1;
    ultimoNombre = nombre;
    ultimosMiembros = miembros;
    ultimoGrupoId = grupoId;
    return grupoId ?? 'g-nuevo';
  }

  @override
  Future<void> cambiarEstado({
    required String grupoId,
    required bool activo,
  }) async {
    cambiosDeEstado.add((grupoId: grupoId, activo: activo));
  }
}

/// Doble del repositorio de programación y confirmación.
class RepositorioProgramacionFalso extends RepositorioProgramacion {
  RepositorioProgramacionFalso({
    this.programados = const <MensajeProgramado>[],
  });

  final List<MensajeProgramado> programados;

  final List<String> abiertos = <String>[];
  final List<String> confirmados = <String>[];
  final List<({String mensajeId, String accion})> cambios =
      <({String mensajeId, String accion})>[];

  /// Error que devolverá la próxima confirmación, si se configura.
  Exception? errorAlConfirmar;

  /// Autor con el que se restringió la consulta, si se restringió.
  ///
  /// Sirve para comprobar que un administrador académico pide SOLO los suyos:
  /// pedir todos no devuelve «los suyos», devuelve `permission-denied`.
  String? filtradoPor;

  @override
  Stream<List<MensajeProgramado>> observarProgramados({String? soloDe}) {
    filtradoPor = soloDe;
    return Stream<List<MensajeProgramado>>.value(programados);
  }

  @override
  Future<void> marcarAbierto(String mensajeId) async {
    abiertos.add(mensajeId);
  }

  @override
  Future<void> confirmarLectura({
    required String mensajeId,
    required String dispositivo,
  }) async {
    final Exception? e = errorAlConfirmar;
    if (e != null) {
      throw e;
    }
    confirmados.add(mensajeId);
  }

  @override
  Future<void> cambiar({
    required String mensajeId,
    required String accion,
  }) async {
    cambios.add((mensajeId: mensajeId, accion: accion));
  }

  /// Detalle que devolverá `detalleEntregas`.
  List<DestinatarioEntrega> detalle = const <DestinatarioEntrega>[];

  /// Cuántas veces se pidió. Sirve para comprobar que NO se pide hasta que
  /// alguien lo abre: son varias lecturas por mensaje.
  int vecesQuePidioDetalle = 0;

  @override
  Future<List<DestinatarioEntrega>> detalleEntregas(String mensajeId) async {
    vecesQuePidioDetalle += 1;
    return detalle;
  }
}
