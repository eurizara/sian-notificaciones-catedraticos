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
    this.emisor = '',
    this.entregadoEn,
    this.abiertoEn,
    this.confirmadoEn,
    this.adjuntos = const <AdjuntoRecibido>[],
  });

  final String mensajeId;
  final String titulo;
  final String cuerpo;

  /// `INFORMATIVO` o `URGENTE` (RF-MSG-02).
  final String tipo;

  /// Estado de la entrega individual (documento 01, sección 10).
  final String estado;

  final bool requiereConfirmacion;

  /// Quién lo envió, por su nombre.
  ///
  /// Viene desnormalizado en el mensaje porque el receptor no puede leer
  /// `usuarios`: sin esto habría que enseñar un identificador aleatorio, que
  /// es peor que no enseñar nada porque parece un dato.
  ///
  /// Vacío en los mensajes anteriores a que esto se guardara. Se muestra lo
  /// que hay: inventar un «Sistema» donde no consta quién firmó sería peor.
  final String emisor;

  final DateTime? entregadoEn;
  final DateTime? abiertoEn;
  final DateTime? confirmadoEn;

  /// Los adjuntos (RF-ENT-08, RF-ENT-09), **en el orden en que se adjuntaron**.
  ///
  /// ──────────────────────────────────────────────────────────────────────────
  /// Una lista, no un hueco para la voz y otro para la imagen.
  /// ──────────────────────────────────────────────────────────────────────────
  ///
  /// El orden lo eligió quien redactó y significa algo: un plano, después la
  /// nota de voz que lo explica, después la foto del punto de reunión.
  /// Separarlos por tipo obligaría a inventar un orden al mostrarlos.
  final List<AdjuntoRecibido> adjuntos;

  bool get llevaVoz => adjuntos.any((AdjuntoRecibido a) => a.esVoz);
  bool get llevaImagen => adjuntos.any((AdjuntoRecibido a) => !a.esVoz);
  bool get llevaAdjuntos => adjuntos.isNotEmpty;

  bool get esUrgente => tipo == 'URGENTE';
  bool get estaConfirmado => estado == 'CONFIRMADO';

  /// Urgente, exige confirmación y todavía no se ha confirmado: es sobre lo
  /// que la aplicación tiene que insistir (RF-CNF-10).
  bool get exigeAtencion =>
      esUrgente && requiereConfirmacion && !estaConfirmado;
}

/// Un adjunto tal como llega al receptor.
class AdjuntoRecibido {
  const AdjuntoRecibido({
    required this.tipo,
    required this.ruta,
    this.duracionSeg,
  });

  /// `AUDIO` o `IMAGEN`.
  final String tipo;

  /// Ruta en Cloud Storage. La URL se pide al mostrar, no se guarda: las de
  /// Storage caducan, y una guardada dejaría de funcionar sin decir por qué.
  final String ruta;

  /// Solo para audio.
  final int? duracionSeg;

  bool get esVoz => tipo == 'AUDIO';
}
