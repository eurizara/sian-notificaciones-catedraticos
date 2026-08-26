#!/usr/bin/env bash
#
# SIAN — Aplica la configuración CORS del bucket de Cloud Storage.
#
# ─────────────────────────────────────────────────────────────────────────────
# Sin esto, las imágenes adjuntas NO se ven. Y el fallo despista.
# ─────────────────────────────────────────────────────────────────────────────
#
# Flutter web descarga los bytes de una imagen con `fetch` para decodificarla,
# y el navegador bloquea esa descarga si el bucket no declara CORS. La nota de
# voz, en cambio, se reproduce con un elemento `<audio>`, que no pide permiso
# de origen.
#
# Resultado: la voz funciona, la imagen no, y parece un problema de la imagen
# o de la conexión. No lo es: es una cabecera que falta en el bucket.
#
# Esto NO lo despliega `firebase deploy`: la configuración vive en el bucket,
# no en `storage.rules`. Hay que aplicarla una vez por ambiente.
#
# Uso:
#   bash scripts/aplicar-cors-storage.sh sian-umg-bdm-dev
#
# Requiere `gcloud` autenticado, o `gsutil`:
#   gcloud storage buckets update gs://<bucket> --cors-file=storage.cors.json

set -euo pipefail

PROYECTO="${1:-sian-umg-bdm-dev}"
BUCKET="${2:-${PROYECTO}.firebasestorage.app}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Aplicando CORS a gs://${BUCKET}"

if command -v gcloud >/dev/null 2>&1; then
  gcloud storage buckets update "gs://${BUCKET}" \
    --cors-file="${RAIZ}/storage.cors.json" --project="${PROYECTO}"
elif command -v gsutil >/dev/null 2>&1; then
  gsutil cors set "${RAIZ}/storage.cors.json" "gs://${BUCKET}"
else
  echo "error: hace falta gcloud o gsutil." >&2
  echo "       Alternativa: consola de Google Cloud → Cloud Storage →" >&2
  echo "       el bucket → Configuración → CORS." >&2
  exit 1
fi

echo "Listo. Comprueba con:"
echo "  curl -sI -H 'Origin: https://${PROYECTO}.web.app' '<url-de-descarga>' | grep -i access-control"
