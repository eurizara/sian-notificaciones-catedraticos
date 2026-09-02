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
| Manual general | [/manuales/](https://sian-umg-bdm-dev.web.app/manuales/) | [/manuales/](https://sian-umg-bdm-qa.web.app/manuales/) | [/manuales/](https://sian-umg-bdm.web.app/manuales/) |
| Manual del catedrático | [/manuales/catedratico/](https://sian-umg-bdm-dev.web.app/manuales/catedratico/) | [/manuales/catedratico/](https://sian-umg-bdm-qa.web.app/manuales/catedratico/) | [/manuales/catedratico/](https://sian-umg-bdm.web.app/manuales/catedratico/) |
| Consola | [abrir](https://console.firebase.google.com/project/sian-umg-bdm-dev/overview) | [abrir](https://console.firebase.google.com/project/sian-umg-bdm-qa/overview) | [abrir](https://console.firebase.google.com/project/sian-umg-bdm/overview) |
| Se despliega | a mano | al fusionar a `qa` | al fusionar a `main`, con aprobación |
| Datos | de prueba, acumulados | de prueba, acumulados | **en operación desde el 26-08-2026** |
| Estado | en uso | certificado el 24-08-2026 | **en producción desde el 26-08-2026** |

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

En producción la lista blanca arrancó con **una sola entrada**, el 26 de agosto de 2026:

| Correo | Rol |
|---|---|
| `eua031989@gmail.com` | COORDINADOR |

Sembrar esa primera invitación es el acto que abre el sistema a gente real, y por eso se
hace deliberadamente el día de la salida, no antes. El resto de la planta entra por carga
masiva desde la propia aplicación, hecha por quien coordina.

> **Recargar una lista no altera a quien ya entró.** Si el archivo trae correos que ya
> usaron su invitación, esos no se tocan y la pantalla los nombra. El detalle está en el
> documento 05, sección 2.10.

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

**La URL de retorno de Google, y el `authDomain`.** Además de habilitar el proveedor, hay
que registrar `https://<proyecto>.web.app/__/auth/handler` en el cliente OAuth del proyecto
—Google Cloud Console → APIs y servicios → Credenciales → «Web client (auto created by
Google Service)»— y poner el `authDomain` de ese ambiente en `<proyecto>.web.app`, **no** en
`<proyecto>.firebaseapp.com`.

Los dos tienen que ir juntos y en ese orden. Si el `authDomain` apunta a otro dominio que
el de la aplicación, entrar con Google **falla en la PWA de iOS**: iOS no puede abrir
ventanas emergentes, el SDK cae a redirección, y aísla el almacenamiento entre los dos
orígenes, así que el estado que se escribe antes de salir no se encuentra al volver. Falla
de forma intermitente, que es lo peor: se reintenta, se queda pensando, y a la tercera
entra. El cliente OAuth es uno por proyecto, así que registrar la URL en uno no sirve para
los otros (DT-19).

**El proveedor de Google.** Se habilita en Authentication → Sign-in method → Google.
Ese clic crea el cliente OAuth; la API no lo crea sola. Sin él, el botón «Entrar con
Google» aparece en pantalla y falla al pulsarlo.

**Las APIs que el despliegue da por habilitadas.** La cuenta de servicio del pipeline
tiene roles acotados y **no puede habilitar APIs**, a propósito: quien despliega no debería
poder encender servicios nuevos en el proyecto. Pero `firebase deploy` sí intenta
habilitar lo que le falta, y cuando no puede se detiene con
«Permissions denied enabling …», sin desplegar nada.

Pasó al publicar producción el 26 de agosto de 2026 con
`firebaseextensions.googleapis.com`. El proyecto de producción se había creado desde la
consola mucho antes que los otros dos, así que traía un juego de APIs distinto: cuatro
menos que calidad, y una de ellas era justo la que el despliegue toca aunque el sistema no
use ninguna extensión.

Antes de estrenar un ambiente conviene comparar sus APIs contra uno que ya despliegue bien,
en lugar de descubrirlas de una en una a base de despliegues fallidos:

```bash
npx firebase-tools projects:list   # para tener a mano los números de proyecto
gcloud services list --enabled --project <ambiente-que-funciona> > /tmp/a.txt
gcloud services list --enabled --project <ambiente-nuevo>        > /tmp/b.txt
diff /tmp/a.txt /tmp/b.txt
```

**Las alertas de operación.** Se crean con `scripts/configurar-alertas.py <proyecto>`, y
sin ellas el ambiente funciona igual —hasta el día que deje de funcionar y nadie se
entere—. Es la sección 5.

**El CORS del bucket.** Se aplica con `scripts/aplicar-cors-storage.sh <proyecto>`. Vive
en el bucket, no en `storage.rules`, así que `firebase deploy` no lo toca. Sin CORS las
imágenes adjuntas no se pintan y las notas de voz sí: Flutter descarga los bytes de una
imagen con `fetch` y el navegador los bloquea, mientras que un `<audio>` reproduce sin
pedir permiso de origen. El resultado despista, porque parece un problema de las
imágenes.

---

## 5 · Qué avisa cuando algo se rompe

Los tres ambientes tienen dos alertas sobre el **despachador**, la función que corre cada
minuto y dispara los mensajes programados y recurrentes. Avisan por correo a
`eurizara1@miumg.edu.gt`.

| Alerta | Salta cuando | Qué significa |
|---|---|---|
| El despachador está fallando | más de 5 ejecuciones con error en 10 minutos | Se ejecuta y revienta. Los mensajes programados no salen |
| El despachador dejó de correr | ninguna ejecución en 15 minutos | O murió la función, o murió el reloj de Cloud Scheduler que la despierta |

Se crean con:

```bash
TOKEN=$(gcloud auth print-access-token) \
  python3 scripts/configurar-alertas.py sian-umg-bdm-qa
```

El script es idempotente: se puede correr las veces que haga falta, y busca por nombre lo
que ya exista para actualizarlo en lugar de duplicarlo. Se corre **una vez por ambiente**,
y hay que volver a correrlo si cambian los umbrales o el correo de destino.

> **Hacen falta las dos alertas, y la segunda es la que de verdad importa.** Una función
> que falla deja errores contables. Una función que **no corre** no deja nada: no produce
> errores porque no produce. Con solo la alerta de tasa de error, la avería más grave —que
> el despachador esté muerto— se vería como un cero y se daría por buena.

**Cada proyecto tiene su propio canal de correo.** Son objetos distintos aunque apunten a
la misma dirección y los cree el mismo script, así que probar uno no prueba los otros: hay
que comprobar la entrega en los tres, y sobre todo en producción, que es el único que va a
sonar cuando importe (documento 09, comprobación A-3).

Cada alerta lleva escrito en su cuerpo qué mirar y en qué orden: los registros de la
función, la colección `cola_despacho` y la pantalla de Programados. Quien la recibe a las
once de la noche no debería tener que reconstruir por dónde empezar.

Lo que **no** vigilan todavía es la tasa de entrega: si los avisos llegaron a los
catedráticos sigue viéndose mensaje por mensaje en Entregas. Es la mitad que queda de
DT-07 (documento 07).

## 6 · Mantenerlos iguales

Los tres ambientes deben ser idénticos **en todo menos en los datos**. Los usuarios y los
mensajes de cada uno son suyos; el código, la configuración y la infraestructura, no.

```bash
TOKEN=$(gcloud auth print-access-token) python3 scripts/comparar-ambientes.py
```

Lo primero que compara es **el commit desplegado en cada ambiente**, y lo demás después:
Functions, planificador, alertas, autenticación, dominios, CORS, APIs habilitadas e
índices. Sale con error si algo difiere.

La primera fila vale por todas las demás. Las otras comprueban que cada ambiente **tenga**
lo que debe; esa comprueba que los tres corran **lo mismo**, que es otra pregunta — y es la
que faltaba.

> **Por qué hace falta una herramienta y no basta con mirar el repositorio.** El 28 de
> agosto de 2026 se perdió un día entero persiguiendo un fallo que en desarrollo no se
> reproducía, y la causa fue que los ambientes no eran iguales en cosas que no viven en el
> código:
>
>   · Desarrollo tenía el CORS con cuatro orígenes y los otros con ocho, porque el archivo
>     se actualizó y solo se aplicó a dos ambientes.
>   · Producción se creó desde la consola meses antes y traía APIs distintas. Una faltaba,
>     y detuvo el primer despliegue con `Permissions denied enabling …`.
>
> Ninguna se ve en un `git diff`. Se ven preguntándole a cada proyecto qué tiene.

### Lo que la herramienta dejaba pasar, y costó media tarde

El 28 de agosto de 2026 esta comprobación dijo que los tres ambientes estaban iguales. Al
día siguiente, desarrollo no notificaba: llevaba desde el 28 a las **17:45** mientras QA y
producción se habían actualizado esa noche a las **22:00**. Las correcciones que se
probaron en desarrollo **no eran** las que se promovieron a producción.

La herramienta no mintió; contestaba otra pregunta. Miraba la configuración a fondo
—Functions activas, CORS, APIs, índices, alertas— y del código solo miraba si ciertas
frases estaban presentes en el paquete servido. Esas frases llevaban ahí desde antes, así
que pasaban en los tres.

> **«¿Tienen la funcionalidad?» no es «¿corren el mismo código?».** La primera pregunta la
> aprueba cualquier versión desde que la funcionalidad existe. La segunda solo la aprueba
> la versión exacta.

Se corrigió con dos cosas:

**Un sello de versión.** `scripts/sellar-version.sh` escribe `version.json` en lo que se
publica, con el árbol, el commit, la rama y si se compiló desde una copia limpia. La
comparación lo lee de cada ambiente y lo pone en la primera fila.

> **Se compara el árbol, no el commit.** La primera versión comparaba commits y daba
> «DIFIERE» con los tres ambientes corriendo exactamente el mismo código: promover por
> `develop → qa → main` crea un commit de fusión distinto en cada rama aunque el contenido
> sea idéntico. El identificador de árbol de git es un resumen del contenido; si coincide,
> los archivos son los mismos venga de la fusión que venga.
>
> El commit se sigue enseñando porque dice **de dónde** salió y sirve para rastrear, pero
> no cuenta como diferencia. Una herramienta que grita cuando todo está bien enseña a
> ignorarla igual que una que calla cuando algo está mal.

**Desarrollo dejó de desplegarse a mano.** Era el único de los tres que dependía de que
alguien se acordara, y por eso fue el que se quedó atrás. Ahora `develop` despliega solo,
igual que `qa` y `main`.

> Un paso manual en una cadena de tres ambientes no es un paso manual: es el ambiente que
> se queda atrás cuando alguien tiene prisa.

Y cada despliegue, al terminar, le pregunta al sitio qué versión está sirviendo y falla si
no es la que acaba de subir. Un trabajo en verde ya había significado antes «casi nada se
desplegó»: dieciocho de diecinueve Functions fallaron con un 409 y el trabajo salió en 0.

### Lo que la herramienta NO puede igualar, y es la trampa peor

**Los datos acumulados.** Ese mismo día, un defecto del envío no apareció en desarrollo
porque ahí **todos** los dispositivos eran del esquema viejo, donde el defecto no podía
manifestarse; en producción ya había del esquema nuevo, y ahí sí. El código era el mismo,
la configuración era la misma, y el resultado era distinto.

Antes de dar por buena una prueba, conviene preguntarse si los datos del ambiente donde se
probó se parecen a los del ambiente donde va a correr de verdad. Cuando la respuesta sea
que no, la prueba hay que rehacerla creando el caso a mano: un dispositivo recién
registrado, un usuario que nunca ha entrado, una invitación ya consumida.

## 7 · Costo

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

## 8 · Cómo se promueve un cambio

```
rama de trabajo  ──PR──▶  develop  ──PR──▶  qa  ──automático──▶  calidad
                                             │
                                             └──PR──▶  main  ──aprobación──▶  producción
```

El pipeline vive en [.github/workflows/deploy.yml](../.github/workflows/deploy.yml), y la
integración continua en [ci.yml](../.github/workflows/ci.yml). **Las tres ramas tienen que
estar en las dos.** Al introducir `qa` se actualizó solo el de despliegue, y el efecto no
se ve hasta que se intenta promover a producción: sin ninguna ejecución de integración
continua sobre el commit de `qa`, el pull request a `main` queda bloqueado esperando unos
checks obligatorios que nunca van a llegar.
Cada ambiente tiene su propio *environment* de GitHub con sus variables y su cuenta de
servicio, y ninguna credencial vive en el repositorio (RNF-10).

Cada job arranca solo si la variable de su ambiente está puesta:

| Variable | Efecto |
|---|---|
| `vars.QA_PROJECT_ID` | **puesta desde el 24-08-2026**: cada fusión a `qa` despliega QA |
| `vars.PROD_PROJECT_ID` | **puesta desde el 26-08-2026**: cada fusión a `main` despliega producción, tras aprobación |

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

## 9 · Ramas

Hay tres ramas permanentes, una por ambiente:

| Rama | Ambiente | Qué es | Al fusionar |
|---|---|---|---|
| `develop` | desarrollo | rama por defecto; todo PR de trabajo entra aquí | no despliega solo |
| `qa` | calidad | lo que está bajo pruebas de calidad | despliega a QA |
| `main` | producción | lo que está publicado | despliega con aprobación |

```
feature/*  ──PR──▶  develop  ──PR──▶  qa  ──PR──▶  main
```

El cambio se promueve siempre hacia adelante y **siempre es el mismo commit**. Eso es lo
que hace útil la rama intermedia: a producción no llega nada que no haya estado antes en
calidad, y lo que se aprobó en calidad no se recompila contra otra base ni se rehace a
mano. Si una corrección urgente entra por `hotfix/*` desde `main`, tiene que regresar
también a `qa` y a `develop`, o la siguiente promoción la borra.

Desarrollo se publica a mano, con:

```bash
bash scripts/generar-firebase-options.sh && cd app && flutter build web --release
```

El ambiente `produccion` de GitHub exige **revisor obligatorio**, y solo acepta
despliegues desde ramas protegidas.

### Protección de las tres ramas

Las tres exigen pull request y los cuatro trabajos de integración continua en verde.
Ninguna admite `force push` ni borrado.

Lo que **no** exigen es que la rama de origen esté al día con la de destino —el
«require branches to be up to date», `strict`—, y eso es deliberado. Cada promoción deja
en la rama de destino un commit de fusión que la de origen nunca va a tener: al fusionar
`qa` en `main`, `main` gana ese commit, y desde ese momento toda promoción futura
aparecería como *behind* aunque el contenido sea idéntico. La única forma de satisfacerlo
sería fusionar `main` de vuelta en `qa` antes de cada entrega, un pull request por
release que no cambia un solo archivo.

La garantía no se pierde: los cuatro trabajos ya corrieron sobre el commit exacto que se
promueve, y la promoción solo avanza hacia adelante, así que la rama de destino nunca
lleva contenido que la de origen no tenga. Se comprueba fácil:

```bash
git rev-parse origin/main^{tree}
git rev-parse origin/develop^{tree}   # tiene que dar lo mismo tras una promoción
```

Con `strict` activado la alternativa práctica habría sido fusionar saltándose la
protección como administrador, que es peor: acostumbrarse a rodear una regla la vuelve
decorativa.
