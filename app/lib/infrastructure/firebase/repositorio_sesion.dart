/// SIAN — Resolución de la sesión contra Firebase.
///
/// Traduce lo que dicen Firebase Authentication y Firestore al vocabulario del
/// dominio (`Sesion`). Es la frontera: de aquí hacia adentro nadie sabe que
/// existe Firebase (RNF-19).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/repositorios.dart';
import '../../domain/rol.dart';
import '../../domain/sesion.dart';

class RepositorioSesionFirebase implements RepositorioSesion {
  RepositorioSesionFirebase({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Emite el estado de sesión cada vez que cambia la autenticación.
  @override
  Stream<Sesion> observar() async* {
    yield const SesionCargando();

    await for (final User? usuario in _auth.authStateChanges()) {
      if (usuario == null) {
        yield const SesionAnonima();
        continue;
      }
      yield const SesionCargando();
      yield await _resolver(usuario);
    }
  }

  /// Convierte un usuario autenticado en una sesión del dominio.
  Future<Sesion> _resolver(User usuario) async {
    final String correo = usuario.email ?? '';

    // `forceRefresh` no es opcional: si los claims se sembraron después de
    // emitirse el token —que es lo normal en el primer acceso—, el token en
    // memoria todavía no trae el rol. Es la causa de «el token de sesión no
    // trae el rol» del anexo del documento 06.
    final IdTokenResult token = await usuario.getIdTokenResult(true);
    final Rol? rol = Rol.desdeClaim(token.claims?['rol']);

    if (rol == null) {
      return SesionRechazada(
        motivo: MotivoRechazo.sinRolEnElToken,
        correo: correo,
      );
    }

    final bool activoEnToken = token.claims?['activo'] == true;
    if (!activoEnToken) {
      return SesionRechazada(
        motivo: MotivoRechazo.cuentaDesactivada,
        correo: correo,
      );
    }

    final DocumentSnapshot<Map<String, dynamic>> perfil = await _firestore
        .doc('usuarios/${usuario.uid}')
        .get();

    if (!perfil.exists) {
      // Token con rol pero sin perfil: el alta no se completó, o el correo
      // nunca estuvo en la lista blanca (RF-AUT-03).
      return SesionRechazada(
        motivo: MotivoRechazo.fueraDeListaBlanca,
        correo: correo,
      );
    }

    final Map<String, dynamic> datos = perfil.data() ?? <String, dynamic>{};

    // El perfil manda sobre el token para `activo`: el token puede llevar
    // hasta una hora emitido, y una desactivación tiene que notarse antes.
    if (datos['activo'] != true) {
      return SesionRechazada(
        motivo: MotivoRechazo.cuentaDesactivada,
        correo: correo,
      );
    }

    return SesionActiva(
      UsuarioSesion(
        uid: usuario.uid,
        correo: (datos['correo'] as String?) ?? correo,
        nombre: (datos['nombre'] as String?) ?? correo,
        rol: rol,
        activo: true,
        puedeEmitirUrgentes: datos['puedeEmitirUrgentes'] == true,
        puedeCrearRecurrentes: datos['puedeCrearRecurrentes'] == true,
      ),
    );
  }

  /// Inicio de sesión con correo y contraseña (RF-AUT-02).
  @override
  Future<void> entrarConCorreo({
    required String correo,
    required String contrasena,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: correo.trim().toLowerCase(),
      password: contrasena,
    );
  }

  /// Recuperación de contraseña por correo (RF-AUT-05).
  @override
  Future<void> recuperarContrasena(String correo) async {
    await _auth.sendPasswordResetEmail(email: correo.trim().toLowerCase());
  }

  /// Cierre de sesión explícito (RF-AUT-07).
  @override
  Future<void> salir() async {
    await _auth.signOut();
  }
}
