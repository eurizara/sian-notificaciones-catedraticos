/// Sustituto para la máquina virtual: pruebas y herramientas.
///
/// Fuera del navegador no hay service workers que actualizar. Se deja
/// constancia de que se pidió, que es lo que una prueba puede comprobar.
library;

int vecesQueSePidioActualizar = 0;

void actualizarWorkers() {
  vecesQueSePidioActualizar += 1;
}
