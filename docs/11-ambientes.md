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

**Las llaves VAPID propias (DT-23).** Son las que permiten enviar Web Push **directo**, sin
pasar por el token de FCM — y por tanto que el service worker pueda reparar el canal sin que
nadie abra la aplicación. Por ambiente hace falta:

  1. Generar el par: `node -e "console.log(JSON.stringify(require('web-push').generateVAPIDKeys()))"`
     desde `functions/`.
  2. Habilitar **Secret Manager** en el proyecto y crear el secreto `VAPID_PRIVADA` con la
     llave privada, dando acceso de lectura a la cuenta con la que corren las funciones.
  3. Poner la **pública** en `functions/src/infrastructure/vapid.ts` y en el
     `--dart-define=SIAN_VAPID_PROPIA` de ese ambiente en `deploy.yml`.

La privada **no se guarda en el repositorio ni en GitHub**. La pública sí, porque lo es:
viaja a cada navegador en cada suscripción.

| Ambiente | Llaves propias | Desde |
|---|---|---|
| Desarrollo | Sí · `VAPID_PRIVADA` con lectura para la cuenta de funciones | 12/09/2026 |
| QA | Sí · la privada la cargó el responsable por consola; solo *Usuario con acceso a secretos* | 12/09/2026 |
| Producción | Sí · la privada la cargó el responsable por consola; solo *Usuario con acceso a secretos* | 13/09/2026 |

En la consola en español, el rol correcto se llama **«Usuario con acceso a secretos de Secret
Manager»**. «Visualizador» no sirve —ve el secreto pero no lee su valor— y «Administrador» da
permiso de sobra.

Mientras un ambiente no tenga par propio, esta vía queda apagada y los avisos salen por FCM
como siempre: desplegar sin **ninguna** de las dos llaves no rompe nada.

> **El orden importa, y equivocarse deja al ambiente mudo.** Una aplicación compilada con
> la pública se suscribe con ella y **ya no pide token de FCM**. Si el servidor no puede leer
> la privada, no puede enviarle por Web Push y tampoco tiene token al que caer: el envío
> sale como `SIN_LLAVES` y a ese aparato no le llega nada. Por eso:
>
>   1. **Primero** el secreto `VAPID_PRIVADA` en Secret Manager, con acceso para la cuenta
>      de las funciones, y comprobado.
>   2. **Después** la pública en `vapid.ts` y en `deploy.yml`, en el mismo cambio.
>
> Las dos públicas tienen que ser idénticas: si difieren, el servicio de push rechaza la
> firma de todos los envíos. `functions/test/unidad/vapid.test.ts` falla si no coinciden o
> si una tiene mal la forma.

**Rotar las llaves VAPID (S-9, desde 1.6.12).** Cambiar el par de un ambiente. **No es
rutinario**: se hace si la privada pudo filtrarse (se pegó donde no debía, o alguien que la
tuvo ya no está en el proyecto). Con la privada **y** las suscripciones —que están en
Firestore, protegidas por las reglas— alguien podría mandar notificaciones a los aparatos de
ese ambiente. Solo con la privada, no.

*Lo que cuesta.* Cada suscripción queda atada a la pública con la que se hizo. Desde que el
servidor firma con la nueva, **un aparato no recibe notificaciones hasta que abra SIAN una
vez**: al abrir, la aplicación ve que su suscripción es de otra llave, la retira, se suscribe
con la nueva y se registra de nuevo, sola (`suscripcion_web.dart`, `_mismaLlave`). Los avisos
de ese intervalo no se pierden: están en la bandeja. El servidor no guarda la llave anterior,
así que no hay forma de cubrir ese intervalo sin programar una transición con dos llaves;
si algún día se necesita rotar sin ese costo, es la mejora que hay que hacer.

*Pasos, por ambiente y en el orden de siempre (desarrollo → QA → producción).* Fuera del
horario de clases y sin avisos programados en la hora siguiente:

  1. **Preparar el cambio de la pública.** Quien desarrolla deja listo, con la CI en verde y
     **sin fusionar**, el pull request que cambia la pública en `functions/src/infrastructure/vapid.ts`
     y en el `--dart-define=SIAN_VAPID_PROPIA` de ese ambiente en `deploy.yml`.
     `vapid.test.ts` comprueba que coincidan.
  2. **El responsable genera el par**, en su computadora:
     `node -e "console.log(JSON.stringify(require('web-push').generateVAPIDKeys()))"` desde
     `functions/`. Pasa **solo la pública** a quien desarrolla; la privada no se pega en
     ningún chat, documento ni repositorio.
  3. **El responsable carga la privada** en la consola de Google Cloud → Secret Manager →
     `VAPID_PRIVADA` → **Nueva versión**. Sin desactivar la anterior todavía. Las funciones
     leen `latest`, pero cada instancia guarda la llave en memoria: hasta el despliegue del
     paso 4 conviven instancias con la vieja y con la nueva, y las nuevas fallan al firmar.
     Por eso el paso 4 va **inmediatamente** después.
  4. **Se fusiona el pull request** del paso 1 y se espera el despliegue (unos 10 minutos;
     en producción, con la aprobación del responsable). Todas las instancias arrancan con
     la privada nueva y la pública nueva.
  5. **Pedir a todos que abran SIAN una vez**, por un canal que no sea SIAN (correo,
     WhatsApp de coordinación): una notificación de SIAN no les llegaría. En Alcance se ve
     quién ya volvió a registrarse (su última actividad).
  6. **Comprobar** con los aparatos propios: abrir SIAN, mandarse un aviso de prueba, que
     llegue.
  7. **A la semana, destruir la versión vieja** del secreto: Secret Manager →
     `VAPID_PRIVADA` → versiones → la anterior → **Destruir**. No antes: si hubiera que
     volver atrás por un error del paso 4, es lo único que lo permite.
  8. Anotar la fecha en la tabla de arriba.

*Si algo sale mal en el paso 4* (el despliegue falla, o los envíos salen `SIN_LLAVES`):
revertir el pull request y, en Secret Manager, abrir la versión **anterior** →
*Ver el valor del secreto* → copiarlo en una **Nueva versión**. **No** desactivar la nueva:
`latest` es siempre la versión creada más recientemente, y si está desactivada las funciones
no leen ninguna y el ambiente se queda sin Web Push. Si la rotación era por una filtración,
no se vuelve atrás: se corrige el despliegue y se sigue, porque la llave vieja ya no es de
fiar.

**Actualizar dependencias (S-8, desde 1.6.12).** El día 1 de cada mes,
`.github/workflows/actualizar-dependencias.yml` sube lo que admiten los rangos declarados
—menores y parches— de las funciones, la raíz y la aplicación, en **un solo** pull request
contra `develop`, y lanza la integración continua sobre él. Se puede lanzar a mano desde
*Actions → Actualización mensual de dependencias → Run workflow*.

  - **CI en verde:** se fusiona y sigue el camino de siempre hacia QA y producción.
  - **CI en rojo:** el pull request dice qué cambió; se busca el paquete culpable, se fija
    su versión en el rango y se vuelve a lanzar.
  - **Versiones mayores:** no se suben solas, porque cambian la API. La descripción del pull
    request las lista; cada una se decide y se hace a mano, en su propio cambio.

Mientras el repositorio no permita que las acciones abran pull requests (*Settings →
Actions → General → «Allow GitHub Actions to create and approve pull requests»*, hoy
desactivado), el flujo deja la rama lista, con la CI ya lanzada, y abre un **issue** con el
enlace para crear el pull request con un clic. Activarlo es decisión del responsable: da a
los flujos permiso para abrir pull requests, no para fusionarlos.

Dependabot se queda solo con las acciones de GitHub: en npm y pub no había abierto nada
desde que se configuró, y dos mecanismos para lo mismo acaban en pull requests duplicados.

**Respaldos de Firestore (desde 1.5.13).** Hasta el 23/09/2026 no había ninguno, en ningún
ambiente. Los configura `scripts/configurar-respaldos.py`, que es idempotente y con
`--revisar` solo lee:

| Ambiente | Programa | Retención |
|---|---|---|
| Producción | diario + semanal (domingo) | 7 días + 12 semanas |
| QA | semanal (domingo) | 4 semanas |
| Desarrollo | semanal (domingo) | 4 semanas |

Firestore no hace respaldos al momento: el primero sale en la fecha del programa.

**Cómo se restaura.** Nunca encima de la base `(default)`:

  1. Ver los respaldos: `GET https://firestore.googleapis.com/v1/projects/<proyecto>/locations/us-central1/backups`.
  2. Restaurar en una base **nueva**: `POST https://firestore.googleapis.com/v1/projects/<proyecto>/databases:restore`
     con `{"databaseId": "restauracion-AAAAMMDD", "backup": "<nombre del respaldo>"}`.
  3. Leer de esa base lo que haga falta y copiarlo a `(default)` con un guion revisado.
  4. Borrar la base temporal al terminar: mientras exista, se paga su almacenamiento.

**App Check (desde 1.6.9, DT-33).** Comprueba que una llamada a las funciones sale de la
aplicación y no de un guion con la configuración pública del proyecto. Va en **dos pasos**, y
el segundo no se da hasta que el primero lo justifique.

*Paso 1 — observar (una vez por ambiente; lo hace el responsable en la consola):*

  1. Google Cloud → proyecto del ambiente → **Seguridad → reCAPTCHA** → habilitar la API si
     la pide → **Crear clave**: tipo *Sitio web*, dominios `<proyecto>.web.app` y
     `<proyecto>.firebaseapp.com`, **sin** desafío de casilla. Copiar el **ID de la clave**:
     es pública, como la VAPID. reCAPTCHA Enterprise no tiene clave secreta.
  2. Consola de Firebase → **App Check → Aplicaciones** → la aplicación web → *reCAPTCHA
     Enterprise* → pegar el ID → **vigencia del token: 1 día** (con la de una hora se gasta
     24 veces más cuota).
  3. **No** pulsar *Aplicar* en ningún producto (Firestore, Storage, Authentication): eso es
     el paso 2.
  4. Guardar el ID como variable del repositorio: `gh variable set DEV_APP_CHECK_KEY`
     (o `QA_…`, `PROD_…`). El siguiente despliegue del ambiente ya lo enciende.

Cuota: reCAPTCHA cobra por evaluación, con un tramo gratuito mensual (10 000 al consultarlo
en septiembre de 2026; confirmarlo en su página de precios antes de encenderlo en
producción). Con tokens de un día, cada aparato hace como mucho una evaluación diaria: unos
150 aparatos en producción son ~4 500 al mes.

*Cómo se observa.* Cada llamada deja en el registro de la función el resultado de las
verificaciones. En el Explorador de registros:

```
resource.type="cloud_run_revision"
jsonPayload.verifications.app=("MISSING" OR "INVALID")
```

`VALID` es la aplicación con token; `MISSING`, una llamada sin él (una versión anterior a
1.6.9, o reCAPTCHA que no cargó); `INVALID`, un token falso o de otro proyecto. App Check →
*APIs* muestra además las proporciones de Firestore y Storage.

*Paso 2 — exigir.* Solo cuando, durante al menos **una semana**, no haya `MISSING` ni
`INVALID` de personas reales, y Alcance diga que nadie sigue en una versión anterior a
1.6.9 (esas no mandan token y quedarían fuera sin aviso). Entonces:
`EXIGIR_APP_CHECK = true` en `functions/src/infrastructure/firebase.ts` (la prueba
`appCheck.test.ts` pide actualizarla a propósito), y después, si se quiere, *Aplicar* en
Firestore y Storage desde la consola. Las dos rutas HTTP del service worker —`acuse` y la
renovación de la suscripción— quedan fuera: el worker no puede obtener un token.

*Si algo sale mal.* Con App Check solo observado, nada: la aplicación arranca aunque
reCAPTCHA no cargue. Ya exigido, se vuelve atrás con `EXIGIR_APP_CHECK = false` y un
despliegue, o quitando *Aplicar* en la consola, que tiene efecto en minutos.

**Gasto.** La cuenta de facturación tiene un **techo de 10 USD al mes para los tres
proyectos**, con avisos por correo a los administradores de facturación al 50, 90 y 100 %, y
uno de 1 USD solo para desarrollo. Recomendado: uno propio para producción, para saber de qué
proyecto viene un aviso.

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

**La huella del paquete (desde 1.6.11).** Después de sellar, `scripts/huella-paquete.sh`
renombra `main.dart.js` a `main.<huella>.dart.js` y apunta `flutter_bootstrap.js` a él, para
que Hosting pueda guardarlo un año. Si una versión nueva de Flutter cambia el formato del
arranque, el guion falla y el despliegue se detiene antes de publicar: es preferible a una
aplicación en blanco. `comparar-ambientes.py` lee el nombre del arranque.

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
| Cloud Scheduler | 2 jobs por ambiente = **6** | 3 jobs | por cuenta de facturación |
| Invocaciones de Functions | ~43 200/mes por ambiente ≈ 130 000 | 2 000 000 | por cuenta de facturación |
| Firestore | muy por debajo | 50 000 lecturas/día | por proyecto |
| Hosting | muy por debajo | 10 GB + 360 MB/día | por proyecto |

### Cloud Scheduler pasó la cuota, y es lo único que cuesta

**Es el único renglón que dejó de ser cero, y conviene mirarlo de frente.**

Hasta el 9 de septiembre de 2026 había un solo trabajo por ambiente —el `despachador`, que
corre cada minuto— y eran exactamente 3, justo en el límite. La sonda de canal de DT-22
añadió un segundo por ambiente: ahora son **6**.

Los tres primeros siguen siendo gratis; los otros tres cuestan **0.10 USD al mes cada uno**,
o sea **0.30 USD mensuales** sobre una cuenta con un presupuesto de 10 USD. Es el 3 % del
aviso más bajo.

> **Se decidió pagarlo.** La alternativa era no tener sonda, y sin ella un token muerto solo
> se descubre cuando falla un aviso real — que el 7 de septiembre costó el 23 % de la
> audiencia en un solo envío. Treinta centavos al mes por saberlo antes es una compra
> evidente.
>
> Lo que no sería evidente es llegar aquí sin darse cuenta. Por eso este renglón queda
> escrito con su número, y no diluido en un «sigue siendo gratis».

Si algún día hiciera falta volver a cero: la sonda es diaria y el despachador es por
minuto, así que el candidato a fusionar sería la sonda dentro del despachador con una
comprobación de día y hora. **No se hizo** porque mezclar una tarea diaria dentro de una que
corre cada minuto es la clase de ahorro que se paga en confusión el día que algo falla.

Antes de agregar cualquier tarea programada hay que contar las que ya existen:

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
