# 11 · Ambientes

Referencia de qué ambientes existen, para qué sirve cada uno, quién entra y por dónde
se despliega. Es el documento que hay que abrir antes de tocar cualquier cosa que se
publique.

El procedimiento paso a paso para crear un ambiente desde cero está en el
[documento 06](06-guia-despliegue.md). Aquí está el resultado.

---

## 1 · Los tres ambientes

| | Desarrollo | Calidad (QA) | Producción |
|---|---|---|---|
| Proyecto | `sian-umg-bdm-dev` | `sian-umg-bdm-qa` | `sian-umg-bdm` |
| Número | 863854823370 | 186815040849 | 199298701333 |
| Aplicación | https://sian-umg-bdm-dev.web.app | https://sian-umg-bdm-qa.web.app | https://sian-umg-bdm.web.app |
| Manual general | [/manuales/](https://sian-umg-bdm-dev.web.app/manuales/) | [/manuales/](https://sian-umg-bdm-qa.web.app/manuales/) | /manuales/ |
| Manual del catedrático | [/manuales/catedratico/](https://sian-umg-bdm-dev.web.app/manuales/catedratico/) | [/manuales/catedratico/](https://sian-umg-bdm-qa.web.app/manuales/catedratico/) | /manuales/catedratico/ |
| Consola | [abrir](https://console.firebase.google.com/project/sian-umg-bdm-dev/overview) | [abrir](https://console.firebase.google.com/project/sian-umg-bdm-qa/overview) | [abrir](https://console.firebase.google.com/project/sian-umg-bdm/overview) |
| Se despliega | a mano | al fusionar a `develop` | al fusionar a `main`, con aprobación |
| Datos | de prueba, acumulados | limpio desde el 24-08-2026 | vacío |
| Estado | en uso | **certificado y en línea desde el 24-08-2026** | aprovisionado, sin publicar |

Los tres cuelgan de la organización `miumg.edu.gt` (id 372264284580) y comparten una
sola cuenta de facturación. El código es idéntico en los tres: lo único que cambia son
los identificadores del proyecto, que entran al compilar por `--dart-define` y por
`firebase_options.dart` (RNF-10).

Ningún dato se copia entre ambientes. QA no es una réplica de desarrollo: nace vacío.

---

## 2 · Quién entra a cada ambiente

El acceso no lo da tener una cuenta de Google: lo da estar en la colección
`invitaciones`, que es la lista blanca institucional (RF-AUT-03). Quien no está en ella
no pasa de la pantalla de ingreso, aunque su correo sea válido.

En QA la lista blanca tiene exactamente dos entradas:

| Correo | Rol | Puede |
|---|---|---|
| `eua031989@gmail.com` | COORDINADOR | crear y programar mensajes, ver entregas, administrar usuarios y grupos |
| `eurizara1@miumg.edu.gt` | CATEDRATICO | recibir mensajes, abrirlos, confirmar lectura |

Para agregar a alguien más a QA:

```bash
ARCHIVO_ENTORNO=$PWD/.env.qa.local npm run seed:invitacion -- --correo=alguien@miumg.edu.gt --rol=CATEDRATICO --proyecto=sian-umg-bdm-qa
```

Producción tiene la lista blanca **vacía a propósito**. Sembrar la primera invitación
ahí es el acto que abre el sistema a gente real, y se hace deliberadamente el día de la
salida a producción, no antes.

---

## 3 · Configuración por ambiente

Los identificadores de cada proyecto viven en archivos que **no se versionan**, porque
apuntan a un proyecto concreto:

| Archivo | Ambiente | En el repositorio |
|---|---|---|
| `.env.local` | desarrollo | ignorado |
| `.env.qa.local` | calidad | ignorado |
| `.env.prod.local` | producción | ignorado |

Los valores de una app web de Firebase son públicos por diseño —viajan al navegador
dentro del paquete compilado—, así que no son credenciales secretas. Lo que protege los
datos son las reglas de seguridad y los custom claims (documento 05, sección 5).

Para compilar contra un ambiente distinto al de la copia local:

```bash
ARCHIVO_ENTORNO=$PWD/.env.qa.local bash scripts/generar-firebase-options.sh
```

El orden de precedencia del script es: variables ya exportadas en el entorno, luego
`ARCHIVO_ENTORNO`, y por último `.env.local`. Ese orden importa. Hasta el 24 de agosto
de 2026 el script cargaba `.env.local` siempre, pisando lo que se hubiera exportado:
quien intentaba compilar QA obtenía, sin ningún aviso, un paquete apuntando a
desarrollo. Con tres ambientes vivos ese descuido escribe datos en el proyecto
equivocado.

---

## 4 · Lo que hay que hacer una vez por ambiente y no lo hace `firebase deploy`

Tres cosas se olvidan siempre porque no viajan en el despliegue:

**La clave VAPID.** Se genera a mano en Consola de Firebase → Configuración del
proyecto → Cloud Messaging → Web Push certificates → *Generate key pair*. Es por
proyecto. Sin ella el navegador no puede registrarse para recibir notificaciones, y la
aplicación funciona en todo lo demás: se entra, se leen y se envían mensajes, pero nunca
suena nada. El fallo no da error visible, así que es fácil creer que las notificaciones
están rotas cuando lo que falta es la clave.

**El proveedor de Google.** Se habilita en Authentication → Sign-in method → Google.
Ese clic crea el cliente OAuth; la API no lo crea sola. Sin él, el botón «Entrar con
Google» aparece en pantalla y falla al pulsarlo.

**El CORS del bucket.** Se aplica con `scripts/aplicar-cors-storage.sh <proyecto>`. Vive
en el bucket, no en `storage.rules`, así que `firebase deploy` no lo toca. Sin CORS las
imágenes adjuntas no se pintan y las notas de voz sí: Flutter descarga los bytes de una
imagen con `fetch` y el navegador los bloquea, mientras que un `<audio>` reproduce sin
pedir permiso de origen. El resultado despista, porque parece un problema de las
imágenes.

---

## 5 · Costo

Cloud Functions exige plan Blaze. Blaze no significa que se cobre: significa que se
cobra lo que pase de la cuota gratuita. Con los tres ambientes en volumen de pruebas, lo
que se paga es **cero**. Los números medidos el 24 de agosto de 2026:

| Recurso | Consumo real | Cuota gratuita | Alcance de la cuota |
|---|---|---|---|
| Artifact Registry | 91 MB por ambiente ≈ 274 MB los tres | 500 MB | por cuenta de facturación |
| Cloud Scheduler | 1 job por ambiente = **3** | 3 jobs | por cuenta de facturación |
| Invocaciones de Functions | ~43 200/mes por ambiente ≈ 130 000 | 2 000 000 | por cuenta de facturación |
| Firestore | muy por debajo | 50 000 lecturas/día | por proyecto |
| Hosting | muy por debajo | 10 GB + 360 MB/día | por proyecto |

Cloud Scheduler queda **justo en el límite**: el `despachador` corre cada minuto y son
exactamente 3 jobs. Un cuarto job empieza a costar (RES-04). Antes de agregar cualquier
tarea programada hay que contar los que ya existen:

```bash
npx firebase-tools functions:list --project sian-umg-bdm-qa
```

Hay un presupuesto de **10 USD mensuales** sobre la cuenta de facturación completa, con
avisos por correo al 50 %, 90 %, 100 % y al 100 % proyectado. No es un tope: Google no
corta el servicio al llegar. Es un aviso para enterarse el mismo día si algo se comporta
distinto a lo previsto.

---

## 6 · Cómo se promueve un cambio

```
rama de trabajo  ──PR──▶  develop  ──automático──▶  QA
                             │
                             └──PR──▶  main  ──aprobación manual──▶  producción
```

El pipeline vive en [.github/workflows/deploy.yml](../.github/workflows/deploy.yml).
Cada ambiente tiene su propio *environment* de GitHub con sus variables y su cuenta de
servicio, y ninguna credencial vive en el repositorio (RNF-10).

Cada job arranca solo si la variable de su ambiente está puesta:

| Variable | Efecto |
|---|---|
| `vars.QA_PROJECT_ID` | **puesta desde el 24-08-2026**: cada fusión a `develop` despliega QA |
| `vars.PROD_PROJECT_ID` | vacía, el job de producción se salta; con valor, se despliega al fusionar a `main` tras aprobación |

Es un interruptor deliberado: mientras un ambiente no esté listo, el job se omite en
lugar de fallar. Un repositorio en rojo permanente enseña a ignorar el rojo.

> **Las dos variables del interruptor van a nivel de repositorio, no de ambiente.** El
> resto de variables (`QA_API_KEY`, `QA_APP_ID`, …) sí viven en el *environment*, porque
> se leen dentro de los pasos. Pero el `if:` de un job se evalúa **antes** de que GitHub
> aplique el ambiente, así que ahí una variable de ambiente se lee vacía y el job se
> salta en silencio, como si el ambiente no existiera. Pasó el 24 de agosto de 2026:
> `QA_PROJECT_ID` estaba puesta en el ambiente `qa`, todo lo demás en orden, y la fusión
> a `develop` no desplegó nada sin dar ni un error. Se arregla moviendo esa sola variable
> al repositorio.

## 7 · Ramas

No existen ramas `qa` ni `prod`, y no deben crearse. El ambiente al que va un cambio lo
decide la rama en la que cae, no una rama con el nombre del ambiente:

| Rama | Ambiente | Qué es |
|---|---|---|
| `develop` | calidad | rama por defecto; todo PR entra aquí |
| `main` | producción | solo recibe fusiones desde `develop`, y despliega con aprobación |

Una rama por ambiente obligaría a mantener tres historias en paralelo y a llevar cada
corrección a mano de una a otra. Con dos ramas, lo que se probó en calidad es
literalmente el mismo commit que llega a producción.

El ambiente `produccion` de GitHub exige **revisor obligatorio**, y solo acepta
despliegues desde ramas protegidas.
