/// Sustituto para la máquina virtual: deja constancia de lo que se pidió abrir.
library;

final List<Uri> enlacesAbiertos = <Uri>[];

void abrirEnlace(Uri destino) => enlacesAbiertos.add(destino);
