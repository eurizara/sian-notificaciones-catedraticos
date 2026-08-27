#!/usr/bin/env python3
"""SIAN — Alertas de operación sobre el despachador (paga parte de DT-07).

    TOKEN=$(gcloud auth print-access-token) \
      python3 scripts/configurar-alertas.py sian-umg-bdm-dev

Es idempotente: se puede correr las veces que haga falta. Busca por nombre lo
que ya exista y lo actualiza en lugar de duplicarlo.

─────────────────────────────────────────────────────────────────────────────
Por qué hacen falta DOS alertas y no una
─────────────────────────────────────────────────────────────────────────────

El despachador es la función que corre cada minuto y dispara los mensajes
programados y recurrentes. Es lo que hace que un aviso salga solo el martes a
las 7:00 sin que nadie esté ahí.

Puede dejar de funcionar de dos maneras que no se parecen en nada:

  · Falla.    Se ejecuta y revienta. Deja errores contables, y una alerta por
              tasa de error los ve.

  · Se calla. No se ejecuta —murió, o murió el reloj de Cloud Scheduler que lo
              despierta—. **No produce ningún error**, porque no produce nada.
              Una alerta por tasa de error miraría un cero y lo daría por bueno.

El segundo caso es el peor y el más silencioso, y es exactamente contra lo que
existe DT-07: «si el despachador falla, nadie se entera hasta que alguien lo
nota». Por eso la alerta de ausencia importa más que la de errores.

─────────────────────────────────────────────────────────────────────────────
Los umbrales
─────────────────────────────────────────────────────────────────────────────

El despachador corre 60 veces por hora, así que un fallo suelto es ruido
normal: una alerta que salte con el primero enseña a ignorarla, y una alerta
que se ignora no sirve de nada.

  · Errores:  más de 5 ejecuciones fallidas en 10 minutos. La mitad de los
              intentos de esa ventana: está roto, no tuvo un mal momento.
  · Silencio: ninguna ejecución en 15 minutos. Corre cada minuto, de modo que
              quince de silencio no admiten otra lectura.
"""

import json
import os
import subprocess
import sys

CORREO_AVISOS = "eurizara1@miumg.edu.gt"

METRICA = "cloudfunctions.googleapis.com/function/execution_count"
FUNCION = "despachador"

BASE_FILTRO = (
    f'metric.type="{METRICA}" AND resource.type="cloud_function" '
    f'AND resource.labels.function_name="{FUNCION}"'
)


def token() -> str:
    """El de la variable TOKEN, o el de gcloud si está a mano."""
    if os.environ.get("TOKEN"):
        return os.environ["TOKEN"].strip()
    try:
        return subprocess.run(
            ["gcloud", "auth", "print-access-token"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        sys.exit(
            "error: hace falta un token de acceso.\n"
            "       TOKEN=$(gcloud auth print-access-token) python3 "
            "scripts/configurar-alertas.py <proyecto>"
        )


def api(metodo: str, url: str, cuerpo=None):
    """Llama a la API de Cloud Monitoring.

    Se usa `curl` y no `urllib` a propósito: `urllib` valida los certificados
    contra el almacén que traiga el propio Python, y una instalación de
    python.org en macOS llega sin ninguno. El script fallaba con
    CERTIFICATE_VERIFY_FAILED en una máquina perfectamente sana. `curl` usa el
    almacén del sistema, que sí está donde tiene que estar.
    """
    orden = [
        "curl", "-s", "-X", metodo,
        "-H", f"Authorization: Bearer {TOKEN}",
        "-H", "Content-Type: application/json",
    ]
    if cuerpo is not None:
        orden += ["-d", json.dumps(cuerpo)]
    orden.append(url)

    salida = subprocess.run(orden, capture_output=True, text=True).stdout
    try:
        respuesta = json.loads(salida or "{}")
    except json.JSONDecodeError:
        sys.exit(f"respuesta ilegible de {url.split('/v3/')[-1]}:\n  {salida[:300]}")

    if isinstance(respuesta, dict) and "error" in respuesta:
        e = respuesta["error"]
        sys.exit(
            f"error {e.get('code')} en {metodo} {url.split('/v3/')[-1]}\n"
            f"  {e.get('message', '')[:400]}"
        )
    return respuesta


def canal(proyecto: str, ambiente: str) -> str:
    """Crea o reutiliza el canal de correo. Devuelve su nombre completo."""
    raiz = f"https://monitoring.googleapis.com/v3/projects/{proyecto}"
    etiqueta = f"SIAN · avisos de operación ({ambiente})"

    existentes = api("GET", f"{raiz}/notificationChannels").get("notificationChannels", [])
    for c in existentes:
        if c.get("labels", {}).get("email_address") == CORREO_AVISOS:
            print(f"  canal ya existía · verificado: {c.get('verificationStatus')}")
            return c["name"]

    creado = api("POST", f"{raiz}/notificationChannels", {
        "type": "email",
        "displayName": etiqueta,
        "description": "Avisos de que el despachador dejó de funcionar (DT-07).",
        "labels": {"email_address": CORREO_AVISOS},
        "enabled": True,
    })
    print(f"  canal creado → {CORREO_AVISOS} · verificado: {creado.get('verificationStatus')}")
    return creado["name"]


def politica(proyecto: str, ambiente: str, canal_nombre: str, definicion: dict) -> None:
    """Crea la política, o la reescribe si ya estaba."""
    raiz = f"https://monitoring.googleapis.com/v3/projects/{proyecto}"
    definicion = {
        **definicion,
        "combiner": "OR",
        "enabled": True,
        "notificationChannels": [canal_nombre],
        # Se cierra sola al día si el problema se resolvió, para no dejar
        # incidentes abiertos que nadie va a ir a cerrar a mano.
        "alertStrategy": {"autoClose": "86400s"},
    }
    definicion["displayName"] = f"{definicion['displayName']} · {ambiente}"

    existentes = api("GET", f"{raiz}/alertPolicies").get("alertPolicies", [])
    for p in existentes:
        if p["displayName"] == definicion["displayName"]:
            api("PATCH", f"https://monitoring.googleapis.com/v3/{p['name']}"
                         "?updateMask=conditions,notificationChannels,documentation,"
                         "alertStrategy,combiner,enabled", definicion)
            print(f"  política actualizada: {definicion['displayName']}")
            return

    api("POST", f"{raiz}/alertPolicies", definicion)
    print(f"  política creada: {definicion['displayName']}")


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit("Uso: python3 scripts/configurar-alertas.py <proyecto>")

    proyecto = sys.argv[1]
    ambiente = {
        "sian-umg-bdm-dev": "desarrollo",
        "sian-umg-bdm-qa": "calidad",
        "sian-umg-bdm": "PRODUCCIÓN",
    }.get(proyecto, proyecto)

    print(f"{proyecto} ({ambiente})")
    canal_nombre = canal(proyecto, ambiente)

    politica(proyecto, ambiente, canal_nombre, {
        "displayName": "SIAN · el despachador está fallando",
        "documentation": {
            "mimeType": "text/markdown",
            "content": (
                f"El despachador de **{ambiente}** está fallando más de la mitad "
                "de las veces que se ejecuta.\n\n"
                "Mientras dure, **los mensajes programados y recurrentes no "
                "salen**. Los inmediatos sí: esos no pasan por aquí.\n\n"
                "Qué mirar, en este orden:\n\n"
                f"1. Los registros de la función `{FUNCION}` en la consola de "
                "Google Cloud, que dicen con qué está reventando.\n"
                "2. La colección `cola_despacho` en Firestore: si creció y no "
                "baja, confirma que nada se está despachando.\n"
                "3. La pantalla de Programados en el panel, para ver qué avisos "
                "quedaron sin salir y reprogramarlos si hace falta.\n"
            ),
        },
        "conditions": [{
            "displayName": "más de 5 ejecuciones con error en 10 minutos",
            "conditionThreshold": {
                "filter": f'{BASE_FILTRO} AND metric.labels.status!="ok"',
                "aggregations": [{
                    "alignmentPeriod": "600s",
                    "perSeriesAligner": "ALIGN_SUM",
                    "crossSeriesReducer": "REDUCE_SUM",
                }],
                "comparison": "COMPARISON_GT",
                "thresholdValue": 5,
                "duration": "0s",
                "trigger": {"count": 1},
            },
        }],
    })

    politica(proyecto, ambiente, canal_nombre, {
        "displayName": "SIAN · el despachador dejó de correr",
        "documentation": {
            "mimeType": "text/markdown",
            "content": (
                f"El despachador de **{ambiente}** lleva 15 minutos sin "
                "ejecutarse **ni una sola vez**. Corre cada minuto, así que "
                "esto no admite otra lectura.\n\n"
                "Es la avería más silenciosa del sistema: una función que no "
                "corre no produce errores, así que nada más la delata. "
                "Mientras dure, **los mensajes programados y recurrentes no "
                "salen**.\n\n"
                "Las dos causas posibles, y se distinguen rápido:\n\n"
                f"1. **La función murió.** Mirá `{FUNCION}` en Cloud Functions: "
                "si no está o está en error, hay que volver a desplegarla.\n"
                "2. **El reloj murió.** Mirá el job de Cloud Scheduler "
                f"`firebase-schedule-{FUNCION}-us-central1`: si está pausado o "
                "borrado, la función está sana pero nadie la despierta.\n\n"
                "Después, revisá `cola_despacho` y la pantalla de Programados "
                "para ver qué quedó sin salir.\n"
            ),
        },
        "conditions": [{
            "displayName": "ninguna ejecución en 15 minutos",
            "conditionAbsent": {
                "filter": BASE_FILTRO,
                "aggregations": [{
                    "alignmentPeriod": "300s",
                    "perSeriesAligner": "ALIGN_SUM",
                    "crossSeriesReducer": "REDUCE_SUM",
                }],
                "duration": "900s",
                "trigger": {"count": 1},
            },
        }],
    })


TOKEN = token()

if __name__ == "__main__":
    main()
