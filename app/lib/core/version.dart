/// SIAN — La versión de la aplicación.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Qué significa cada número
/// ────────────────────────────────────────────────────────────────────────────
///
///     MAYOR . MENOR . PARCHE
///       │       │       └── sube con cada cambio liberado dentro de la
///       │       │           iteración: una corrección, un ajuste, un arreglo
///       │       └────────── la ITERACIÓN del plan (documento 08). La 1.5 es la
///       │                   de septiembre de 2026: correcciones C-1 a C-5 y
///       │                   mejoras M-1 a M-5
///       └────────────────── cambia cuando cambia el sistema, no una pantalla
///
/// Se eligió atarlo a la iteración y no a una fecha por una razón práctica: en
/// este proyecto todo lo que se libera está descrito en el documento 08, y así
/// «1.5.2» se puede buscar ahí y leer qué trae. Una versión con la fecha diría
/// cuándo salió, que es justo lo que ya dice `desplegadoEn` en `version.json`.
///
/// ────────────────────────────────────────────────────────────────────────────
/// Este archivo es la ÚNICA fuente
/// ────────────────────────────────────────────────────────────────────────────
///
/// `pubspec.yaml` tiene que decir lo mismo, y hay una prueba que falla si se
/// separan. El sellado del despliegue (`scripts/sellar-version.sh`) lee de aquí
/// para escribirlo en `version.json`, que es lo que el navegador consulta para
/// saber si lo que tiene cargado es lo último publicado.
///
/// Al subir la versión: cambiar el número aquí, en `pubspec.yaml`, y anotar en
/// el documento 08 qué trae.
library;

/// La versión de este código. Ver arriba qué significa cada número.
const String versionSian = '1.5.9';

/// Desde qué versión el aparato sabe avisar de que mostró una notificación.
///
/// El acuse lo manda el service worker, que viaja con la aplicación: un
/// teléfono que todavía no ha recargado no puede acusar aunque enseñe la
/// notificación perfectamente. De esos no se afirma nada (DT-31).
const String versionQueSabeAcusar = '1.5.0';

/// Compara por tramos numéricos: «1.10.0» es posterior a «1.9.0», y comparadas
/// como texto saldrían al revés.
bool sabeAcusar(String? version) {
  final List<int?> tramos = (version ?? '')
      .trim()
      .split('.')
      .map(int.tryParse)
      .toList();
  if (tramos.length != 3 || tramos.any((int? t) => t == null)) {
    return false;
  }
  final List<int> minimo = versionQueSabeAcusar
      .split('.')
      .map(int.parse)
      .toList();
  for (int i = 0; i < 3; i += 1) {
    if (tramos[i]! != minimo[i]) {
      return tramos[i]! > minimo[i];
    }
  }
  return true;
}
