/// SIAN — Arranque de Firebase.
///
/// Esta es la **única** puerta de entrada de Firebase en la aplicación. El
/// resto de las capas habla con repositorios y adaptadores, nunca con el SDK
/// directamente (RNF-19): si el dominio dependiera de Firebase, migrar de
/// proveedor obligaría a reescribirlo, que es justo lo que la arquitectura
/// evita.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entorno.dart';
import '../../firebase_options.dart';

/// A qué está conectada la aplicación en este arranque.
enum ConexionFirebase {
  /// Emuladores locales. Recuerda: **no entregan notificaciones push reales**
  /// (documento 06, etapa D.5). FCM no tiene emulador.
  emuladores,

  /// Proyecto real en la nube.
  nube,

  /// El arranque falló. La aplicación sigue viva y lo dice en pantalla, en
  /// lugar de morir con un error críptico.
  fallida,
}

@immutable
class ResultadoArranque {
  const ResultadoArranque({required this.conexion, this.detalle});

  final ConexionFirebase conexion;

  /// Mensaje legible cuando algo salió mal. Nulo si todo fue bien.
  final String? detalle;

  bool get correcto => conexion != ConexionFirebase.fallida;
}

/// Resultado del arranque, disponible para toda la aplicación.
///
/// `main` lo sobrescribe con el valor real. Que exista un valor por defecto
/// permite montar cualquier pantalla en una prueba de widget sin tocar la red
/// ni levantar un emulador.
final Provider<ResultadoArranque> arranqueProvider = Provider<ResultadoArranque>(
  (Ref ref) => const ResultadoArranque(
    conexion: ConexionFirebase.fallida,
    detalle: 'Sin inicializar',
  ),
);

/// Inicializa Firebase y, en desarrollo, redirige todo a los emuladores.
///
/// No lanza: un fallo de arranque se devuelve como resultado para que la
/// interfaz pueda explicarlo. Una pantalla en blanco no le dice nada a nadie.
Future<ResultadoArranque> inicializarFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Los correos que manda Firebase —restablecer contraseña, verificar
    // dirección— salen en el idioma que se fije aquí. Sin esto llegan en
    // inglés, y un correo en inglés que dice «project-863854823370» es
    // indistinguible de una suplantación para quien lo recibe.
    await FirebaseAuth.instance.setLanguageCode('es');

    if (Entorno.usaEmulador) {
      await _conectarEmuladores();
      return const ResultadoArranque(conexion: ConexionFirebase.emuladores);
    }

    return const ResultadoArranque(conexion: ConexionFirebase.nube);
  } on FirebaseException catch (e) {
    return ResultadoArranque(
      conexion: ConexionFirebase.fallida,
      detalle: 'Firebase rechazó el arranque: ${e.code}. ${e.message ?? ''}',
    );
  } on Object catch (e) {
    return ResultadoArranque(
      conexion: ConexionFirebase.fallida,
      detalle: 'No se pudo inicializar Firebase: $e',
    );
  }
}

/// Redirige Auth, Firestore, Functions y Storage a los emuladores locales.
///
/// Los puertos son los declarados en `firebase.json`: si cambian ahí, cambian
/// en [Entorno] y en ningún otro sitio.
Future<void> _conectarEmuladores() async {
  const String host = Entorno.hostEmulador;

  await FirebaseAuth.instance.useAuthEmulator(host, Entorno.puertoAuth);
  FirebaseFirestore.instance.useFirestoreEmulator(host, Entorno.puertoFirestore);
  FirebaseFunctions.instance.useFunctionsEmulator(host, Entorno.puertoFunctions);
  await FirebaseStorage.instance.useStorageEmulator(host, Entorno.puertoStorage);
}
