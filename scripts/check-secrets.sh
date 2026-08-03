#!/usr/bin/env bash
#
# SIAN — Búsqueda de secretos filtrados (RNF-10, RES-10).
#
# El repositorio es público. Una clave que entre al historial de git sigue ahí
# aunque se borre del archivo en el commit siguiente, así que esto se ejecuta
# antes de cada push y en la integración continua.
#
# Uso:  bash scripts/check-secrets.sh

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

HALLAZGOS=0

echo "→ Archivos que jamás deben estar versionados"
PROHIBIDOS=(
  ".env"
  ".env.local"
  ".firebaserc"
  "serviceAccountKey.json"
  "google-services.json"
  "GoogleService-Info.plist"
  "app/lib/firebase_options.dart"
)
for archivo in "${PROHIBIDOS[@]}"; do
  if git ls-files --error-unmatch "$archivo" >/dev/null 2>&1; then
    echo "  ✗ $archivo ESTÁ versionado"
    HALLAZGOS=1
  fi
done
[ "$HALLAZGOS" -eq 0 ] && echo "  ✓ ninguno versionado"

echo "→ Patrones de credencial en los archivos versionados"
# AIza…  = clave de API de Google
# -----BEGIN … PRIVATE KEY = clave privada de cuenta de servicio
if git grep -nIE "AIza[0-9A-Za-z_-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|\"private_key\"[[:space:]]*:" \
    -- . ':(exclude)scripts/check-secrets.sh' ':(exclude).github/workflows/*'; then
  echo "  ✗ patrón de credencial encontrado en el árbol de trabajo"
  HALLAZGOS=1
else
  echo "  ✓ sin patrones evidentes"
fi

echo "→ Patrones de credencial en el historial completo"
if git log -p --all 2>/dev/null \
    | grep -aE "AIza[0-9A-Za-z_-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----" \
    | head -5 | grep -q .; then
  echo "  ✗ hay rastro de credenciales en el historial: reescribirlo y ROTAR las claves"
  HALLAZGOS=1
else
  echo "  ✓ historial limpio"
fi

if [ "$HALLAZGOS" -ne 0 ]; then
  echo
  echo "SE ENCONTRARON POSIBLES SECRETOS. No hagas push hasta resolverlo."
  echo "Recuerda: borrar el archivo no basta; hay que rotar la credencial expuesta."
  exit 1
fi

echo
echo "Sin secretos aparentes."
