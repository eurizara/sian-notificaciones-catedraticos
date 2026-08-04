/// Dobles de prueba en memoria.
///
/// Documento 02, sección 3: el patrón Repository existe precisamente para
/// «permitir pruebas con repositorios en memoria». Ninguna prueba de este
/// paquete toca la red, Firebase ni un emulador.
library;

import 'dart:async';

import 'package:sian/domain/repositorios.dart';
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

  /// Empuja un estado de sesión, como si Firebase hubiera cambiado.
  void emitir(Sesion sesion) {
    _ultima = sesion;
    if (_controlador.hasListener) {
      _controlador.add(sesion);
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

  @override
  Future<void> recuperarContrasena(String correo) async {
    correosRecuperados.add(correo);
  }

  @override
  Future<void> salir() async {
    vecesQueSalio += 1;
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
