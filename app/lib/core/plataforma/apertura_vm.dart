/// Sustituto para la máquina virtual: pruebas y herramientas.
///
/// Fuera del navegador no hay dirección ni service worker. Las pruebas fijan
/// aquí los parámetros con los que «se abrió» la aplicación y empujan avisos
/// del worker a mano.
library;

/// Los parámetros de la dirección con la que arrancó la aplicación.
Map<String, String> parametrosDePrueba = <String, String>{};

/// Cuántas veces se pidió limpiar la dirección.
int vecesQueSeLimpio = 0;

void Function(Map<String, String>)? _oyente;

Map<String, String> parametrosDeApertura() =>
    Map<String, String>.of(parametrosDePrueba);

void limpiarParametrosDeApertura() {
  vecesQueSeLimpio += 1;
  parametrosDePrueba = <String, String>{};
}

void escucharAperturas(void Function(Map<String, String>) alAbrir) {
  _oyente = alAbrir;
}

/// Simula que el worker avisa de que se tocó una notificación.
void simularAperturaDesdeElWorker(Map<String, String> datos) =>
    _oyente?.call(datos);
