# 06 — Guía de despliegue

**Versión:** 1.0 · 2 de agosto de 2026

Esta guía cubre desde la instalación de herramientas hasta tener una demostración funcionando
en un enlace público. Está escrita para que **cualquier persona pueda replicar el sistema
completo** siguiendo únicamente este documento (RNF-20).

---

## Orden recomendado

| Etapa | Qué se logra | Tiempo estimado |
|-------|--------------|-----------------|
| A | Herramientas instaladas en tu equipo | 30–45 min |
| B | Repositorio local y en GitHub | 15 min |
| C | Proyectos de Firebase creados y configurados | 30 min |
| D | Ejecución local con emuladores, sin tocar la nube | 15 min |
| E | Despliegue a desarrollo y demostración accesible | 20 min |
| F | Ambientes QA y producción | 30 min |

**Haz A, B, C y D antes de desplegar nada a la nube.** Tal como pediste, la copia local
funciona primero.

---

## Etapa A — Herramientas en tu equipo

### A.1 Requisitos

| Herramienta | Versión mínima | Para qué |
|-------------|:---:|----------|
| Git | 2.40 | Control de versiones |
| Node.js | 20 LTS | Cloud Functions e interfaz de línea de comandos de Firebase |
| Flutter SDK | 3.24 (referencia: 3.44) | Aplicación web y futura compilación nativa |
| Java JDK | 17 | Requerido por los emuladores de Firebase |
| Firebase CLI | 13 | Despliegue y emuladores |
| Un editor | — | VS Code con las extensiones de Flutter y Dart |

### A.2 Instalación

**Windows (PowerShell como administrador):**

```powershell
winget install --id Git.Git -e
winget install --id OpenJS.NodeJS.LTS -e
winget install --id Microsoft.OpenJDK.17 -e
# Flutter: descargar el zip de flutter.dev, descomprimir en C:\src\flutter
# y agregar C:\src\flutter\bin al PATH del sistema
npm install -g firebase-tools
```

**macOS:**

```bash
brew install git node@20 openjdk@17
brew install --cask flutter
npm install -g firebase-tools
```

**Linux (Ubuntu/Debian):**

```bash
sudo apt update && sudo apt install -y git curl unzip openjdk-17-jdk
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
sudo snap install flutter --classic
npm install -g firebase-tools
```

### A.3 Verificación

```bash
git --version          # >= 2.40
node --version         # v20.x
java -version          # 17.x
flutter --version      # >= 3.24
firebase --version     # >= 13
flutter doctor         # todo en verde salvo lo relativo a Android/iOS
```

> `flutter doctor` marcará en rojo las herramientas de Android Studio y Xcode. **Para este
> proyecto no importa**, porque compilamos a web. Solo harían falta si más adelante se activa
> el plan de contingencia del documento 02, sección 13.

Habilita el objetivo web una sola vez:

```bash
flutter config --enable-web
```

---

## Etapa B — Repositorio local y en GitHub

### B.1 Crear el repositorio en GitHub

1. Entra a `https://github.com/new`.
2. Nombre: `sian-notificaciones-catedraticos`.
3. Visibilidad: **Público** (requisito del proyecto).
4. Marca «Add a README file» y elige la licencia MIT.
5. Crea el repositorio.

### B.2 Clonar y preparar la estructura local

```bash
cd ~/proyectos                     # o la carpeta que prefieras
git clone https://github.com/<tu-usuario>/sian-notificaciones-catedraticos.git sian
cd sian

git checkout -b develop
git push -u origin develop
```

Copia dentro de la carpeta `sian/` los documentos de `docs/` que ya tienes, y crea el
`.gitignore` **antes de cualquier otra cosa**:

```gitignore
# Secretos — jamás se versionan (RES-10, RNF-10)
.env
.env.local
.env.*.local
**/serviceAccountKey.json
**/google-services.json
**/GoogleService-Info.plist
.firebaserc

# Flutter
app/build/
app/.dart_tool/
app/.flutter-plugins*
app/lib/firebase_options.dart

# Node
functions/node_modules/
functions/lib/
node_modules/

# Emuladores y registros
firebase-debug.log
firestore-debug.log
ui-debug.log
.firebase/
emulator-data/

# Sistema operativo y editor
.DS_Store
Thumbs.db
.idea/
.vscode/settings.json
```

> **`.firebaserc` va ignorado a propósito.** Contiene los identificadores reales de tus
> proyectos. En su lugar se versiona `.firebaserc.example`, con marcadores de posición, para
> que quien replique el proyecto ponga los suyos.

### B.3 Proteger las ramas

En GitHub, en Settings → Branches, agrega reglas de protección para `main` y `develop`:
exigir pull request antes de fusionar, y exigir que la verificación de integración continua
pase.

### B.4 Primer commit

```bash
git add .
git commit -m "docs: linea base de requerimientos, arquitectura y diagramas

Incluye SRS, arquitectura, modelo de datos, diagramas de flujo y
secuencia, guia de despliegue, deuda tecnica y plan de iteraciones.
Refs: fase-0"
git push
```

---

## Etapa C — Proyectos de Firebase

### C.1 Crear los tres proyectos

En `https://console.firebase.google.com`, crea **tres proyectos separados**:

| Alias | Proyecto | Creado |
|-------|----------|--------|
| `dev` | `sian-umg-bdm-dev` | 3 de agosto de 2026 |
| `qa` | `sian-umg-bdm-qa` | 24 de agosto de 2026 |
| `prod` | `sian-umg-bdm` | 24 de agosto de 2026 |

> Los tres ya existen. El estado de cada uno, sus URL y quién tiene acceso están en el
> [documento 11](11-ambientes.md); esta etapa queda como el procedimiento a seguir si
> hubiera que rehacer un ambiente desde cero.

Desactiva Google Analytics en `dev` y `qa`; actívalo solo en `prod` si lo consideras útil.

### C.2 Activar el plan Blaze

Necesario para Cloud Functions, Cloud Storage y Cloud Scheduler.

1. En la consola de Firebase, ve a **Configuración → Uso y facturación → Detalles y
   configuración**.
2. Selecciona **Blaze — Pago por uso** y vincula una cuenta de facturación.
3. **Antes de seguir**, fija una alerta de presupuesto. No es opcional (RNF-18).
4. En Google Cloud Console → Billing → Budgets, agrega tu correo como destinatario.

> Una sola cuenta de facturación sirve a los tres ambientes, y el presupuesto se define
> sobre la cuenta, no sobre cada proyecto: un único aviso cubre dev, QA y producción.
> El que está puesto es de **10 USD mensuales**, con avisos al 50 %, 90 %, 100 % y al
> 100 % proyectado. El desglose del consumo real medido está en el documento 11,
> sección 5.

> Con el consumo proyectado en el documento 05, sección 7, el costo esperado es **0.00 USD**.
> La alerta existe para enterarte de inmediato si algo se comporta distinto a lo previsto.

### C.3 Habilitar los servicios en cada proyecto

**Authentication**
- Ve a Authentication → Sign-in method.
- Habilita **Google**: define el nombre público del proyecto y el correo de soporte.
- Habilita **Correo electrónico/contraseña**. No habilites el enlace mágico por ahora.
- En Settings → Authorized domains, agrega los dominios donde se servirá la aplicación.

**Firestore Database**
- Crea la base de datos en modo **producción** (nunca en modo de prueba, ni siquiera en dev).
- Ubicación: elige la región más cercana a tus usuarios y **anótala: no se puede cambiar
  después**. Para Guatemala, `us-central1` o `southamerica-east1`.

**Storage**
- Comienza en modo producción, misma región que Firestore.

**Cloud Messaging**
- Ve a Configuración del proyecto → Cloud Messaging → Web configuration.
- Pulsa **Generate key pair** para obtener la clave **VAPID**. Cópiala: la necesitarás en
  `.env.local`.

**Hosting**
- Se configura desde la línea de comandos en la etapa E.

### C.4 Vincular los alias localmente

```bash
firebase login
firebase use --add        # elige sian-umg-bdm-dev, alias: dev
firebase use --add        # elige sian-umg-bdm-qa, alias: qa
firebase use --add        # elige sian-umg-bdm, alias: prod
firebase use dev          # trabaja en desarrollo por omisión
```

### C.5 Configuración de la aplicación

```bash
dart pub global activate flutterfire_cli
cd app
flutterfire configure --project=sian-umg-bdm-dev --platforms=web
```

Esto genera `app/lib/firebase_options.dart`, que **está en el `.gitignore`** por contener
identificadores de tu proyecto. Cada persona que replique el proyecto genera el suyo.

> **Alternativa sin interacción.** `flutterfire configure` es interactivo y exige estar
> autenticado contra el proyecto, lo que no sirve en un runner de integración continua ni
> cuando se automatiza la réplica. Para esos casos:
>
> ```bash
> firebase apps:sdkconfig WEB <appId> --project sian-umg-bdm-dev   # obtener los valores
> bash scripts/generar-firebase-options.sh                          # generar el archivo
> ```
>
> El script lee `.env.local`, o las variables de entorno si vienen dadas. Sin valores genera
> marcadores de posición: el código compila y las pruebas pasan, pero la aplicación no puede
> conectarse a nada. Es justo lo que se quiere en integración continua, donde un runner con
> acceso real a Firebase sería un problema, no una ventaja.

Crea `.env.local` en la raíz (ignorado por git):

```bash
FIREBASE_VAPID_KEY=BN...tu_clave_vapid_publica
FIREBASE_PROJECT_ID=sian-umg-bdm-dev
ZONA_HORARIA=America/Guatemala
```

Y versiona `.env.example` con las mismas llaves vacías y un comentario que explique cada una.

> **`FIREBASE_AUTH_DOMAIN` debe quedarse en `.firebaseapp.com`. No lo cambies solo.**
>
> Es tentador apuntarlo a `<proyecto>.web.app`, que es de donde se sirve el sitio: dejaría todo
> el flujo de Google en un único origen y evitaría que Safari lo trate como un tercero. **Y
> Hosting sirve el manejador `/__/auth/` en todos los dominios del proyecto, así que parece que
> basta con cambiarlo.** No basta, y el fallo es total:
>
> ```
> Error 400: redirect_uri_mismatch
> ```
>
> Firebase crea en Google Cloud un cliente de OAuth que autoriza **un solo** redirector, el de
> `.firebaseapp.com`. Al cambiar el dominio, la aplicación pide uno que ese cliente no conoce y
> Google bloquea el acceso por completo — peor que el problema que se quería resolver.
>
> Que el manejador responda no significa que Google lo acepte; son dos comprobaciones
> distintas y solo la primera se puede hacer con `curl`:
>
> ```bash
> curl -s -o /dev/null -w "%{http_code}\n" https://sian-umg-bdm-dev.web.app/__/auth/handler
> ```
>
> Para cambiarlo de verdad hay que **añadir antes** el redirector nuevo al cliente de OAuth, en
> Google Cloud → APIs y servicios → Credenciales → el cliente web de Firebase → URI de
> redireccionamiento autorizados:
>
> ```
> https://sian-umg-bdm-dev.web.app/__/auth/handler
> ```
>
> Y solo después tocar `FIREBASE_AUTH_DOMAIN`. Mientras no se haga ese paso en la consola, el
> valor correcto es el que da Firebase:
>
> ```bash
> FIREBASE_AUTH_DOMAIN=sian-umg-bdm-dev.firebaseapp.com
> ```

> **CORS del bucket: se aplica aparte, y sin esto las imágenes no se ven.**
>
> Flutter web descarga los bytes de una imagen con `fetch` para decodificarla, y el navegador
> bloquea esa descarga si el bucket no declara CORS. La nota de voz sí funciona, porque un
> elemento `<audio>` reproduce sin pedir permiso de origen. El síntoma resultante despista
> mucho: **la voz se escucha y la imagen no**, y parece un problema de la imagen o de la red.
>
> No lo despliega `firebase deploy`: la configuración vive en el bucket, no en
> `storage.rules`. Se aplica una vez por ambiente:
>
> ```bash
> bash scripts/aplicar-cors-storage.sh sian-umg-bdm-dev
> ```
>
> Y se comprueba así — sin `access-control-allow-origin` en la respuesta, no hay imágenes:
>
> ```bash
> curl -sI -H 'Origin: https://sian-umg-bdm-dev.web.app' '<url-de-descarga>' | grep -i access-control
> ```

---

## Etapa D — Ejecución local con emuladores

**Aquí es donde tienes tu copia local funcionando sin tocar la nube ni gastar un centavo.**

### D.1 Inicializar los emuladores

```bash
cd ~/proyectos/sian
firebase init emulators
```

Selecciona: Authentication, Firestore, Functions, Storage y Hosting. Acepta los puertos por
omisión y activa la interfaz gráfica de emuladores.

### D.2 Instalar dependencias

```bash
cd functions && npm install && cd ..
cd app && flutter pub get && cd ..
```

### D.3 Levantar todo

Terminal 1 — emuladores:

```bash
firebase emulators:start --import=./emulator-data --export-on-exit=./emulator-data
```

La interfaz de emuladores queda en `http://localhost:4000`. El parámetro `--import/--export`
conserva tus datos de prueba entre reinicios, lo que ahorra muchísimo tiempo.

Terminal 2 — aplicación Flutter apuntando a los emuladores:

```bash
cd app
flutter run -d chrome --web-port=5000 --dart-define=USE_EMULATOR=true
```

### D.4 Sembrar datos de prueba

```bash
npx tsx scripts/seed-dev.ts
```

El script crea: un coordinador, dos administradoras, diez catedráticos ficticios, dos grupos
y tres mensajes de ejemplo en distintos estados.

### D.5 Limitación importante del entorno local

Los emuladores **no envían notificaciones push reales**. Firebase Cloud Messaging no tiene
emulador. En local puedes probar todo lo demás —autenticación, reglas, lógica de recurrencia,
transacciones, bitácora—, pero la llegada real de la notificación al dispositivo solo se
verifica desplegando a `dev`.

Por eso el orden de trabajo es: **lógica en local, notificaciones en `dev`**.

### D.6 Antes de cada push

```bash
cd app && flutter analyze && flutter test && cd ..
cd functions && npm run lint && npm test && cd ..
firebase emulators:exec --only firestore "npm --prefix functions run test:rules"
```

---

## Etapa E — Despliegue a desarrollo y demostración funcionando

### E.1 Compilar la aplicación web

```bash
cd app
flutter build web --release \
  --dart-define=FIREBASE_VAPID_KEY=$FIREBASE_VAPID_KEY \
  --dart-define=USE_EMULATOR=false
cd ..
```

### E.2 Configurar `firebase.json`

```jsonc
{
  "hosting": {
    "public": "app/build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [{ "source": "**", "destination": "/index.html" }],
    "headers": [
      {
        "source": "/firebase-messaging-sw.js",
        "headers": [
          { "key": "Cache-Control", "value": "no-cache, no-store, must-revalidate" },
          { "key": "Service-Worker-Allowed", "value": "/" }
        ]
      }
    ]
  },
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "storage": { "rules": "storage.rules" },
  "functions": [{ "source": "functions", "codebase": "default", "runtime": "nodejs20" }]
}
```

> El encabezado `no-cache` sobre el service worker de mensajería no es un detalle menor: sin
> él, los navegadores sirven una versión vieja del archivo y las notificaciones dejan de
> funcionar tras una actualización, sin ningún error visible. Es una de las causas más
> frecuentes de fallo en este tipo de aplicaciones.

### E.3 Desplegar

```bash
firebase use dev

firebase deploy --only firestore:rules,firestore:indexes,storage
firebase deploy --only functions
firebase deploy --only hosting
```

Al terminar obtienes la URL de la demostración:
`https://sian-umg-bdm-dev.web.app`

### E.4 Crear el job de Cloud Scheduler

Este paso se hace **una sola vez por ambiente**. Si defines la función con
`onSchedule` del SDK de Firebase Functions v2, el job se crea automáticamente al desplegar.
Si prefieres crearlo a mano:

```bash
gcloud scheduler jobs create http sian-despachador-dev \
  --project=sian-umg-bdm-dev \
  --location=us-central1 \
  --schedule="* * * * *" \
  --time-zone="America/Guatemala" \
  --uri="https://us-central1-sian-umg-bdm-dev.cloudfunctions.net/despachador" \
  --http-method=POST \
  --oidc-service-account-email=sian-umg-bdm-dev@appspot.gserviceaccount.com
```

Verifica que solo exista **un job por proyecto**:

```bash
gcloud scheduler jobs list --project=sian-umg-bdm-dev --location=us-central1
```

> **Vigila este número.** Tres jobs en total —uno por ambiente— es la cuota gratuita completa.
> El cuarto job empieza a costar (RES-04).

### E.5 Sembrar el primer coordinador

Como la lista blanca controla el acceso y aún está vacía, nadie podría entrar. Siembra tu
propio correo:

```bash
npx tsx scripts/seed-invitacion.ts --correo=eua031989@gmail.com --rol=COORDINADOR --proyecto=sian-umg-bdm-dev
```

### E.6 Lista de verificación de la demostración

Recorre esta lista en un teléfono real, no en el emulador del navegador:

- [ ] Abro `https://sian-umg-bdm-dev.web.app` en Chrome en Android e inicio sesión con Google
- [ ] El sistema me reconoce como Coordinador y muestra el panel
- [ ] Instalo la aplicación en la pantalla de inicio y llega la notificación de prueba
- [ ] Repito lo anterior en Safari en iPhone: **instalar en la pantalla de inicio es
      obligatorio**
- [ ] Creo un aviso informativo de solo texto y lo envío de inmediato
- [ ] La notificación llega al teléfono con la aplicación cerrada
- [ ] Creo una alerta urgente con nota de voz e imagen y verifico la doble confirmación
- [ ] La alerta llega con sonido y vibración en Android
- [ ] Reproduzco la nota de voz y veo la imagen en el detalle
- [ ] Marco un mensaje como «requiere confirmación», confirmo desde el teléfono y lo veo
      reflejado en el panel en tiempo real
- [ ] Programo un mensaje para dentro de 3 minutos y compruebo que llega puntual
- [ ] Creo un recurrente cada 2 minutos con fin en 10 minutos y verifico las 5 ocurrencias
- [ ] Cancelo un mensaje programado y compruebo que no se envía
- [ ] Reviso la bitácora y confirmo que cada acción anterior dejó su asiento
- [ ] **Prueba de resistencia iOS (riesgo R-01):** envío 20 notificaciones consecutivas a un
      iPhone durante 24 horas y verifico que siguen llegando todas

> El último punto es el más importante de toda la lista. Si falla, se activa el plan de
> contingencia del documento 02, sección 13, y hay que saberlo antes de prometer nada al
> coordinador académico.

---

## Etapa F — Ambientes de QA y producción

### F.1 Integración y despliegue continuos

`.github/workflows/deploy.yml` — esquema:

```yaml
name: Despliegue
on:
  push:
    branches: [qa, main]

jobs:
  qa:
    if: github.ref == 'refs/heads/qa'
    runs-on: ubuntu-latest
    environment: qa
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.24.x' }
      - run: cd app && flutter pub get && flutter analyze && flutter test
      - run: cd app && flutter build web --release
          --dart-define=FIREBASE_VAPID_KEY=${{ secrets.QA_VAPID_KEY }}
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.QA_SERVICE_ACCOUNT }}
          projectId: ${{ vars.QA_PROJECT_ID }}
          channelId: live

  produccion:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: produccion      # con aprobación manual obligatoria
    steps: [ ... equivalente, apuntando a ${{ vars.PROD_PROJECT_ID }} ... ]
```

En GitHub → Settings → Environments, crea el ambiente `produccion` y marca **Required
reviewers** con tu usuario. Así ningún despliegue a producción ocurre sin tu aprobación
explícita.

### F.2 Secretos que debes cargar en GitHub

| Secreto | De dónde sale |
|---------|---------------|
| `QA_VAPID_KEY` / `PROD_VAPID_KEY` | Consola de Firebase → Cloud Messaging → Web configuration |

> **`QA_PROJECT_ID` y `PROD_PROJECT_ID` van a nivel de repositorio**, no dentro del
> *environment*: el `if:` del job se evalúa antes de que GitHub aplique el ambiente, y
> ahí una variable de ambiente se lee vacía y el job se salta sin dar error. El detalle
> está en el documento 11, sección 6.
| `QA_SERVICE_ACCOUNT` / `PROD_SERVICE_ACCOUNT` | Consola de Firebase → Configuración → Cuentas de servicio → Generar nueva clave privada (contenido JSON completo) |

Nunca los pegues en un archivo del repositorio, ni siquiera temporalmente: el historial de
git conserva todo.

### F.3 Antes de habilitar producción

- [ ] Los tres proyectos de Firebase tienen alerta de presupuesto de 1 USD
- [ ] Existen exactamente 3 jobs de Cloud Scheduler en total
- [ ] Las pruebas de reglas de seguridad pasan en la integración continua
- [ ] Se ejecutó el simulacro con al menos 10 dispositivos reales
- [ ] La lista blanca de correos institucionales está cargada y verificada
- [ ] El branding institucional está aplicado
- [ ] `main` está protegida y `produccion` exige aprobación
- [ ] El documento de deuda técnica está actualizado
- [ ] Se verificó que no hay secretos en el historial de git

```bash
# Verificación de secretos filtrados
npx @secretlint/quick-start "**/*"
git log -p | grep -iE "AIza|-----BEGIN|serviceAccount" || echo "Sin secretos aparentes"
```

---

## Anexo — Solución de problemas frecuentes

| Síntoma | Causa probable | Solución |
|---------|----------------|----------|
| Error 404 al registrar el service worker | Flutter genera su propio `flutter_service_worker.js` que interfiere | Mantener `firebase-messaging-sw.js` como archivo independiente en `web/`; nunca fusionar la lógica |
| Las notificaciones llegan con la aplicación abierta pero no cerrada | El manejador de segundo plano no está en el service worker | Implementar `onBackgroundMessage` dentro de `firebase-messaging-sw.js` |
| En iOS no llega ninguna notificación | La aplicación no está instalada en la pantalla de inicio, o iOS es anterior a 16.4 | Instructivo de instalación obligatorio (documento 03, sección 3) |
| En iOS dejan de llegar tras varios envíos | Riesgo R-01, conocido y reportado por la comunidad | Refrescar el token en cada apertura; si persiste, activar el plan de contingencia |
| `firebase deploy --only functions` falla por facturación | El proyecto sigue en plan Spark | Activar Blaze (etapa C.2) |
| El token de sesión no trae el rol | Los custom claims se sembraron después de emitir el token | Llamar a `getIdToken(forceRefresh: true)` después de asignar el rol |
| El despachador no dispara nada | El job de Cloud Scheduler no existe o apunta a la URL equivocada | `gcloud scheduler jobs list` y verificar la URI |
| Firestore rechaza una consulta por falta de índice | El índice compuesto no está declarado | Copiar el enlace del mensaje de error, o agregarlo a `firestore.indexes.json` y desplegar |
| Todo funciona en local pero falla al desplegar | Los emuladores no aplican las reglas con la misma severidad si se usó modo de prueba | Ejecutar siempre las pruebas de reglas contra el emulador antes de desplegar |
