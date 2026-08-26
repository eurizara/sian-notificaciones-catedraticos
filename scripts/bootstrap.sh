#!/usr/bin/env bash
#
# SIAN — Prepara el entorno local completo (documento 06, etapas A y D).
#
# No instala herramientas del sistema: comprueba que estén y te dice cuáles
# faltan. Instalar cosas en la máquina de alguien sin avisar es mala educación.
#
# Uso:  bash scripts/bootstrap.sh

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

FALTA=0

verificar() {
  local comando="$1" nombre="$2" requerido="$3" obligatorio="$4"
  if command -v "$comando" >/dev/null 2>&1; then
    printf '  ✓ %-14s %s\n' "$nombre" "$($comando --version 2>&1 | head -1)"
  else
    printf '  ✗ %-14s no encontrado (se requiere %s)\n' "$nombre" "$requerido"
    [ "$obligatorio" = "si" ] && FALTA=1
  fi
}

echo "Herramientas (documento 06, etapa A.1)"
verificar git "Git" "2.40+" si
verificar node "Node.js" "20 LTS" si
verificar java "Java JDK" "17" si
verificar flutter "Flutter" "3.24+" no

echo
echo "Java, en detalle — los emuladores no arrancan sin él"
java -version 2>&1 | head -1 | sed 's/^/  /' || true

if [ "$FALTA" -ne 0 ]; then
  echo
  echo "Faltan herramientas obligatorias. Instálalas siguiendo el documento 06, etapa A.2."
  exit 1
fi

echo
echo "Dependencias"
echo "  → raíz"
npm install --silent
echo "  → functions"
npm install --silent --prefix functions

if [ ! -f .env.local ]; then
  echo
  echo "  → creando .env.local a partir de .env.example"
  cp .env.example .env.local
  echo "    Rellena FIREBASE_VAPID_KEY y FIREBASE_PROJECT_ID antes de desplegar."
fi

if [ ! -f .firebaserc ]; then
  echo "  → creando .firebaserc a partir de .firebaserc.example"
  cp .firebaserc.example .firebaserc
  echo "    Sustituye los marcadores por tus IDs reales, o usa 'npx firebase use --add'."
fi

echo
echo "  → generando app/lib/firebase_options.dart"
bash "$RAIZ/scripts/generar-firebase-options.sh"

echo
echo "Verificación rápida"
npm run lint --prefix functions --silent && echo "  ✓ analizador estático"
npm test --prefix functions --silent >/dev/null && echo "  ✓ pruebas unitarias"

cat <<'FIN'

Listo. Siguientes pasos (documento 06, etapa D):

  npm run emu          Levanta los emuladores en http://localhost:4000
  npm run seed:dev     Siembra datos de prueba (con los emuladores corriendo)
  npm run verificar    Analizador, compilación, cobertura y reglas de seguridad

Recuerda: los emuladores NO envían notificaciones push reales. La llegada de la
notificación al dispositivo solo se verifica desplegando a `dev` (etapa D.5).
FIN
