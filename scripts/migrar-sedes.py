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
  · si se pide, marca a una persona como administración general (RF-SED-06);
  · (2.0.6) crea el catálogo único de facultades, `facultades/{id}`, con cada
    facultad que alguna sede ya tenía, con su mismo identificador: así lo que
    ya está asignado a cada persona sigue valiendo. Si dos sedes tienen el
    mismo nombre con identificadores distintos, no adivina: lo avisa y no
    crea la segunda (la decide el superadministrador);
  · (2.0-f, decisiones del 23/11/2026) completa lo viejo que no dice sede:
    F1, la bitácora anterior a la 2.0 pasa a ser de `bdm`, y un asiento de la
    propia migración lo hace constar; F2, entregas y respuestas (`hilos`)
    toman la sede de su aviso; F3, cada perfil guarda `sedesIds` y
    `sedesCoordina`, las listas que leen las reglas. También las invitaciones
    sin sede pasan a `bdm`.

Escribe por tandas de 500 (`batchWrite`), así que miles de entregas no tardan
lo que tardarían una por una.

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
import datetime
import json
import os
import re
import subprocess
import sys
import unicodedata

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
    if isinstance(v, datetime.datetime):
        return {'timestampValue': v.astimezone(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}
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

def clave_de_nombre(nombre):
    """Como `claveDeNombre` del servidor: sin tildes, sin mayúsculas, sin espacios de más."""
    sin_tildes = ''.join(c for c in unicodedata.normalize('NFD', nombre) if not unicodedata.combining(c))
    return re.sub(r'\s+', ' ', sin_tildes.lower()).strip()


def campos_de_sedes(membresias):
    """Como `camposDeSedes` del servidor: las listas que leen las reglas (F3)."""
    ids = sorted(membresias.keys())
    coordina = [s for s in ids
                if isinstance(membresias.get(s), dict) and membresias[s].get('rol') in ('COORDINADOR', 'AUDITOR')]
    return {'sedesIds': ids, 'sedesCoordina': coordina}


def sede_de_ruta(ruta, campos, sede_de_mensaje):
    """La sede de una entrega o un hilo: la de su aviso (F2). Sin aviso conocido, la inicial."""
    mensaje_id = campos.get('mensajeId') or (ruta.split('/')[1] if ruta.startswith('mensajes/') else '')
    return sede_de_mensaje.get(mensaje_id, SEDE_INICIAL)


def planificar(*, usuarios, grupos, mensajes, existe_sede, existe_facultad,
               facultad_a_todos=False, admin_general=None,
               facultades_por_sede=(), catalogo=None,
               invitaciones=(), bitacora=(), entregas=(), hilos=(), ahora=None):
    """
    Cada operación es (ruta, cambios, debe_existir). `debe_existir=False` solo
    crea si no está; `True` solo actualiza lo que ya está. Así ninguna operación
    puede crear un documento a medias ni pisar uno ajeno.

    usuarios, grupos, mensajes: listas de (id, campos ya decodificados).
    facultades_por_sede: lista de (sede, id, campos) de `sedes/*/facultades`.
    catalogo: {id: campos} del catálogo único `facultades/` tal como está.
    """
    ops = []
    resumen = {'sede': 0, 'facultad': 0, 'usuarios': 0, 'facultad_a_perfiles': 0,
               'admin_general': 0, 'grupos': 0, 'mensajes': 0,
               'catalogo_facultades': 0, 'listas_de_sedes': 0, 'invitaciones': 0,
               'bitacora': 0, 'entregas': 0, 'hilos': 0, 'conflictos': []}

    if not existe_sede:
        ops.append((f'sedes/{SEDE_INICIAL}', {'nombre': NOMBRE_SEDE_INICIAL, 'activa': True}, False))
        resumen['sede'] = 1
    if not existe_facultad:
        ops.append((f'sedes/{SEDE_INICIAL}/facultades/{FACULTAD_INICIAL}',
                    {'nombre': NOMBRE_FACULTAD_INICIAL, 'activa': True}, False))
        resumen['facultad'] = 1

    # Catálogo único de facultades (2.0.6): adopta las que ya tienen las sedes.
    globales = dict(catalogo or {})
    por_clave = {clave_de_nombre(d.get('nombre') or i): i for i, d in globales.items()}
    candidatas = list(facultades_por_sede)
    if not existe_facultad:
        candidatas.append((SEDE_INICIAL, FACULTAD_INICIAL, {'nombre': NOMBRE_FACULTAD_INICIAL}))
    for sede, fid, d in candidatas:
        if fid in globales:
            continue
        nombre = d.get('nombre') or fid
        k = clave_de_nombre(nombre)
        if k in por_clave and por_clave[k] != fid:
            resumen['conflictos'].append(
                f'«{nombre}» de {sede} ({fid}) se llama igual que {por_clave[k]}: no se crea')
            continue
        globales[fid] = {'nombre': nombre}
        por_clave[k] = fid
        ops.append((f'facultades/{fid}', {'nombre': nombre, 'activa': True}, False))
        resumen['catalogo_facultades'] += 1

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
        # F3: las listas que leen las reglas, al día con las membresías.
        listas = campos_de_sedes(membresias)
        if d.get('sedesIds') != listas['sedesIds'] or d.get('sedesCoordina') != listas['sedesCoordina']:
            cambios.update(listas)
            resumen['listas_de_sedes'] += 1
        if correo_admin and (d.get('correo') or '').strip().lower() == correo_admin:
            admin_encontrado = True
            if d.get('adminGeneral') is not True:
                cambios['adminGeneral'] = True
                resumen['admin_general'] = 1
        if cambios:
            ops.append((f'usuarios/{uid}', cambios, True))

    for coleccion, docs in (('grupos', grupos), ('mensajes', mensajes), ('invitaciones', invitaciones)):
        for doc_id, d in docs:
            if not d.get('sedeId'):
                ops.append((f'{coleccion}/{doc_id}', {'sedeId': SEDE_INICIAL}, True))
                resumen[coleccion] += 1

    # F1: la bitácora anterior a la 2.0 es de la sede inicial. Solo clasifica:
    # no cambia lo que registra, y la migración deja su propio asiento.
    for doc_id, d in bitacora:
        if not d.get('sedeId'):
            ops.append((f'bitacora/{doc_id}', {'sedeId': SEDE_INICIAL}, True))
            resumen['bitacora'] += 1
    if resumen['bitacora'] > 0:
        cuando = ahora or datetime.datetime.now(datetime.timezone.utc)
        ops.append((f"bitacora/migracion-2-0-f-{cuando.strftime('%Y%m%d%H%M%S')}", {
            'tipo': 'MIGRACION_SEDES',
            'actorUid': 'sistema',
            'actorCorreo': '',
            'actorRol': 'SISTEMA',
            'entidad': 'BITACORA',
            'entidadId': 'bitacora',
            'resumen': (f"Migración 2.0-f: {resumen['bitacora']} asientos anteriores a la 2.0 se "
                        'clasifican como de Boca del Monte. No cambia lo que registran.'),
            'sedeId': SEDE_INICIAL,
            'ocurridoEn': cuando,
        }, False))

    # F2: entregas y respuestas toman la sede de su aviso.
    sede_de_mensaje = {doc_id: (d.get('sedeId') or SEDE_INICIAL) for doc_id, d in mensajes}
    for clave, docs in (('entregas', entregas), ('hilos', hilos)):
        for ruta, d in docs:
            if not d.get('sedeId'):
                ops.append((ruta, {'sedeId': sede_de_ruta(ruta, d, sede_de_mensaje)}, True))
                resumen[clave] += 1

    if correo_admin and not admin_encontrado:
        raise ValueError('No hay ningún perfil con ese correo para la administración general.')
    return ops, resumen


# ---------------------------------------------------------------------------
# Lectura y escritura contra Firestore
# ---------------------------------------------------------------------------

TAMANO_TANDA = 500


def tandas(ops, tamano=TAMANO_TANDA):
    """Las operaciones en tandas de a lo sumo 500, el máximo de `batchWrite`."""
    return [ops[i:i + tamano] for i in range(0, len(ops), tamano)]


def escritura(raiz, op):
    """Una operación del plan como escritura de `batchWrite`, con su precondición."""
    ruta, cambios, debe_existir = op
    return {
        'update': {'name': f'{raiz}/{ruta}', 'fields': {k: a_valor(v) for k, v in cambios.items()}},
        'updateMask': {'fieldPaths': list(cambios.keys())},
        'currentDocument': {'exists': debe_existir},
    }


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

    def hijos(padre, coleccion):
        q = {'structuredQuery': {'from': [{'collectionId': coleccion}]}}
        filas = _curl(cfg, 'POST', f'{base}/{padre}:runQuery', q)
        return [(x['document']['name'].rsplit('/', 1)[1], campos(x['document'])) for x in filas if 'document' in x]

    facultades_por_sede = [(sede, fid, d) for sede, _ in todos('sedes') for fid, d in hijos(f'sedes/{sede}', 'facultades')]

    def grupo_de_colecciones(coleccion):
        """(ruta relativa, campos) de toda una colección, a cualquier profundidad."""
        q = {'structuredQuery': {'from': [{'collectionId': coleccion, 'allDescendants': True}]}}
        filas = _curl(cfg, 'POST', f'{base}:runQuery', q)
        if isinstance(filas, dict) and 'error' in filas:
            raise SystemExit(f"Firestore respondió: {filas['error'].get('message')}")
        return [(x['document']['name'].split('/documents/', 1)[1], campos(x['document']))
                for x in filas if 'document' in x]

    ops, resumen = planificar(
        usuarios=todos('usuarios'), grupos=todos('grupos'), mensajes=todos('mensajes'),
        existe_sede=existe(f'sedes/{SEDE_INICIAL}'),
        existe_facultad=existe(f'sedes/{SEDE_INICIAL}/facultades/{FACULTAD_INICIAL}'),
        facultad_a_todos=facultad_a_todos, admin_general=admin,
        facultades_por_sede=facultades_por_sede, catalogo=dict(todos('facultades')),
        invitaciones=todos('invitaciones'), bitacora=todos('bitacora'),
        entregas=grupo_de_colecciones('entregas'), hilos=grupo_de_colecciones('hilos'),
    )
    print(f'Proyecto {proyecto} · {"APLICANDO" if aplicar else "solo el plan (sin escribir)"}')
    conflictos = resumen.pop('conflictos')
    for clave, n in resumen.items():
        print(f'  {clave:20} {n}')
    for c in conflictos:
        print(f'  AVISO: {c}')
    print(f'  {"operaciones":20} {len(ops)}')
    if not aplicar or not ops:
        return 0

    raiz = f'projects/{proyecto}/databases/(default)/documents'
    fallidas = 0
    for tanda in tandas(ops):
        r = _curl(cfg, 'POST', f'{base}:batchWrite', {'writes': [escritura(raiz, op) for op in tanda]})
        if 'error' in r:
            fallidas += len(tanda)
            print(f'  FALLÓ una tanda de {len(tanda)}: {r["error"].get("message", "")[:120]}')
            continue
        for op, estado in zip(tanda, r.get('status', [])):
            if estado.get('code', 0) != 0:
                fallidas += 1
                print(f'  FALLÓ {op[0]}: {estado.get("message", "")[:120]}')
    print(f'Escritas {len(ops) - fallidas} de {len(ops)}.')
    return 0 if fallidas == 0 else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv))
