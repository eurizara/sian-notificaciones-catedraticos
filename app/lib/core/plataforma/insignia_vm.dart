/// Sustituto para la máquina virtual: pruebas y herramientas.
///
/// No hay icono de aplicación fuera del navegador, así que no hay dónde pintar
/// la insignia. Se guarda lo último que se pidió, que es lo que una prueba
/// puede comprobar.
library;

/// Último valor pedido. `null` significa «insignia retirada».
int? insigniaPedida;

/// Cuántas veces se pidió, para distinguir «se pidió cero» de «no se pidió».
int vecesQueSePidioInsignia = 0;

bool get insigniaSoportada => false;

void fijarInsignia(int cuenta) {
  insigniaPedida = cuenta;
  vecesQueSePidioInsignia += 1;
}

void retirarInsignia() {
  insigniaPedida = null;
  vecesQueSePidioInsignia += 1;
}
