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
const String versionSian = '1.5.1';
