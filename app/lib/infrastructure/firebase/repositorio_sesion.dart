/// SIAN — Resolución de la sesión contra Firebase.
///
/// Traduce lo que dicen Firebase Authentication y Firestore al vocabulario del
/// dominio (`Sesion`). Es la frontera: de aquí hacia adentro nadie sabe que
/// existe Firebase (RNF-19).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/repositorios.dart';
import '../../domain/rol.dart';
import '../../domain/sesion.dart';

class RepositorioSesionFirebase implements RepositorioSesion {
  RepositorioSesionFirebase({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// Rechazo que la persona todavía no ha reconocido.
  ///
  /// ────────────────────────────────────────────────────────────────────────
  /// Un rechazo NO se borra porque la credencial desaparezca.
  /// ────────────────────────────────────────────────────────────────────────
  ///
  /// Al rechazar un acceso no autorizado, el servidor **borra la credencial
  /// recién creada** para no dejar cuentas huérfanas. Firebase detecta la
  /// desaparición y emite «sesión anónima» casi a la vez que llega el rechazo.
  /// Sin esta memoria, el segundo evento pisaba al primero y la persona volvía
  /// al formulario sin enterarse de nada.
  ///
  /// La credencial desaparece **a causa** del rechazo, así que su desaparición
  /// no puede ser motivo para dejar de explicarlo. Se limpia únicamente cuando
  /// se cierra sesión de forma explícita, que es lo que hace el botón «Volver
  /// al inicio de sesión» — es decir, cuando ya se leyó el motivo (RF-AUT-03).
  SesionRechazada? _rechazoSinReconocer;

  /// Emite el estado de sesión cada vez que cambia la autenticación.
  @override
  Stream<Sesion> observar() async* {
    yield const SesionCargando();

    await for (final User? usuario in _auth.authStateChanges()) {
      if (usuario == null) {
        yield _rechazoSinReconocer ?? const SesionAnonima();
        continue;
      }

      yield const SesionCargando();
      final Sesion resuelta = await _resolver(usuario);

      if (resuelta is SesionRechazada) {
        _rechazoSinReconocer = resuelta;
      } else if (resuelta is SesionActiva) {
        // Alguien entró de verdad: lo anterior deja de importar.
        _rechazoSinReconocer = null;
      }

      yield resuelta;
    }
  }

  /// Convierte un usuario autenticado en una sesión del dominio.
  ///
  /// El paso decisivo es la llamada a `activarSesion`: hasta que esa Function
  /// responde, la credencial no vale nada. Es ella quien comprueba la lista
  /// blanca, crea el perfil en el primer acceso y siembra los custom claims
  /// (RF-AUT-03, ADR-008).
  Future<Sesion> _resolver(User usuario) async {
    final String correo = usuario.email ?? '';

    try {
      await _functions.httpsCallable('activarSesion').call<Object?>();
    } on FirebaseFunctionsException catch (e) {
      final Sesion rechazo = _interpretarRechazo(e, correo);
      // La credencial ya no sirve de nada: si el servidor no la borró —caso
      // de cuenta desactivada—, al menos se cierra la sesión local para que
      // el siguiente intento parta de cero.
      await _auth.signOut().catchError((_) {});
      return rechazo;
    } on Object {
      // Un fallo de red no es un rechazo. Se trata como sesión sin resolver
      // en lugar de acusar a nadie de no estar autorizado.
      return SesionRechazada(
        motivo: MotivoRechazo.sinRolEnElToken,
        correo: correo,
      );
    }

    // `forceRefresh` no es opcional: los claims acaban de sembrarse desde el
    // servidor y el token en memoria todavía no los trae. Es la causa de «el
    // token de sesión no trae el rol» del anexo del documento 06.
    final IdTokenResult token = await usuario.getIdTokenResult(true);
    final Rol? rol = Rol.desdeClaim(token.claims?['rol']);

    if (rol == null) {
      return SesionRechazada(
        motivo: MotivoRechazo.sinRolEnElToken,
        correo: correo,
      );
    }

    final DocumentSnapshot<Map<String, dynamic>> perfil = await _firestore
        .doc('usuarios/${usuario.uid}')
        .get();

    if (!perfil.exists) {
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

  /// Traduce el error de la Function al motivo del dominio.
  Sesion _interpretarRechazo(FirebaseFunctionsException e, String correo) {
    final Object? detalles = e.details;
    final String motivo = detalles is Map
        ? (detalles['motivo'] as String? ?? '')
        : '';

    return SesionRechazada(
      motivo: motivo == 'CUENTA_DESACTIVADA'
          ? MotivoRechazo.cuentaDesactivada
          : MotivoRechazo.fueraDeListaBlanca,
      correo: correo,
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

  /// Registro con correo y contraseña (RF-AUT-02).
  ///
  /// Crear la credencial **no** concede acceso: el alta solo se completa si
  /// ese correo ya estaba en la lista blanca, y si no lo está el servidor
  /// borra la credencial recién creada (RF-AUT-03).
  @override
  Future<void> registrarConCorreo({
    required String correo,
    required String contrasena,
  }) async {
    await _auth.createUserWithEmailAndPassword(
      email: correo.trim().toLowerCase(),
      password: contrasena,
    );
  }

  /// Cierre de sesión explícito (RF-AUT-07).
  ///
  /// Es también el punto donde se da por reconocido un rechazo: quien pulsa
  /// «Volver al inicio de sesión» ya leyó el motivo.
  @override
  Future<void> salir() async {
    _rechazoSinReconocer = null;
    await _auth.signOut();
  }
}
