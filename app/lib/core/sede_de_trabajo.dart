/// SIAN — La sede donde se trabaja en esta sesión (2.0 · RF-SED-04, ADR-009).
///
/// ────────────────────────────────────────────────────────────────────────────
/// Cada llamada al servidor dice en qué sede actúa.
/// ────────────────────────────────────────────────────────────────────────────
///
/// El servidor decide el permiso con el rol que la persona tiene EN esa sede,
/// y resuelve «todos» dentro de ella. Con una sola sede la elegiría solo; con
/// varias, una llamada sin sede se rechaza (`FALTA_SEDE`) en lugar de adivinar.
///
/// El valor lo fija `sedeDeTrabajoProvider` (la elegida en el selector, o la
/// principal), y los repositorios lo leen al momento de llamar con
/// [conSede]. Vive aquí, fuera de Riverpod, porque los repositorios no
/// dependen de él para construirse: así ninguno necesita cambiar cómo nace.
library;

abstract final class SedeDeTrabajo {
  static String? _actual;

  /// La sede de esta sesión, o `null` si no hay sesión.
  static String? get actual => _actual;

  static void fijar(String? sede) => _actual = sede;
}

/// Los datos de una llamada, con la sede de trabajo si la hay.
Map<String, Object?> conSede([
  Map<String, Object?> datos = const <String, Object?>{},
]) {
  final String? sede = SedeDeTrabajo.actual;
  return sede == null ? datos : <String, Object?>{...datos, 'sedeId': sede};
}

/// La sede de un documento. Sin `sedeId` es de antes de la 2.0: la inicial,
/// igual que `sedeDelDocumento` en el servidor.
String sedeDelDocumento(Map<String, dynamic>? datos) {
  final Object? s = datos?['sedeId'];
  return s is String && s.isNotEmpty ? s : 'bdm';
}
