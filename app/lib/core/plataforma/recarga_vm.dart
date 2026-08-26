/// Sustituto para la máquina virtual: pruebas y herramientas.
///
/// No recarga nada porque fuera del navegador no hay nada que recargar. Se
/// deja constancia de que se pidió, que es lo que una prueba puede comprobar.
library;

int vecesQueSeRecargo = 0;

void recargarAplicacion() {
  vecesQueSeRecargo += 1;
}
