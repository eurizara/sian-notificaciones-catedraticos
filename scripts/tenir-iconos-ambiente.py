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

─────────────────────────────────────────────────────────────────────────────
Los iconos `maskable` llevan la marca en otro sitio, y no es un capricho
─────────────────────────────────────────────────────────────────────────────

Android usa los iconos declarados `purpose: maskable` para el icono del
lanzador, y **los recorta a la forma que el sistema elija** —círculo, cuadrado
redondeado, gota—. La zona que sobrevive con seguridad es el 80 % central; todo
lo de fuera puede desaparecer.

Una marca en la esquina cae exactamente en lo que se recorta. Comprobado el 10
de septiembre de 2026: en iOS el icono cambió y en Android no, porque iOS usa
`Icon-180.png`, que no es maskable, y Android usa el que sí lo es.

Así que en los maskable la marca es una **banda horizontal dentro del círculo
seguro**, no una esquina. Se ve peor, y da igual: un icono que no se distingue
no cumple ninguna función.
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


def _centrar_letra(dibujo, inicial, tipo, centro_x, centro_y) -> None:
    """Dibuja la inicial centrada de verdad en el punto dado.

    `textbbox` incluye el desplazamiento de la fuente, así que hay que restarlo:
    sin eso la letra queda visiblemente alta o baja según el tipo instalado.
    """
    caja = dibujo.textbbox((0, 0), inicial, font=tipo)
    dibujo.text(
        (
            centro_x - (caja[2] - caja[0]) / 2 - caja[0],
            centro_y - (caja[3] - caja[1]) / 2 - caja[1],
        ),
        inicial,
        font=tipo,
        fill=BLANCO,
    )


def _marcar_esquina(icono, dibujo, inicial: str, lado: int) -> None:
    """Franja diagonal en la esquina. Para los iconos que NO se recortan."""
    alto = max(6, round(lado * 0.34))
    dibujo.polygon(
        [(lado, lado - alto), (lado, lado), (lado - alto, lado)],
        fill=DORADO,
    )
    # La letra solo cabe a partir de cierto tamaño. En 16 px la franja sola ya
    # distingue, y una letra ahí sería una mancha que ensucia sin informar.
    if lado >= 64:
        _centrar_letra(
            dibujo,
            inicial,
            fuente(max(8, round(lado * 0.17))),
            lado - alto * 0.42,
            lado - alto * 0.36,
        )


def _marcar_maskable(icono, dibujo, inicial: str, lado: int) -> None:
    """Banda horizontal DENTRO del círculo seguro. Para los que sí se recortan.

    La zona segura de un icono maskable es el 80 % central, o sea un círculo de
    radio 0.4·lado. La banda se recorta contra ese círculo para que sobreviva a
    cualquier forma que elija el lanzador de Android.
    """
    radio = lado * 0.40
    centro = lado / 2
    alto = max(8, round(lado * 0.22))
    arriba = centro + radio - alto

    banda = Image.new('RGBA', (lado, lado), (0, 0, 0, 0))
    ImageDraw.Draw(banda).rectangle([(0, arriba), (lado, centro + radio)], fill=DORADO)

    # La máscara es el círculo seguro: lo que caiga fuera se descarta.
    seguro = Image.new('L', (lado, lado), 0)
    ImageDraw.Draw(seguro).ellipse(
        [(centro - radio, centro - radio), (centro + radio, centro + radio)],
        fill=255,
    )
    banda.putalpha(Image.composite(banda.getchannel('A'), Image.new('L', (lado, lado), 0), seguro))
    icono.alpha_composite(banda)

    if lado >= 64:
        _centrar_letra(
            ImageDraw.Draw(icono),
            inicial,
            fuente(max(9, round(alto * 0.72))),
            centro,
            arriba + alto / 2,
        )


def marcar(ruta: Path, inicial: str) -> None:
    icono = Image.open(ruta).convert('RGBA')
    lado = icono.size[0]

    if 'maskable' in ruta.name:
        _marcar_maskable(icono, None, inicial, lado)
        icono.save(ruta)
        return

    capa = Image.new('RGBA', icono.size, (0, 0, 0, 0))
    _marcar_esquina(icono, ImageDraw.Draw(capa), inicial, lado)
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

    # ─────────────────────────────────────────────────────────────────────────
    # Los iconos marcados van a RUTAS NUEVAS, no encima de las originales.
    # ─────────────────────────────────────────────────────────────────────────
    #
    # Marcar el archivo en su sitio no bastó, y el motivo es Android: al
    # instalar una aplicación web genera un WebAPK con el icono **horneado
    # dentro**. Cambiar los bytes detrás de la misma dirección no le llega ni
    # desinstalando y volviendo a instalar, porque el icono se sirve desde una
    # caché que la dirección no invalida.
    #
    # Comprobado el 10 de septiembre de 2026: el archivo servido tenía la marca,
    # y el teléfono seguía enseñando el icono de antes tras varias
    # reinstalaciones.
    #
    # Con un nombre distinto no hay nada que reutilizar: es otra dirección, y el
    # WebAPK se genera con lo que encuentra en ella.
    renombrados: dict[str, str] = {}
    for icono in iconos:
        marcado = icono.with_name(f'{icono.stem}-{ambiente}{icono.suffix}')
        marcado.write_bytes(icono.read_bytes())
        marcar(marcado, INICIALES[ambiente])
        renombrados[f'icons/{icono.name}'] = f'icons/{marcado.name}'

    _reescribir_referencias(destino, renombrados)

    print(f'Marcados {len(iconos)} iconos para «{ambiente}» con la inicial '
          f'«{INICIALES[ambiente]}», en rutas propias.')


def _reescribir_referencias(destino: Path, renombrados: dict[str, str]) -> None:
    """Apunta el manifiesto y el HTML a los iconos marcados.

    Los originales se dejan donde están: si algo quedó apuntando a ellos, sigue
    encontrando un icono válido en vez de un hueco.
    """
    manifiesto = destino / 'manifest.json'
    if manifiesto.is_file():
        import json

        datos = json.loads(manifiesto.read_text(encoding='utf-8'))
        for icono in datos.get('icons', []):
            icono['src'] = renombrados.get(icono.get('src', ''), icono.get('src', ''))
        manifiesto.write_text(
            json.dumps(datos, ensure_ascii=False, indent=2) + '\n', encoding='utf-8'
        )
        print(f'  manifest.json: {len(datos.get("icons", []))} referencias actualizadas')

    indice = destino / 'index.html'
    if indice.is_file():
        html = indice.read_text(encoding='utf-8')
        antes = html
        for viejo, nuevo in renombrados.items():
            html = html.replace(viejo, nuevo)
        if html != antes:
            indice.write_text(html, encoding='utf-8')
            print('  index.html: referencias actualizadas')


if __name__ == '__main__':
    main()
