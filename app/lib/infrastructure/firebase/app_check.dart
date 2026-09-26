/// SIAN — App Check en la aplicación (DT-33).
///
/// La aplicación solo **pide** el token y lo adjunta a cada llamada; quien
/// decide si una llamada sin token se rechaza son las funciones
/// (`EXIGIR_APP_CHECK`). Mientras se observa, una llamada sin token sigue
/// funcionando, y por eso encenderlo aquí no puede romper nada — siempre que
/// no rompa el arranque, que es lo que cuida [activarAppCheck].
///
/// El proveedor es reCAPTCHA Enterprise: no tiene clave secreta que guardar,
/// solo la clave de sitio, que es pública y entra por `--dart-define`.
library;

import 'package:firebase_app_check/firebase_app_check.dart';

import '../../core/plataforma/consola.dart';

/// ¿Hay que encender App Check en este arranque?
///
/// Contra los emuladores no: reCAPTCHA no acepta `localhost` sin registrarlo,
/// y los emuladores no lo verifican. Sin clave tampoco: el ambiente todavía no
/// lo tiene dado de alta.
bool debeActivarAppCheck({required bool usaEmulador, required String clave}) =>
    !usaEmulador && clave.trim().isNotEmpty;

/// Enciende App Check si corresponde. Devuelve si quedó encendido.
///
/// Nunca lanza: si reCAPTCHA no carga (red, bloqueador, un iPhone sin
/// conexión), la aplicación arranca igual y las llamadas salen sin token, que
/// es exactamente lo que pasaba antes de App Check.
Future<bool> activarAppCheck({
  required String clave,
  required bool usaEmulador,
  Future<void> Function(String clave)? activar,
}) async {
  if (!debeActivarAppCheck(usaEmulador: usaEmulador, clave: clave)) {
    return false;
  }
  try {
    await (activar ?? _activarConRecaptcha)(clave.trim());
    return true;
  } on Object catch (e) {
    consolaError('App Check no se pudo encender: $e');
    return false;
  }
}

Future<void> _activarConRecaptcha(String clave) => FirebaseAppCheck.instance
    .activate(providerWeb: ReCaptchaEnterpriseProvider(clave));
