/// SIAN — Interfaces de repositorio (patrón Repository, documento 02, §3).
///
/// El dominio declara **qué** necesita; la infraestructura decide **cómo**. Sin
/// esta separación no habría forma de probar una pantalla sin levantar
/// Firebase, y la regla de dependencia de la arquitectura quedaría en un dibujo
/// bonito del documento 02 (RNF-19).
library;

import 'sesion.dart';

abstract interface class RepositorioSesion {
  /// Emite el estado de sesión cada vez que cambia la autenticación.
  Stream<Sesion> observar();

  /// Inicio de sesión con correo y contraseña (RF-AUT-02).
  Future<void> entrarConCorreo({
    required String correo,
    required String contrasena,
  });

  /// Inicio de sesión con la cuenta institucional de Google (RF-AUT-01).
  ///
  /// Autenticar con Google **no** concede acceso: el correo tiene que estar
  /// en la lista blanca igual que con cualquier otro proveedor (RF-AUT-03).
  Future<void> entrarConGoogle();

  /// Registro con correo y contraseña (RF-AUT-02).
  ///
  /// Crear la credencial no concede acceso: el alta solo se completa si el
  /// correo está en la lista blanca (RF-AUT-03).
  Future<void> registrarConCorreo({
    required String correo,
    required String contrasena,
  });

  /// Recuperación de contraseña por correo (RF-AUT-05).
  Future<void> recuperarContrasena(String correo);

  /// Cierre de sesión explícito (RF-AUT-07).
  Future<void> salir();
}

abstract interface class RepositorioBandeja {
  /// Historial de mensajes recibidos por un catedrático (RF-ENT-12).
  Stream<List<MensajeRecibido>> observarHistorial(String uid);
}

/// Una entrega, ya combinada con los datos del mensaje que la originó.
///
/// Vive en el dominio y no en la infraestructura: es lo que la interfaz
/// necesita saber, con independencia de que venga de Firestore o de cualquier
/// otro proveedor.
class MensajeRecibido {
  const MensajeRecibido({
    required this.mensajeId,
    required this.titulo,
    required this.cuerpo,
    required this.tipo,
    required this.estado,
    required this.requiereConfirmacion,
    this.entregadoEn,
    this.abiertoEn,
    this.confirmadoEn,
    this.rutaVoz,
    this.duracionVozSeg,
    this.rutaImagen,
  });

  final String mensajeId;
  final String titulo;
  final String cuerpo;

  /// `INFORMATIVO` o `URGENTE` (RF-MSG-02).
  final String tipo;

  /// Estado de la entrega individual (documento 01, sección 10).
  final String estado;

  final bool requiereConfirmacion;
  final DateTime? entregadoEn;
  final DateTime? abiertoEn;
  final DateTime? confirmadoEn;

  /// Rutas en Cloud Storage de los adjuntos (RF-ENT-08, RF-ENT-09). Nulas si
  /// el aviso es solo de texto.
  final String? rutaVoz;
  final int? duracionVozSeg;
  final String? rutaImagen;

  bool get llevaVoz => rutaVoz != null;
  bool get llevaImagen => rutaImagen != null;
  bool get llevaAdjuntos => llevaVoz || llevaImagen;

  bool get esUrgente => tipo == 'URGENTE';
  bool get estaConfirmado => estado == 'CONFIRMADO';

  /// Urgente, exige confirmación y todavía no se ha confirmado: es sobre lo
  /// que la aplicación tiene que insistir (RF-CNF-10).
  bool get exigeAtencion =>
      esUrgente && requiereConfirmacion && !estaConfirmado;
}
