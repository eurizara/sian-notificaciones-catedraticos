/// Sustituto para la máquina virtual: no hay servidor a quien preguntar.
library;

/// Lo que devolverá la consulta, para que las pruebas puedan fijarlo.
String? versionPublicadaDePrueba;

Future<String?> consultarVersionPublicada() async => versionPublicadaDePrueba;
