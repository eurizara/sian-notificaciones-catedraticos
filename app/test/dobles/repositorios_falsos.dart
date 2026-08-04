/// Dobles de prueba en memoria.
///
/// Documento 02, sección 3: el patrón Repository existe precisamente para
/// «permitir pruebas con repositorios en memoria». Ninguna prueba de este
/// paquete toca la red, Firebase ni un emulador.
library;

import 'dart:async';

import 'package:sian/domain/repositorios.dart';
import 'package:sian/core/navegador.dart';
import 'package:sian/infrastructure/firebase/repositorio_administracion.dart';
import 'package:sian/infrastructure/firebase/repositorio_dispositivos.dart';
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

  /// Empuja un estado de sesión, como si Firebase hubiera cambiado.
  void emitir(Sesion sesion) {
    Sesion efectiva = sesion;

    if (sesion is SesionRechazada) {
      _rechazoSinReconocer = sesion;
    } else if (sesion is SesionActiva) {
      _rechazoSinReconocer = null;
    } else if (sesion is SesionAnonima && _rechazoSinReconocer != null) {
      efectiva = _rechazoSinReconocer!;
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
    emitir(const SesionAnonima());
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
  Stream<List<AsientoVista>> observarBitacora({String? tipo, int limite = 100}) =>
      Stream<List<AsientoVista>>.value(
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

  @override
  Future<EstadoPermiso> consultarPermiso() async => permiso;

  @override
  Future<ResultadoRegistro> pedirPermisoYRegistrar() async {
    vecesQuePidioPermiso += 1;
    final ResultadoRegistro r =
        resultado ??
        const ResultadoRegistro(
          permiso: EstadoPermiso.concedido,
          registrado: true,
          puedeRecibir: true,
          pruebaEnviada: true,
        );
    permiso = r.permiso;
    return r;
  }
}
