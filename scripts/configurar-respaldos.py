#!/usr/bin/env python3
"""SIAN — Respaldos programados de Firestore (1.5.13, documento 12, S-2).

Uso:
    TOKEN=$(gcloud auth print-access-token) python3 scripts/configurar-respaldos.py sian-umg-bdm
    python3 scripts/configurar-respaldos.py sian-umg-bdm --revisar   # solo lee, no cambia nada

────────────────────────────────────────────────────────────────────────────────
Por qué ahora
────────────────────────────────────────────────────────────────────────────────

Hasta el 23/09/2026 ningún ambiente tenía respaldos, tampoco producción. Un
borrado equivocado —de una persona, de un guion o de una migración— no tenía
vuelta atrás. Y la iteración 2.0 migra todos los datos a un modelo con sedes:
no se empieza una migración sin poder deshacerla.

────────────────────────────────────────────────────────────────────────────────
Qué deja configurado
────────────────────────────────────────────────────────────────────────────────

    Producción   diario, 7 días      + semanal (domingo), 12 semanas
    QA           semanal (domingo), 4 semanas
    Desarrollo   semanal (domingo), 4 semanas

Firestore admite como mucho un programa diario (retención máxima de 7 días) y
uno semanal (máxima de 14 semanas) por base de datos. El diario cubre «ayer
borré algo»; el semanal, «me di cuenta tres semanas después».

El costo se paga por GB guardado en respaldos, y hoy los datos pesan unos pocos
MB: son centavos al mes.

Es idempotente: crea lo que falta, ajusta la retención si cambió, y no duplica
nada si se corre dos veces.

────────────────────────────────────────────────────────────────────────────────
Cómo se restaura
────────────────────────────────────────────────────────────────────────────────

Un respaldo se restaura en una base de datos **nueva** —nunca encima de la
`(default)`—, y desde ahí se copian los documentos que hagan falta. El
procedimiento está en el documento 11. Firestore no hace respaldos al
momento: el primero sale en la fecha del programa, y la restauración se prueba
en desarrollo con ese primer respaldo.
"""

import json
import os
import subprocess
import sys

DIA = 86_400

PLANES = {
    'sian-umg-bdm': [
        ('diario', {'dailyRecurrence': {}}, 7 * DIA),
        ('semanal', {'weeklyRecurrence': {'day': 'SUNDAY'}}, 12 * 7 * DIA),
    ],
    'sian-umg-bdm-qa': [
        ('semanal', {'weeklyRecurrence': {'day': 'SUNDAY'}}, 4 * 7 * DIA),
    ],
    'sian-umg-bdm-dev': [
        ('semanal', {'weeklyRecurrence': {'day': 'SUNDAY'}}, 4 * 7 * DIA),
    ],
}


def token() -> str:
    """El de la variable TOKEN, o el de gcloud si está a mano."""
    if os.environ.get('TOKEN'):
        return os.environ['TOKEN']
    try:
        return subprocess.run(
            ['gcloud', 'auth', 'print-access-token'],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        sys.exit(
            'error: hace falta un token de acceso.\n'
            '       TOKEN=$(gcloud auth print-access-token) python3 '
            'scripts/configurar-respaldos.py <proyecto>'
        )


def api(metodo: str, url: str, cuerpo=None) -> dict:
    orden = ['curl', '-s', '-X', metodo, '-H', f'Authorization: Bearer {TOKEN}',
             '-H', 'Content-Type: application/json']
    if cuerpo is not None:
        orden += ['-d', json.dumps(cuerpo)]
    salida = subprocess.run(orden + [url], capture_output=True, text=True).stdout
    return json.loads(salida or '{}')


def tipo(programa: dict) -> str:
    return 'diario' if 'dailyRecurrence' in programa else 'semanal'


def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] not in PLANES:
        sys.exit(f'uso: configurar-respaldos.py <{"|".join(PLANES)}> [--revisar]')
    proyecto = sys.argv[1]
    solo_revisar = '--revisar' in sys.argv

    base = (f'https://firestore.googleapis.com/v1/projects/{proyecto}'
            '/databases/(default)/backupSchedules')
    existentes = api('GET', base)
    if 'error' in existentes:
        sys.exit(f'error: {existentes["error"].get("message")}')
    por_tipo = {tipo(p): p for p in existentes.get('backupSchedules', [])}

    print(f'{proyecto}:')
    for nombre, recurrencia, segundos in PLANES[proyecto]:
        deseada = f'{segundos}s'
        actual = por_tipo.get(nombre)
        if actual and actual.get('retention') == deseada:
            print(f'  {nombre:<8} ya está, con {segundos // DIA} días de retención')
        elif solo_revisar:
            print(f'  {nombre:<8} FALTA o difiere (actual: {actual.get("retention") if actual else "ninguno"})')
        elif actual:
            r = api('PATCH', f'https://firestore.googleapis.com/v1/{actual["name"]}'
                             '?updateMask=retention', {'retention': deseada})
            print(f'  {nombre:<8} retención ajustada a {segundos // DIA} días'
                  if 'name' in r else f'  {nombre:<8} error: {r}')
        else:
            r = api('POST', base, {'retention': deseada, **recurrencia})
            print(f'  {nombre:<8} creado, con {segundos // DIA} días de retención'
                  if 'name' in r else f'  {nombre:<8} error: {r.get("error", r)}')

    sobran = set(por_tipo) - {n for n, _, _ in PLANES[proyecto]}
    for nombre in sorted(sobran):
        # No se borra: quitar un programa de respaldo tiene que ser una decisión
        # explícita, no un efecto secundario de correr este guion.
        print(f'  {nombre:<8} existe y no está en el plan: se deja como está')


TOKEN = token()

if __name__ == '__main__':
    main()
