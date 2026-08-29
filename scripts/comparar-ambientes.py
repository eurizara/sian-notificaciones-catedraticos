#!/usr/bin/env python3
"""SIAN — Compara los tres ambientes y señala en qué se han separado.

    TOKEN=$(gcloud auth print-access-token) python3 scripts/comparar-ambientes.py

Compara **todo menos los datos**: código servido, Functions, reglas, índices,
autenticación, CORS, APIs habilitadas, alertas y planificador. Los usuarios y
los mensajes de cada ambiente son suyos y no deben parecerse.

─────────────────────────────────────────────────────────────────────────────
Por qué existe
─────────────────────────────────────────────────────────────────────────────

El 28 de agosto de 2026 se pasó un día entero persiguiendo un fallo que en
desarrollo no se reproducía. La causa acabó siendo que **el mismo código se
comportaba distinto porque los ambientes no eran iguales**, y esa desigualdad
no estaba en el código:

  · Desarrollo tenía el CORS del bucket con cuatro orígenes y los otros con
    ocho, porque el archivo se actualizó y solo se aplicó a dos.
  · Producción se creó desde la consola meses antes que los otros dos y traía
    APIs distintas. Una faltaba, y detuvo el primer despliegue.

Ninguna de las dos se ve mirando el repositorio. Se ven preguntándole a cada
proyecto qué tiene, que es lo que hace este script.

Lo que **no** compara, y sigue siendo la trampa más difícil: los datos
acumulados. Ese mismo día, un defecto de envío no apareció en desarrollo porque
ahí todos los dispositivos eran del esquema viejo, donde el defecto no podía
manifestarse. Antes de dar por buena una prueba en un ambiente, conviene
preguntarse si sus datos se parecen a los del ambiente donde va a correr de
verdad.
"""

import json
import os
import subprocess
import sys

AMBIENTES = [
    ("dev", "sian-umg-bdm-dev", "863854823370"),
    ("qa", "sian-umg-bdm-qa", "186815040849"),
    ("prd", "sian-umg-bdm", "199298701333"),
]


def token() -> str:
    if os.environ.get("TOKEN"):
        return os.environ["TOKEN"].strip()
    try:
        return subprocess.run(
            ["gcloud", "auth", "print-access-token"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        sys.exit(
            "error: hace falta un token.\n"
            "       TOKEN=$(gcloud auth print-access-token) "
            "python3 scripts/comparar-ambientes.py"
        )


TOKEN = token()


def api(url: str) -> dict:
    """Consulta autenticada. Devuelve `{}` si algo falla: aquí una respuesta
    ilegible es un dato («no pude leerlo»), no un motivo para abortar."""
    salida = subprocess.run(
        ["curl", "-s", "-H", f"Authorization: Bearer {TOKEN}", url],
        capture_output=True, text=True,
    ).stdout
    try:
        return json.loads(salida or "{}", strict=False)
    except json.JSONDecodeError:
        return {}


def publico(url: str) -> str:
    return subprocess.run(["curl", "-s", url], capture_output=True, text=True).stdout


def retrato(proyecto: str, numero: str) -> dict:
    """Todo lo que debería ser idéntico entre ambientes."""
    sitio = f"https://{proyecto}.web.app"
    paquete = publico(f"{sitio}/main.dart.js")
    worker = publico(f"{sitio}/firebase-messaging-sw.js")
    config = publico(f"{sitio}/firebase-config.js")

    # El sello lo escribe scripts/sellar-version.sh al compilar. Es lo único de
    # todo este retrato que no se puede confundir: o los tres ambientes traen el
    # mismo commit, o no lo traen.
    try:
        sello = json.loads(publico(f"{sitio}/version.json") or "{}")
    except json.JSONDecodeError:
        sello = {}

    funciones = api(
        f"https://cloudfunctions.googleapis.com/v2/projects/{proyecto}"
        "/locations/us-central1/functions?pageSize=60"
    ).get("functions", [])
    jobs = api(
        f"https://cloudscheduler.googleapis.com/v1/projects/{proyecto}"
        "/locations/us-central1/jobs"
    ).get("jobs", [])
    alertas = api(
        f"https://monitoring.googleapis.com/v3/projects/{proyecto}/alertPolicies"
    ).get("alertPolicies", [])
    canales = api(
        f"https://monitoring.googleapis.com/v3/projects/{proyecto}/notificationChannels"
    ).get("notificationChannels", [])
    auth = api(f"https://identitytoolkit.googleapis.com/admin/v2/projects/{proyecto}/config")
    google = api(
        f"https://identitytoolkit.googleapis.com/admin/v2/projects/{proyecto}"
        "/defaultSupportedIdpConfigs/google.com"
    )
    bucket = api(f"https://storage.googleapis.com/storage/v1/b/{proyecto}.firebasestorage.app")
    servicios = api(
        f"https://serviceusage.googleapis.com/v1/projects/{numero}"
        "/services?filter=state:ENABLED&pageSize=200"
    ).get("services", [])
    indices = api(
        f"https://firestore.googleapis.com/v1/projects/{proyecto}"
        "/databases/(default)/collectionGroups/-/indexes"
    ).get("indexes", [])

    return {
        # ────────────────────────────────────────────────────────────────────
        # Esta fila vale por todas las demás. Va primero por eso.
        # ────────────────────────────────────────────────────────────────────
        #
        # Las otras comprueban que cada ambiente TENGA lo que debe. Esta
        # comprueba que los tres corran LO MISMO, que es otra pregunta y es la
        # que importaba el 29 de agosto de 2026, cuando desarrollo llevaba cinco
        # horas de retraso sobre QA y producción y esta herramienta dijo que los
        # tres estaban iguales.
        "Commit desplegado": (sello.get("commit") or "SIN SELLO")[:12],
        "Sellado desde copia limpia": sello.get("limpio", "?"),
        "Functions activas": f"{sum(1 for f in funciones if f.get('state') == 'ACTIVE')}/{len(funciones)}",
        "Cloud Scheduler": f"{len(jobs)} {jobs[0].get('state') if jobs else '-'}",
        "Alertas de operación": len(alertas),
        "Canales de aviso": len(canales),
        "Correo y contraseña": auth.get("signIn", {}).get("email", {}).get("enabled"),
        "Entrar con Google": google.get("enabled"),
        "Dominios autorizados": len(auth.get("authorizedDomains", [])),
        "authDomain propio": f"{proyecto}.web.app" in config,
        "Orígenes CORS": len((bucket.get("cors") or [{}])[0].get("origin", [])),
        "APIs habilitadas": len(servicios),
        "Índices de Firestore": len(indices),
        "Notifica con app cerrada": "if (!hayVisible)" not in worker,
        "Una sola notificación": worker.count("showNotification") == 1,
        "Envía instalacionId": "instalacionId" in paquete,
        "_apis": {s["config"]["name"] for s in servicios},
    }


def main() -> None:
    retratos = {et: retrato(p, n) for et, p, n in AMBIENTES}
    claves = [k for k in retratos["dev"] if not k.startswith("_")]

    print(f"  {'':<26} {'dev':<12} {'qa':<12} prd")
    print("  " + "-" * 62)

    diferencias = 0
    for clave in claves:
        valores = [str(retratos[e][clave]) for e in ("dev", "qa", "prd")]
        igual = valores[0] == valores[1] == valores[2]
        if not igual:
            diferencias += 1
        marca = "" if igual else "   <-- DIFIERE"
        print(f"  {clave:<26} {valores[0]:<12} {valores[1]:<12} {valores[2]:<12}{marca}")

    sin_sello = [e for e in ("dev", "qa", "prd")
                 if retratos[e]["Commit desplegado"] == "SIN SELLO"]
    if sin_sello:
        diferencias += 1
        print(f"\n  Sin sello de versión: {', '.join(sin_sello)}")
        print("  Ese ambiente se desplegó sin pasar por scripts/sellar-version.sh,")
        print("  así que no hay forma de saber qué código corre. Vuelve a desplegarlo.")

    sucios = [e for e in ("dev", "qa", "prd") if retratos[e]["Sellado desde copia limpia"] is False]
    if sucios:
        diferencias += 1
        print(f"\n  Desplegado desde una copia con cambios sin confirmar: {', '.join(sucios)}")
        print("  El commit del sello no describe lo que realmente se subió.")

    todas = set().union(*[retratos[e]["_apis"] for e in retratos])
    for e in ("dev", "qa", "prd"):
        faltan = sorted(todas - retratos[e]["_apis"])
        if faltan:
            diferencias += 1
            print(f"\n  APIs que le faltan a {e}:")
            for a in faltan:
                print(f"    · {a}")

    print()
    if diferencias == 0:
        print("  Los tres ambientes están iguales.")
    else:
        print(f"  {diferencias} diferencia(s). Cada una es un sitio donde una prueba")
        print("  puede pasar en un ambiente y fallar en otro.")
        sys.exit(1)


if __name__ == "__main__":
    main()
