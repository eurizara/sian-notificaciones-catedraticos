/// SIAN — Permiso de notificaciones y registro del dispositivo (RF-USR-09).
///
/// Es el punto donde el sistema deja de ser una web y empieza a ser un canal
/// de avisos. Sin un dispositivo registrado y con permiso, un catedrático no
/// recibe nada (RN-02), y ni él ni el emisor tienen forma de saberlo.
///
/// Por eso el registro se rehace **en cada apertura de la aplicación**: en iOS
/// el identificador de notificación cambia solo, y esa es la mitigación
/// principal del riesgo R-01.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../core/entorno.dart';
import '../../core/navegador.dart';
import '../../core/plataforma/consola.dart';

/// Estado del permiso, tal como lo entiende el sistema.
enum EstadoPermiso { concedido, denegado, pendiente, noSoportado }

/// Resultado de intentar dejar el dispositivo listo para recibir.
class ResultadoRegistro {
  const ResultadoRegistro({
    required this.permiso,
    required this.registrado,
    required this.puedeRecibir,
    this.motivoSinRecepcion,
    this.pruebaEnviada = false,
    this.detalleError,
  });

  final EstadoPermiso permiso;
  final bool registrado;

  /// Puede recibir de verdad. En iOS esto es `false` si la PWA no está
  /// instalada, aunque el permiso esté concedido (RES-05).
  final bool puedeRecibir;

  /// `PERMISO_DENEGADO`, `PERMISO_NO_CONCEDIDO`, `IOS_SIN_INSTALAR` o nulo.
  final String? motivoSinRecepcion;

  final bool pruebaEnviada;
  final String? detalleError;
}

class RepositorioDispositivos {
  RepositorioDispositivos({
    FirebaseMessaging? mensajeria,
    FirebaseFunctions? functions,
    EntornoNavegador? entorno,
  }) : _mensajeriaDada = mensajeria,
       _functionsDado = functions,
       _entorno = entorno ?? EntornoNavegador.detectar();

  final FirebaseMessaging? _mensajeriaDada;
  final FirebaseFunctions? _functionsDado;
  final EntornoNavegador _entorno;

  late final FirebaseMessaging _mensajeria =
      _mensajeriaDada ?? FirebaseMessaging.instance;
  late final FirebaseFunctions _fn =
      _functionsDado ?? FirebaseFunctions.instance;

  EntornoNavegador get entorno => _entorno;

  /// Estado actual del permiso, sin pedir nada.
  Future<EstadoPermiso> consultarPermiso() async {
    if (!_entorno.soportaNotificaciones) {
      return EstadoPermiso.noSoportado;
    }
    final NotificationSettings s = await _mensajeria.getNotificationSettings();
    return _traducir(s.authorizationStatus);
  }

  /// Pide el permiso, obtiene el identificador y lo registra en el servidor.
  ///
  /// Devuelve siempre un resultado, nunca lanza: quedarse sin notificaciones
  /// es una situación que hay que **explicar**, no un error que abortar.
  Future<ResultadoRegistro> pedirPermisoYRegistrar() async {
    if (!_entorno.soportaNotificaciones) {
      return const ResultadoRegistro(
        permiso: EstadoPermiso.noSoportado,
        registrado: false,
        puedeRecibir: false,
        motivoSinRecepcion: 'NAVEGADOR_SIN_SOPORTE',
      );
    }

    try {
      final NotificationSettings ajustes = await _mensajeria
          .requestPermission();
      final EstadoPermiso permiso = _traducir(ajustes.authorizationStatus);
      consolaError('SIAN.dispositivo permiso | estado=$permiso');

      if (permiso != EstadoPermiso.concedido) {
        // Sin permiso no hay identificador que obtener, pero el intento sí se
        // registra: al emisor le sirve saber quién no puede recibir y por qué.
        return await _registrarEnServidor(token: null, permiso: permiso);
      }

      final String? token = await _mensajeria.getToken(
        vapidKey: Entorno.claveVapid.isEmpty ? null : Entorno.claveVapid,
      );
      consolaError('SIAN.dispositivo token | obtenido=${token != null}');

      return await _registrarEnServidor(token: token, permiso: permiso);
    } on Object catch (e) {
      consolaError('SIAN.dispositivo error | $e');
      return ResultadoRegistro(
        permiso: EstadoPermiso.pendiente,
        registrado: false,
        puedeRecibir: false,
        motivoSinRecepcion: 'ERROR',
        detalleError: '$e',
      );
    }
  }

  Future<ResultadoRegistro> _registrarEnServidor({
    required String? token,
    required EstadoPermiso permiso,
  }) async {
    if (token == null) {
      return ResultadoRegistro(
        permiso: permiso,
        registrado: false,
        puedeRecibir: false,
        motivoSinRecepcion: permiso == EstadoPermiso.denegado
            ? 'PERMISO_DENEGADO'
            : 'PERMISO_NO_CONCEDIDO',
      );
    }

    final HttpsCallableResult<Object?> r = await _fn
        .httpsCallable('registrarDispositivo')
        .call<Object?>(<String, Object?>{
          'tokenFCM': token,
          'plataforma': _entorno.plataformaPersistida,
          'esPWAInstalada': _entorno.instalada,
          'navegador': _entorno.navegador,
          'permisoNotificacion': switch (permiso) {
            EstadoPermiso.concedido => 'concedido',
            EstadoPermiso.denegado => 'denegado',
            _ => 'pendiente',
          },
        });

    final Map<Object?, Object?> datos =
        (r.data as Map<Object?, Object?>?) ?? <Object?, Object?>{};

    return ResultadoRegistro(
      permiso: permiso,
      registrado: datos['registrado'] == true,
      puedeRecibir: datos['puedeRecibir'] == true,
      motivoSinRecepcion: datos['motivoSinRecepcion'] as String?,
      pruebaEnviada: datos['pruebaEnviada'] == true,
    );
  }

  /// Mensajes que llegan con la aplicación en primer plano.
  ///
  /// El navegador **no** muestra notificación del sistema en este caso: es la
  /// aplicación la que tiene que hacerse notar. Es también la mitigación de
  /// DT-02 en iOS, donde no se puede definir sonido propio.
  Stream<RemoteMessage> mensajesEnPrimerPlano() => FirebaseMessaging.onMessage;

  EstadoPermiso _traducir(AuthorizationStatus estado) => switch (estado) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => EstadoPermiso.concedido,
    AuthorizationStatus.denied => EstadoPermiso.denegado,
    AuthorizationStatus.notDetermined => EstadoPermiso.pendiente,
  };
}
