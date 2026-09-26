#!/usr/bin/env bash
#
# SIAN — Pone la huella de contenido en el nombre del paquete de la aplicación.
#
# ─────────────────────────────────────────────────────────────────────────────
# Sin huella, cada apertura descargaba 820 KB que casi nunca habían cambiado.
# ─────────────────────────────────────────────────────────────────────────────
#
# Flutter publica el código siempre como `main.dart.js`. Con el mismo nombre
# para contenidos distintos solo quedaban dos opciones: guardarlo en caché y
# arriesgarse a correr código viejo después de un despliegue (pasó con la
# fuente de iconos), o no guardarlo nunca. Se eligió no guardarlo, y medido el
# 25/09/2026 eso eran 820 KB comprimidos en CADA apertura, en cada iPhone.
#
# Con la huella en el nombre, el archivo puede guardarse un año: si el
# contenido cambia, cambia el nombre, y el arranque (`flutter_bootstrap.js`,
# que sigue sin caché) apunta al nuevo.
#
# Uso:  bash scripts/huella-paquete.sh <directorio-de-salida>
#
# Falla sin tocar nada si el arranque no tiene la forma esperada: una versión
# nueva de Flutter puede cambiarla, y publicar un arranque que apunta a un
# archivo que no existe dejaría la aplicación en blanco.

set -euo pipefail

DESTINO="${1:-app/build/web}"
PAQUETE="$DESTINO/main.dart.js"
ARRANQUE="$DESTINO/flutter_bootstrap.js"
BUSCADO='"mainJsPath":"main.dart.js"'

if [ ! -f "$PAQUETE" ] || [ ! -f "$ARRANQUE" ]; then
  echo "error: falta $PAQUETE o $ARRANQUE (¿se compiló?, ¿ya tenía huella?)" >&2
  exit 1
fi

VECES="$( (grep -o "$BUSCADO" "$ARRANQUE" || true) | wc -l | tr -d ' ')"
if [ "$VECES" != "1" ]; then
  echo "error: $ARRANQUE debería nombrar el paquete una vez con $BUSCADO y lo hace $VECES." >&2
  echo "       Flutter cambió el formato del arranque: revisar este guion." >&2
  exit 1
fi

HUELLA="$(shasum -a 256 "$PAQUETE" | cut -c1-12)"
NUEVO="main.$HUELLA.dart.js"

mv "$PAQUETE" "$DESTINO/$NUEVO"
# Mapa de fuentes, si lo hubiera: tiene que seguir al paquete.
if [ -f "$PAQUETE.map" ]; then
  mv "$PAQUETE.map" "$DESTINO/$NUEVO.map"
fi

TEMPORAL="$(mktemp)"
sed "s/\"mainJsPath\":\"main\.dart\.js\"/\"mainJsPath\":\"$NUEVO\"/" "$ARRANQUE" > "$TEMPORAL"
cat "$TEMPORAL" > "$ARRANQUE"
rm -f "$TEMPORAL"

if ! grep -q "\"mainJsPath\":\"$NUEVO\"" "$ARRANQUE"; then
  echo "error: el arranque no quedó apuntando a $NUEVO" >&2
  exit 1
fi

echo "Huella: $NUEVO ($(wc -c < "$DESTINO/$NUEVO" | tr -d ' ') bytes)"
