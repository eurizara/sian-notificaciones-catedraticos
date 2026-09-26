/// Sustituto para la máquina virtual: deja constancia de lo que se guardó.
library;

/// Los bytes de una imagen ya descargada, listos para guardarse.
class ImagenPreparada {
  const ImagenPreparada(this.url, this.nombre);
  final String url;
  final String nombre;
}

final List<({String nombre, bool compartir})> imagenesGuardadas =
    <({String nombre, bool compartir})>[];

Future<ImagenPreparada?> prepararImagen(String url, String nombre) async =>
    ImagenPreparada(url, nombre);

Future<bool> guardarImagen(
  ImagenPreparada imagen, {
  required bool compartir,
}) async {
  imagenesGuardadas.add((nombre: imagen.nombre, compartir: compartir));
  return true;
}
