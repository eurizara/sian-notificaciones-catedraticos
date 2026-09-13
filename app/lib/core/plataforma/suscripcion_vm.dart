/// Sustituto para la máquina virtual: no hay navegador al que suscribir.
library;

/// Lo que devolverá la suscripción, para que las pruebas lo fijen.
Map<String, String>? suscripcionDePrueba;

Future<Map<String, String>?> suscribirConLlavePropia(String clavePublica) async =>
    suscripcionDePrueba;
