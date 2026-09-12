/// Sustituto para la máquina virtual: no hay navegador donde abrir nada.
library;

/// Última ruta pedida, para que las pruebas puedan comprobarla.
String? ultimoManualAbierto;

void abrirManual(String ruta) {
  ultimoManualAbierto = ruta;
}

/// Las pruebas se comportan como el navegador, que es el caso por omisión.
bool manualSeAbreEnOtraPestana() => true;
