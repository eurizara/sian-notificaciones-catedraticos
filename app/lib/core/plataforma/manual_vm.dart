/// Sustituto para la máquina virtual: no hay navegador donde abrir nada.
library;

/// Última ruta pedida, para que las pruebas puedan comprobarla.
String? ultimoManualAbierto;

void abrirManual(String ruta) {
  ultimoManualAbierto = ruta;
}
