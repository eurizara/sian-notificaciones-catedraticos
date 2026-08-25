#!/usr/bin/env python3
"""SIAN — Genera el juego completo de iconos a partir del escudo institucional.

Se ejecuta a mano cuando cambia el escudo, y su salida se versiona. No corre en
la integración continua: un icono es una decisión de diseño, no un artefacto de
compilación, y regenerarlo en cada rama produciría diferencias de un byte que
nadie sabe leer.

    python3 scripts/generar-iconos.py

─────────────────────────────────────────────────────────────────────────────
Por qué el icono pequeño NO es el escudo
─────────────────────────────────────────────────────────────────────────────

El escudo de la Universidad Mariano Gálvez es un anillo con el nombre completo
rodeando una figura. Es magnífico impreso y a 512 px. A 16 px —el tamaño de la
pestaña del navegador— el anillo de texto se convierte en un cerco de píxeles
sueltos y la figura en una mancha: lo que queda es «un círculo rojo con algo
adentro», indistinguible de cualquier otro sello.

Así que por debajo de 64 px se usa una marca reducida: el anillo rojo y el
campo azul del propio escudo, con la inicial del sistema. No es un logotipo
nuevo ni compite con el escudo; es el escudo dicho en la única cantidad de
píxeles disponible. De 180 px en adelante vuelve el escudo completo, que a ese
tamaño se lee entero.

─────────────────────────────────────────────────────────────────────────────
Por qué los iconos «maskable» llevan tanto margen
─────────────────────────────────────────────────────────────────────────────

Android no respeta la forma del icono: le aplica la máscara del sistema
—círculo, cuadrado redondeado, gota— y recorta **hasta un 20 % por lado**. La
especificación pide que todo lo que importe viva dentro del 80 % central.

Los iconos anteriores tenían 0 % de margen: el escudo llegaba al borde exacto
del lienzo, así que en cualquier teléfono con máscara circular el anillo con
«UNIVERSIDAD MARIANO GÁLVEZ» quedaba cortado por los cuatro costados. Aquí el
escudo ocupa el 60 % del lienzo, con lo que sobrevive entero a la máscara más
agresiva.

El fondo va blanco y opaco, nunca transparente: iOS rellena de negro la
transparencia del icono de pantalla de inicio.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
ESCUDO = RAIZ / "app" / "assets" / "escudo-umg.png"
ICONOS = RAIZ / "app" / "web" / "icons"

# Muestreados del escudo, los mismos que declara app/lib/presentation/shared/tema.dart
ROJO = (203, 51, 50, 255)
AZUL = (28, 114, 165, 255)
BLANCO = (255, 255, 255, 255)

# Por encima de este tamaño el escudo completo se lee; por debajo, no.
UMBRAL_ESCUDO = 64

# Cuánto del lienzo ocupa el escudo en un icono maskable.
FRACCION_MASKABLE = 0.60

TIPOGRAFIAS = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]


def _fuente(px: int) -> ImageFont.FreeTypeFont:
    for ruta in TIPOGRAFIAS:
        try:
            return ImageFont.truetype(ruta, px)
        except OSError:
            continue
    return ImageFont.load_default()


def marca_reducida(lado: int) -> Image.Image:
    """Anillo rojo, campo azul e inicial. Se dibuja a 8× y se reduce.

    Dibujar directamente a 16 px daría bordes dentados: PIL no antialiasa las
    elipses. Reducir desde 8× sí produce un borde limpio.
    """
    f = 8
    g = Image.new("RGBA", (lado * f, lado * f), (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    borde = lado * f - 1
    d.ellipse([0, 0, borde, borde], fill=ROJO)
    grosor = int(lado * f * 0.13)
    d.ellipse([grosor, grosor, borde - grosor, borde - grosor], fill=AZUL)

    fuente = _fuente(int(lado * f * 0.62))
    caja = d.textbbox((0, 0), "S", font=fuente)
    d.text(
        ((lado * f - caja[2] + caja[0]) // 2 - caja[0],
         (lado * f - caja[3] + caja[1]) // 2 - caja[1]),
        "S",
        font=fuente,
        fill=BLANCO,
    )
    return g.resize((lado, lado), Image.LANCZOS)


def sobre_blanco(im: Image.Image, lado: int, fraccion: float) -> Image.Image:
    """Centra `im` ocupando `fraccion` del lienzo, sobre blanco opaco."""
    lienzo = Image.new("RGBA", (lado, lado), BLANCO)
    dentro = max(1, int(lado * fraccion))
    pieza = im.resize((dentro, dentro), Image.LANCZOS)
    desplazamiento = (lado - dentro) // 2
    lienzo.paste(pieza, (desplazamiento, desplazamiento), pieza)
    return lienzo


def main() -> None:
    escudo = Image.open(ESCUDO).convert("RGBA")
    ICONOS.mkdir(parents=True, exist_ok=True)

    # Iconos normales. El escudo lleva un 6 % de aire para no tocar el borde.
    for lado in (16, 48, 180, 192, 512):
        if lado < UMBRAL_ESCUDO:
            icono = sobre_blanco(marca_reducida(lado), lado, 1.0)
        else:
            icono = sobre_blanco(escudo, lado, 0.88)
        icono.save(ICONOS / f"Icon-{lado}.png")
        print(f"  Icon-{lado}.png")

    # Maskable: mucho margen, porque Android recorta hasta el 20 % por lado.
    for lado in (192, 512):
        sobre_blanco(escudo, lado, FRACCION_MASKABLE).save(
            ICONOS / f"Icon-maskable-{lado}.png"
        )
        print(f"  Icon-maskable-{lado}.png")

    # Favicon: la marca reducida, que es la que se lee en una pestaña.
    web = RAIZ / "app" / "web"
    sobre_blanco(marca_reducida(32), 32, 1.0).save(web / "favicon.png")
    print("  favicon.png")

    marca_reducida(64).save(
        web / "favicon.ico",
        format="ICO",
        sizes=[(16, 16), (32, 32), (48, 48)],
    )
    print("  favicon.ico  (16, 32 y 48 px)")


if __name__ == "__main__":
    main()
