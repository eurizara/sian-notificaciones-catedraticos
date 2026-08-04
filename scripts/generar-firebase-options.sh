#!/usr/bin/env bash
#
# SIAN — Genera app/lib/firebase_options.dart sin interacción.
#
# `flutterfire configure` hace lo mismo, pero es interactivo y exige estar
# autenticado contra el proyecto. Este script cubre los dos casos donde eso no
# sirve:
#
#   · La integración continua, que solo necesita que el código COMPILE. Sin
#     valores reales genera marcadores de posición: el análisis y las pruebas
#     pasan, y la aplicación no podría conectarse a nada, que es exactamente lo
#     que se quiere en un runner.
#
#   · Quien replique el proyecto siguiendo solo la documentación (RNF-20).
#
# El archivo generado está en .gitignore: contiene los identificadores de UN
# proyecto concreto (documento 06, etapa C.5).
#
# Los valores de una app web de Firebase son públicos por diseño —viajan al
# navegador dentro del paquete compilado—, así que no son credenciales
# secretas. Lo que protege los datos son las reglas de seguridad y los custom
# claims (documento 05, sección 5).
#
# Uso:
#   bash scripts/generar-firebase-options.sh              # lee .env.local
#   FIREBASE_API_KEY=... bash scripts/generar-firebase-options.sh
#
# Para obtener los valores de un proyecto:
#   firebase apps:sdkconfig WEB <appId> --project <proyecto>

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINO="$RAIZ/app/lib/firebase_options.dart"

# Si existe .env.local y no vienen valores por el entorno, se usan los de ahí.
if [ -f "$RAIZ/.env.local" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$RAIZ/.env.local"
  set +a
fi

SIN_CONFIGURAR='SIN-CONFIGURAR'

API_KEY="${FIREBASE_API_KEY:-$SIN_CONFIGURAR}"
APP_ID="${FIREBASE_APP_ID:-$SIN_CONFIGURAR}"
SENDER_ID="${FIREBASE_MESSAGING_SENDER_ID:-$SIN_CONFIGURAR}"
PROJECT_ID="${FIREBASE_PROJECT_ID:-$SIN_CONFIGURAR}"
AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN:-$SIN_CONFIGURAR}"
STORAGE_BUCKET="${FIREBASE_STORAGE_BUCKET:-$SIN_CONFIGURAR}"

if [ "$API_KEY" = "$SIN_CONFIGURAR" ]; then
  echo "aviso: sin valores de Firebase; se generan marcadores de posición." >&2
  echo "       El código compilará, pero la aplicación no podrá conectarse." >&2
  echo "       Rellena .env.local siguiendo el documento 06, etapa C.5." >&2
fi

mkdir -p "$(dirname "$DESTINO")"

cat > "$DESTINO" <<DART
// GENERADO por scripts/generar-firebase-options.sh — no editar a mano.
//
// Equivalente a la salida de \`flutterfire configure --platforms=web\`.
// Está en .gitignore: contiene los identificadores de un proyecto concreto, y
// cada persona que replique el sistema genera el suyo (documento 06, C.5).
//
// Los valores de una app web de Firebase son públicos por diseño: viajan al
// navegador dentro del paquete compilado. No son credenciales secretas. Lo que
// protege los datos son las reglas de seguridad y los custom claims.

// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;

/// Opciones de Firebase por plataforma.
///
/// Solo se declara web: SIAN se distribuye exclusivamente como PWA, sin
/// tiendas de aplicaciones (ADR-003, RES-01). Android e iOS nativos solo
/// aparecerían si se activara el plan de contingencia del documento 02,
/// sección 11.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'SIAN se distribuye únicamente como PWA (ADR-003). '
      'No hay configuración para \$defaultTargetPlatform. '
      'Si esto cambia, revisa antes el plan de contingencia del documento 02, '
      'sección 11.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '$API_KEY',
    appId: '$APP_ID',
    messagingSenderId: '$SENDER_ID',
    projectId: '$PROJECT_ID',
    authDomain: '$AUTH_DOMAIN',
    storageBucket: '$STORAGE_BUCKET',
  );
}
DART

# El service worker de mensajería no puede leer el archivo de Dart: corre
# fuera de la aplicación. Se le deja la misma configuración en un archivo
# aparte que él importa (documento 02, riesgo R-03).
CONFIG_SW="$RAIZ/app/web/firebase-config.js"
cat > "$CONFIG_SW" <<JS
// GENERADO por scripts/generar-firebase-options.sh — no editar a mano.
// Lo consume firebase-messaging-sw.js, que corre fuera de la aplicación y no
// puede leer el archivo de Dart. Está en .gitignore por la misma razón.
self.SIAN_FIREBASE_CONFIG = {
  apiKey: '$API_KEY',
  appId: '$APP_ID',
  messagingSenderId: '$SENDER_ID',
  projectId: '$PROJECT_ID',
  authDomain: '$AUTH_DOMAIN',
  storageBucket: '$STORAGE_BUCKET',
};
JS

echo "Generado: app/lib/firebase_options.dart  (proyecto: $PROJECT_ID)"
echo "Generado: app/web/firebase-config.js"
