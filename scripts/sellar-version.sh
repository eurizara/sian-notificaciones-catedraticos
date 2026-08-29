#!/usr/bin/env bash
#
# SIAN — Sella la versión dentro de lo que se publica.
#
# ─────────────────────────────────────────────────────────────────────────────
# Sin esto no hay forma de saber qué código está corriendo en un ambiente.
# ─────────────────────────────────────────────────────────────────────────────
#
# El 29 de agosto de 2026 se perdió media tarde persiguiendo un fallo de
# notificaciones en desarrollo. La causa no estaba en el código: desarrollo
# llevaba desde el 28 a las 17:45 mientras QA y producción se habían actualizado
# esa misma noche a las 22:00. Las correcciones que se probaron en desarrollo
# **no eran** las que se promovieron.
#
# El día anterior se había comprobado que «los tres ambientes están iguales», y
# la comprobación lo dijo. Miraba la configuración a fondo —Functions activas,
# CORS, APIs, índices, alertas— y del código solo miraba si ciertas frases
# estaban presentes. Esas frases llevaban ahí desde antes, así que pasaban en
# los tres. La herramienta contestaba «¿tienen la función?» cuando la pregunta
# era «¿corren el mismo código?».
#
# Un identificador de commit no se puede confundir. O es el mismo, o no lo es.
#
# Uso:  bash scripts/sellar-version.sh <directorio-de-salida>
#
# Escribe <directorio>/version.json, que Hosting publica en /version.json.

set -euo pipefail

DESTINO="${1:-app/build/web}"

if [ ! -d "$DESTINO" ]; then
  echo "error: no existe el directorio $DESTINO" >&2
  echo "       compila antes de sellar (flutter build web)" >&2
  exit 1
fi

# En la integración continua el commit viene dado; en local se pregunta a git.
COMMIT="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo desconocido)}"
RAMA="${GITHUB_REF_NAME:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo desconocida)}"
CUANDO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# `limpio` distingue un despliegue reproducible de uno hecho desde una copia con
# cambios sin confirmar. Un ambiente sellado con `limpio: false` no se puede
# comparar con nada, y saberlo vale más que el propio identificador.
if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
  LIMPIO=true
else
  LIMPIO=false
fi

cat > "$DESTINO/version.json" <<JSON
{
  "commit": "$COMMIT",
  "rama": "$RAMA",
  "desplegadoEn": "$CUANDO",
  "limpio": $LIMPIO
}
JSON

echo "Sellado: $DESTINO/version.json  (${COMMIT:0:12}, rama $RAMA, limpio=$LIMPIO)"
