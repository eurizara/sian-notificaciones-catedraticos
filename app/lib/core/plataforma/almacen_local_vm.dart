/// Sustituto para la máquina virtual: guarda en memoria.
library;

/// Visible para que las pruebas puedan sembrarlo y comprobarlo.
final Map<String, String> almacenLocalDePrueba = <String, String>{};

String? leerLocal(String clave) => almacenLocalDePrueba[clave];

void guardarLocal(String clave, String valor) {
  almacenLocalDePrueba[clave] = valor;
}
