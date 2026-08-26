/// Implementación para la máquina virtual: pruebas y herramientas.
///
/// Declara que **no** soporta grabar, en vez de fingir que sí. Una grabadora
/// que dijera «puedo» y devolviera silencio dejaría la interfaz mostrando un
/// botón de grabar que no graba, que es peor que no ofrecerlo.
library;

import 'grabacion.dart';

Grabadora crearGrabadora() => _GrabadoraNula();

class _GrabadoraNula implements Grabadora {
  @override
  bool get soportada => false;

  @override
  bool get grabando => false;

  @override
  int get segundos => 0;

  @override
  Future<FalloGrabacion?> iniciar() async => FalloGrabacion.sinSoporte;

  @override
  Future<Grabacion?> detener() async => null;

  @override
  Future<void> cancelar() async {}

  @override
  void liberar() {}
}
