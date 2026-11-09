#!/usr/bin/env python3
"""
SIAN — Un cambio en la aplicación exige subir su versión.

El 07/11/2026 la 2.0 llegó a desarrollo con el número 1.6.20: el código era
nuevo, pero la aplicación no ofrecía actualizar y nadie podía saber qué tenía
delante. Ninguna prueba lo miraba. Esto corre en cada pull request y lo frena
ANTES de fusionar, que es donde todavía se corrige con un commit.

Cuenta como «cambio en la aplicación» lo que llega a quien usa SIAN:
`app/lib/**` y `app/web/**`, salvo los manuales (`app/web/manuales/**`), que se
corrigen sin cambiar la aplicación. No cuentan las pruebas, la documentación,
las funciones ni `pubspec.lock` (la actualización mensual de dependencias es
automática y no puede quedar bloqueada; su versión se sube al liberar).

Uso (en la CI):  python3 scripts/verificar-version.py <commit-base>
"""
import re
import subprocess
import sys

RUTA_VERSION = 'app/lib/core/version.dart'


def toca_la_aplicacion(archivos):
    """¿Alguno de estos archivos llega a quien usa SIAN?"""
    for a in archivos:
        if a.startswith('app/web/manuales/'):
            continue
        if a.startswith('app/lib/') or a.startswith('app/web/'):
            return True
    return False


def leer_version(texto):
    m = re.search(r"const String versionSian = '(\d+)\.(\d+)\.(\d+)';", texto or '')
    return tuple(int(x) for x in m.groups()) if m else None


def decidir(archivos, texto_base, texto_nuevo):
    """(bien, mensaje). Pura: recibe lo leído, no toca git."""
    if not toca_la_aplicacion(archivos):
        return True, 'No cambia la aplicación: no hace falta subir la versión.'
    base, nueva = leer_version(texto_base), leer_version(texto_nuevo)
    if nueva is None:
        return False, f'No se pudo leer versionSian en {RUTA_VERSION}.'
    if base is None or nueva > base:
        return True, f'Versión {".".join(map(str, nueva))}: sube respecto de la base.'
    return False, (
        f'Este cambio toca la aplicación y la versión sigue en {".".join(map(str, nueva))}. '
        f'Súbala en {RUTA_VERSION} y en app/pubspec.yaml, con su sección en las notas de '
        'la versión (app/web/manuales/notas/index.html) y su fila en el documento 08. '
        'Sin eso, quien usa SIAN no ve «Actualizar» ni puede saber qué versión tiene.'
    )


def _git(*args):
    return subprocess.run(['git', *args], capture_output=True, text=True, check=True).stdout


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 2
    base = argv[1]
    archivos = [l for l in _git('diff', '--name-only', f'{base}...HEAD').splitlines() if l]
    try:
        texto_base = _git('show', f'{base}:{RUTA_VERSION}')
    except subprocess.CalledProcessError:
        texto_base = ''
    with open(RUTA_VERSION, encoding='utf-8') as f:
        texto_nuevo = f.read()
    bien, mensaje = decidir(archivos, texto_base, texto_nuevo)
    print(mensaje if bien else f'::error file={RUTA_VERSION}::{mensaje}')
    return 0 if bien else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv))
