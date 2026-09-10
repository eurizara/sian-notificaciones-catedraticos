#!/usr/bin/env python3
"""SIAN — Marca los iconos de desarrollo y calidad para no confundirlos (DT-20).

    python3 scripts/tenir-iconos-ambiente.py app/build/web dev

─────────────────────────────────────────────────────────────────────────────
La banda en pantalla solo se ve con la aplicación abierta.
─────────────────────────────────────────────────────────────────────────────

El aviso «NO ES PRODUCCIÓN» resuelve el caso de estar dentro. Pero en la pantalla
de inicio, quien tiene los tres instalados ve tres iconos idénticos, y elige uno
antes de que ninguna banda pueda avisarle. El error —abrir producción creyendo
que es la de pruebas— se comete ahí, un segundo antes de que la aplicación
arranque.

Así que el icono también tiene que decirlo.

─────────────────────────────────────────────────────────────────────────────
PRODUCCIÓN NO SE TOCA. Nunca.
─────────────────────────────────────────────────────────────────────────────

Este script se ejecuta solo para desarrollo y calidad, y actúa sobre la CARPETA
YA COMPILADA, no sobre las fuentes. Los iconos versionados siguen siendo los
institucionales, intactos; lo que se marca es una copia que vive el tiempo que
dura un despliegue.

Dos motivos para hacerlo así y no generar tres juegos de iconos:

  · El escudo institucional no se modifica en el repositorio. Lo que se versiona
    es lo que la universidad aprobó.
  · Si mañana este script desaparece, producción sigue exactamente igual. El
    peor fallo posible de esta herramienta es no hacer nada.

─────────────────────────────────────────────────────────────────────────────
Cómo se marca, y por qué no con el rojo
─────────────────────────────────────────────────────────────────────────────

Una franja diagonal en la esquina inferior, en el dorado institucional #8A6A2B,
con la inicial del ambiente encima en blanco. El mismo dorado de la banda en
pantalla, para que las dos señales se lean como una sola cosa.

No se usa el rojo, y no es por gusto: el rojo institucional está reservado en
exclusiva a las alertas urgentes. Si además significara «ambiente de pruebas»,
dejaría de significar «urgente» — que es justo el color que tiene que conservar
todo su peso en una emergencia.

La franja va en diagonal y ocupa una esquina porque a 48 px, que es como se ve en
la pantalla de inicio, un detalle centrado se pierde contra el escudo y un borde
completo se confunde con el marco que dibuja el propio sistema.
"""

import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.exit(
        'error: hace falta Pillow.\n'
        '       pip3 install Pillow'
    )

# El mismo dorado de la banda en pantalla: 5.03:1 con blanco encima, que cumple
# AA para texto normal (RNF-13).
DORADO = (138, 106, 43, 255)
BLANCO = (255, 255, 255, 255)

# Qué letra lleva cada ambiente. Producción no está, y su ausencia es la
# protección: pedir un ambiente desconocido no hace nada.
INICIALES = {'dev': 'D', 'qa': 'Q'}


def fuente(tamano: int):
    """Una fuente que exista en la máquina, del tamaño pedido."""
    for ruta in (
        '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
        '/System/Library/Fonts/Helvetica.ttc',
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
        '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
    ):
        if Path(ruta).exists():
            try:
                return ImageFont.truetype(ruta, tamano)
            except OSError:
                continue
    # Sin fuente de sistema queda la de Pillow: más fea, pero legible, y mejor
    # que dejar el icono sin marcar.
    return ImageFont.load_default()


def marcar(ruta: Path, inicial: str) -> None:
    icono = Image.open(ruta).convert('RGBA')
    lado = icono.size[0]

    # La franja ocupa la esquina inferior derecha, en diagonal. Las medidas van
    # en proporción al lado para que el resultado se vea igual a 48 y a 512.
    alto = max(6, round(lado * 0.34))
    capa = Image.new('RGBA', icono.size, (0, 0, 0, 0))
    dibujo = ImageDraw.Draw(capa)
    dibujo.polygon(
        [
            (lado, lado - alto),
            (lado, lado),
            (lado - alto, lado),
        ],
        fill=DORADO,
    )

    # La letra solo cabe a partir de cierto tamaño. En 16 px la franja sola ya
    # distingue, y una letra ahí sería una mancha que ensucia sin informar.
    if lado >= 64:
        tipo = fuente(max(8, round(lado * 0.17)))
        caja = dibujo.textbbox((0, 0), inicial, font=tipo)
        ancho_texto = caja[2] - caja[0]
        alto_texto = caja[3] - caja[1]
        dibujo.text(
            (
                lado - alto * 0.42 - ancho_texto / 2 - caja[0],
                lado - alto * 0.36 - alto_texto / 2 - caja[1],
            ),
            inicial,
            font=tipo,
            fill=BLANCO,
        )

    Image.alpha_composite(icono, capa).save(ruta)


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(
            'uso: python3 scripts/tenir-iconos-ambiente.py <directorio> <ambiente>\n'
            '     ambiente: dev | qa   (producción no se marca)'
        )

    destino = Path(sys.argv[1])
    ambiente = sys.argv[2].strip().lower()

    if ambiente not in INICIALES:
        # No es un error: producción llega aquí y la respuesta correcta es no
        # hacer nada. Fallar detendría un despliegue por hacer lo que debe.
        print(f'Ambiente «{ambiente}»: los iconos no se marcan.')
        return

    carpeta = destino / 'icons'
    if not carpeta.is_dir():
        sys.exit(f'error: no existe {carpeta}. ¿Se compiló antes?')

    iconos = sorted(carpeta.glob('Icon-*.png'))
    if not iconos:
        sys.exit(f'error: no hay iconos en {carpeta}')

    for icono in iconos:
        marcar(icono, INICIALES[ambiente])

    print(f'Marcados {len(iconos)} iconos para «{ambiente}» con la inicial '
          f'«{INICIALES[ambiente]}».')


if __name__ == '__main__':
    main()
