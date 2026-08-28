/// Sustituto para la máquina virtual: pruebas y herramientas.
///
/// Devuelve siempre el mismo valor dentro de un proceso, que es justo lo que
/// una prueba necesita comprobar: que el identificador no cambia entre
/// llamadas.
library;

String? _recordado;

String identificadorDeInstalacion() =>
    _recordado ??= 'instalacion-de-pruebas';

/// Solo para las pruebas, que comparten proceso.
void olvidarIdentificadorDeInstalacion() => _recordado = null;
