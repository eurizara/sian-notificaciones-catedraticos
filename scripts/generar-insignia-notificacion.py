"""Genera la insignia de las notificaciones: una campana blanca sobre transparente.

────────────────────────────────────────────────────────────────────────────────
Por qué no sirve el icono de la aplicación
────────────────────────────────────────────────────────────────────────────────

Android dibuja el icono pequeño de una notificación —el de la barra de estado y
el de la cabecera— usando **solo el canal alfa**: lo que es opaco se pinta del
color del sistema y lo transparente se deja ver. Es una silueta, no una imagen.

Los iconos de SIAN son opacos de borde a borde (0 % de píxeles transparentes,
medido el 12 de septiembre de 2026), así que Android los convertía en un
cuadrado blanco macizo. Es el cuadro que se ve junto a «Chrome» en la
notificación y junto a la hora en la barra de estado.

La insignia tiene que ser una forma simple: a 24 puntos de alto, el escudo de la
universidad se reduce a una mancha. Una campana se lee a ese tamaño y dice lo
que es.

────────────────────────────────────────────────────────────────────────────────
Uso
────────────────────────────────────────────────────────────────────────────────

    python3 scripts/generar-insignia-notificacion.py

Escribe `app/web/icons/insignia-notificacion.png`. El nombre NO empieza por
`Icon-` a propósito: `tenir-iconos-ambiente.py` marca con la inicial del ambiente
todo lo que empieza así, y una marca de color sobre una silueta la estropearía.
"""

from pathlib import Path

from PIL import Image, ImageDraw

LADO = 96          # 24 dp a densidad xxxhdpi, la mayor que usa Android.
ESCALA = 8         # Se dibuja grande y se reduce: bordes suaves sin trucos.
BLANCO = (255, 255, 255, 255)


def campana(lado: int) -> Image.Image:
    g = lado * ESCALA
    img = Image.new('RGBA', (g, g), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def p(x: float, y: float) -> tuple[int, int]:
        return (round(x * g), round(y * g))

    # Cuerpo: cúpula redonda arriba, faldón que se abre abajo.
    d.pieslice([p(0.24, 0.16), p(0.76, 0.68)], 180, 360, fill=BLANCO)
    d.polygon([p(0.24, 0.42), p(0.76, 0.42), p(0.86, 0.72), p(0.14, 0.72)], fill=BLANCO)
    # Borde inferior.
    d.rounded_rectangle([p(0.10, 0.68), p(0.90, 0.78)], radius=round(0.05 * g), fill=BLANCO)
    # Asa superior.
    d.ellipse([p(0.44, 0.08), p(0.56, 0.20)], fill=BLANCO)
    # Badajo.
    d.ellipse([p(0.40, 0.78), p(0.60, 0.94)], fill=BLANCO)

    return img.resize((lado, lado), Image.LANCZOS)


def main() -> None:
    destino = Path(__file__).resolve().parent.parent / 'app' / 'web' / 'icons'
    ruta = destino / 'insignia-notificacion.png'
    campana(LADO).save(ruta, optimize=True)

    alfa = Image.open(ruta).getchannel('A')
    transparentes = sum(1 for a in alfa.getdata() if a < 16) / (LADO * LADO)
    print(f'{ruta.name}: {LADO}x{LADO}, {transparentes:.0%} transparente')


if __name__ == '__main__':
    main()
