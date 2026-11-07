#!/usr/bin/env python3
"""
SIAN — Migración a varias sedes (2.0, ADR-009, paso 2.0-c).

Rellena lo que la 2.0 necesita en los datos que ya existen, sin cambiar cómo se
comporta nada:

  · crea la sede inicial `sedes/bdm` (Boca del Monte) y su primera facultad,
    `sedes/bdm/facultades/ing-sistemas` (Ingeniería en Sistemas), si no están;
  · da a cada perfil sin `membresias` la de omisión, `{bdm: {rol, facultades}}`,
    que es exactamente lo que el servidor ya suponía;
  · pone `sedeId: 'bdm'` a los mensajes y grupos que no la tienen;
  · si se pide, marca a una persona como administración general (RF-SED-06).

NO toca la bitácora: es inmutable (RF-BIT-03), y un asiento sin sede se lee como
de `bdm`. Tampoco borra ni reescribe nada que ya tenga su dato: es idempotente,
correrlo dos veces deja lo mismo, y la segunda vez no escribe nada.

Uso:
  python3 scripts/migrar-sedes.py <proyecto>                    # solo muestra el plan
  python3 scripts/migrar-sedes.py <proyecto> --aplicar          # lo escribe
  opciones:  --facultad-a-todos       pone Ingeniería en Sistemas a todos los perfiles
             --admin-general <correo>  marca a esa persona como administración general

Usa el token de la CLI de Firebase (`npx firebase projects:list` lo refresca) y
nunca lo imprime: curl lo recibe por la entrada estándar. Antes de correrlo en
producción, el respaldo diario tiene que estar al día (documento 11).
"""
import json
import os
import subprocess
import sys

SEDE_INICIAL = 'bdm'
NOMBRE_SEDE_INICIAL = 'Boca del Monte'
FACULTAD_INICIAL = 'ing-sistemas'
NOMBRE_FACULTAD_INICIAL = 'Ingeniería en Sistemas'
ROLES = {'COORDINADOR', 'ADMINISTRADORA', 'CATEDRATICO', 'AUDITOR'}


# ---------------------------------------------------------------------------
# Valores de Firestore (REST) — funciones puras, con pruebas en test_migrar_sedes.py
# ---------------------------------------------------------------------------

def a_valor(v):
    """Un valor de Python como `Value` de la API REST de Firestore."""
    if isinstance(v, bool):
        return {'booleanValue': v}
    if isinstance(v, str):
        return {'stringValue': v}
    if isinstance(v, int):
        return {'integerValue': str(v)}
    if isinstance(v, list):
        return {'arrayValue': {'values': [a_valor(x) for x in v]}}
    if isinstance(v, dict):
        return {'mapValue': {'fields': {k: a_valor(x) for k, x in v.items()}}}
    if v is None:
        return {'nullValue': None}
    raise ValueError(f'tipo no soportado: {type(v).__name__}')


def de_valor(v):
    """Un `Value` de Firestore como Python. Lo que no se usa aquí queda como None."""
    if 'stringValue' in v:
        return v['stringValue']
    if 'booleanValue' in v:
        return v['booleanValue']
    if 'integerValue' in v:
        return int(v['integerValue'])
    if 'arrayValue' in v:
        return [de_valor(x) for x in v['arrayValue'].get('values', [])]
    if 'mapValue' in v:
        return {k: de_valor(x) for k, x in v['mapValue'].get('fields', {}).items()}
    return None


def campos(documento):
    return {k: de_valor(v) for k, v in documento.get('fields', {}).items()}


# ---------------------------------------------------------------------------
# El plan — puro: recibe lo leído y devuelve qué escribir
# ---------------------------------------------------------------------------

def planificar(*, usuarios, grupos, mensajes, existe_sede, existe_facultad,
               facultad_a_todos=False, admin_general=None):
    """
    Cada operación es (ruta, cambios, debe_existir). `debe_existir=False` solo
    crea si no está; `True` solo actualiza lo que ya está. Así ninguna operación
    puede crear un documento a medias ni pisar uno ajeno.

    usuarios, grupos, mensajes: listas de (id, campos ya decodificados).
    """
    ops = []
    resumen = {'sede': 0, 'facultad': 0, 'usuarios': 0, 'facultad_a_perfiles': 0,
               'admin_general': 0, 'grupos': 0, 'mensajes': 0}

    if not existe_sede:
        ops.append((f'sedes/{SEDE_INICIAL}', {'nombre': NOMBRE_SEDE_INICIAL, 'activa': True}, False))
        resumen['sede'] = 1
    if not existe_facultad:
        ops.append((f'sedes/{SEDE_INICIAL}/facultades/{FACULTAD_INICIAL}',
                    {'nombre': NOMBRE_FACULTAD_INICIAL, 'activa': True}, False))
        resumen['facultad'] = 1

    correo_admin = (admin_general or '').strip().lower()
    admin_encontrado = False
    for uid, d in usuarios:
        cambios = {}
        membresias = d.get('membresias')
        rol = d.get('rol') if d.get('rol') in ROLES else 'CATEDRATICO'
        if not isinstance(membresias, dict) or not membresias:
            membresias = {SEDE_INICIAL: {'rol': rol, 'facultades': []}}
            cambios['membresias'] = membresias
            resumen['usuarios'] += 1
        if facultad_a_todos:
            m = membresias.get(SEDE_INICIAL)
            if isinstance(m, dict):
                facultades = m.get('facultades') if isinstance(m.get('facultades'), list) else []
                if FACULTAD_INICIAL not in facultades:
                    nuevas = {**membresias, SEDE_INICIAL: {**m, 'facultades': sorted(facultades + [FACULTAD_INICIAL])}}
                    membresias = nuevas
                    cambios['membresias'] = nuevas
                    resumen['facultad_a_perfiles'] += 1
        if correo_admin and (d.get('correo') or '').strip().lower() == correo_admin:
            admin_encontrado = True
            if d.get('adminGeneral') is not True:
                cambios['adminGeneral'] = True
                resumen['admin_general'] = 1
        if cambios:
            ops.append((f'usuarios/{uid}', cambios, True))

    for coleccion, docs in (('grupos', grupos), ('mensajes', mensajes)):
        for doc_id, d in docs:
            if not d.get('sedeId'):
                ops.append((f'{coleccion}/{doc_id}', {'sedeId': SEDE_INICIAL}, True))
                resumen[coleccion] += 1

    if correo_admin and not admin_encontrado:
        raise ValueError('No hay ningún perfil con ese correo para la administración general.')
    return ops, resumen


# ---------------------------------------------------------------------------
# Lectura y escritura contra Firestore
# ---------------------------------------------------------------------------

def _curl(cfg, metodo, url, cuerpo=None):
    args = ['curl', '-s', '-K', '-', '-X', metodo, url]
    if cuerpo is not None:
        args += ['--data-binary', json.dumps(cuerpo)]
    r = subprocess.run(args, input=cfg, capture_output=True, text=True)
    return json.loads(r.stdout) if r.stdout.strip() else {}


def main(argv):
    if len(argv) < 2 or argv[1].startswith('-'):
        print(__doc__)
        return 2
    proyecto = argv[1]
    aplicar = '--aplicar' in argv
    facultad_a_todos = '--facultad-a-todos' in argv
    admin = argv[argv.index('--admin-general') + 1] if '--admin-general' in argv else None

    tok = json.load(open(os.path.expanduser('~/.config/configstore/firebase-tools.json')))['tokens']['access_token']
    cfg = (f'header = "Authorization: Bearer {tok}"\nheader = "Content-Type: application/json"\n'
           f'header = "x-goog-user-project: {proyecto}"\n')
    base = f'https://firestore.googleapis.com/v1/projects/{proyecto}/databases/(default)/documents'

    def todos(coleccion):
        q = {'structuredQuery': {'from': [{'collectionId': coleccion}]}}
        filas = _curl(cfg, 'POST', f'{base}:runQuery', q)
        if isinstance(filas, dict) and 'error' in filas:
            raise SystemExit(f"Firestore respondió: {filas['error'].get('message')}")
        return [(x['document']['name'].rsplit('/', 1)[1], campos(x['document'])) for x in filas if 'document' in x]

    def existe(ruta):
        r = _curl(cfg, 'GET', f'{base}/{ruta}')
        return 'name' in r

    ops, resumen = planificar(
        usuarios=todos('usuarios'), grupos=todos('grupos'), mensajes=todos('mensajes'),
        existe_sede=existe(f'sedes/{SEDE_INICIAL}'),
        existe_facultad=existe(f'sedes/{SEDE_INICIAL}/facultades/{FACULTAD_INICIAL}'),
        facultad_a_todos=facultad_a_todos, admin_general=admin,
    )
    print(f'Proyecto {proyecto} · {"APLICANDO" if aplicar else "solo el plan (sin escribir)"}')
    for clave, n in resumen.items():
        print(f'  {clave:20} {n}')
    print(f'  {"operaciones":20} {len(ops)}')
    if not aplicar or not ops:
        return 0

    fallidas = 0
    for ruta, cambios, debe_existir in ops:
        mascara = '&'.join(f'updateMask.fieldPaths={k}' for k in cambios)
        pre = f'currentDocument.exists={"true" if debe_existir else "false"}'
        r = _curl(cfg, 'PATCH', f'{base}/{ruta}?{mascara}&{pre}',
                  {'fields': {k: a_valor(v) for k, v in cambios.items()}})
        if 'error' in r:
            fallidas += 1
            print(f'  FALLÓ {ruta}: {r["error"].get("message", "")[:120]}')
    print(f'Escritas {len(ops) - fallidas} de {len(ops)}.')
    return 0 if fallidas == 0 else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv))
