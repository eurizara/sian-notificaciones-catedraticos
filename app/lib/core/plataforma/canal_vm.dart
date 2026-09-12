/// Sustituto para la máquina virtual: no hay worker a quien hablarle.
library;

/// Lo último que se le dijo al worker, para que las pruebas lo comprueben.
({String uid, String instalacionId})? ultimaIdentidadEnviada;

/// Si se pidió la revisión periódica.
bool sePidioRevisionPeriodica = false;

Future<void> avisarIdentidadAlWorker({
  required String uid,
  required String instalacionId,
}) async {
  ultimaIdentidadEnviada = (uid: uid, instalacionId: instalacionId);
}

Future<void> pedirRevisionPeriodicaDelCanal() async {
  sePidioRevisionPeriodica = true;
}
