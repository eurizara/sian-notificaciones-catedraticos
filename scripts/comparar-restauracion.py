#!/usr/bin/env python3
"""
SIAN — Comprueba una restauración de respaldo de Firestore (documento 11).

Compara una base restaurada con `(default)`: todo documento que exista hoy y se
haya creado ANTES del respaldo tiene que estar en la restaurada, e idéntico si
no se modificó después. Solo lee; no toca ninguna de las dos bases.

Uso:  python3 scripts/comparar-restauracion.py <proyecto> <base-restaurada> <AAAA-MM-DDTHH:MM del respaldo, UTC>

Usa el token de la CLI de Firebase (`npx firebase projects:list` lo refresca) y
nunca lo imprime: curl lo recibe por la entrada estándar.
"""
import json, os, subprocess, sys
PROYECTO, BASE, CORTE = sys.argv[1], sys.argv[2], sys.argv[3]
tok = json.load(open(os.path.expanduser('~/.config/configstore/firebase-tools.json')))['tokens']['access_token']
cfg = f'header = "Authorization: Bearer {tok}"\nheader = "Content-Type: application/json"\nheader = "x-goog-user-project: {PROYECTO}"\n'
def todos(db, coleccion):
    url = f'https://firestore.googleapis.com/v1/projects/{PROYECTO}/databases/{db}/documents:runQuery'
    q = {"structuredQuery": {"from": [{"collectionId": coleccion, "allDescendants": True}]}}
    r = subprocess.run(['curl','-s','-K','-','-X','POST','--data-binary',json.dumps(q),url], input=cfg, capture_output=True, text=True)
    out = {}
    for x in json.loads(r.stdout):
        d = x.get('document')
        if d:
            out[d['name'].split('/documents/')[1]] = d
    return out
total_ok = True
for c in ['usuarios','dispositivos','grupos','mensajes','ocurrencias','entregas','hilos','turnos','invitaciones','configuracion','bitacora','plantillas','cola_despacho']:
    hoy, rest = todos('(default)', c), todos(BASE, c)
    antes = {k: d for k, d in hoy.items() if d['createTime'] < CORTE}
    faltan = [k for k in antes if k not in rest]
    iguales = sum(1 for k, d in antes.items() if k in rest and d['updateTime'] < CORTE and d['fields'] == rest[k].get('fields'))
    sin_cambio = sum(1 for d in antes.values() if d['updateTime'] < CORTE)
    ok = not faltan and iguales == sin_cambio
    total_ok &= ok
    print(f'{c:14} hoy {len(hoy):4} · creados antes del respaldo {len(antes):4} · restaurados {len(rest):4} · faltan {len(faltan)} · idénticos {iguales}/{sin_cambio} {"OK" if ok else "REVISAR"}')
print('RESULTADO:', 'la restauración contiene todo lo que había al respaldarse' if total_ok else 'hay diferencias')
sys.exit(0 if total_ok else 1)
