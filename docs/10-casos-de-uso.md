# 10 — Especificación de casos de uso

Especificación detallada de los doce casos de uso catalogados en el
[documento 01, sección 8](01-levantamiento-requerimientos.md).

## Sobre el formato

Se usa la plantilla de **caso de uso extendido** (*fully dressed*) recomendada
por **ISO/IEC/IEEE 29148:2018** —la norma vigente de ingeniería de requisitos,
que reemplazó a la IEEE 830— y compatible con la notación de casos de uso de
UML 2.5.

Cada caso declara los mismos catorce apartados. Que estén todos, incluso cuando
alguno queda corto, es lo que permite compararlos entre sí y detectar el que
falta.

| Apartado | Qué contiene |
|---|---|
| Identificador y nombre | Clave estable para trazar |
| Actor principal | Quien inicia y obtiene el valor |
| Actores secundarios | Sistemas o personas que participan sin iniciar |
| Partes interesadas e intereses | Quién se ve afectado y qué espera |
| Nivel | Objetivo de usuario, subfunción o resumen |
| Precondiciones | Lo que debe ser cierto **antes**. El sistema lo garantiza |
| Garantía mínima | Lo que se cumple aunque el caso falle a mitad |
| Garantía de éxito | El estado del sistema al terminar bien |
| Disparador | Qué lo inicia |
| Flujo principal | El camino esperado, numerado |
| Flujos alternativos | Variantes válidas que también terminan bien |
| Excepciones | Qué ocurre cuando algo falla |
| Reglas de negocio | Las RN que gobiernan el caso |
| Requisitos trazados | Los RF que este caso cubre |

> **Estos casos describen el sistema construido, no una intención.** Los flujos
> se contrastaron contra el código desplegado en agosto de 2026. Donde el
> comportamiento difiere de lo que uno esperaría, hay una nota explicando por
> qué — casi siempre porque la primera versión falló en una prueba real.

---

## Índice

| ID | Caso de uso | Actor principal | Nivel |
|---|---|---|---|
| [CU-01](#cu-01) | Iniciar sesión con cuenta institucional de Google | Cualquier usuario | Objetivo de usuario |
| [CU-02](#cu-02) | Registrarse con correo y contraseña | Catedrático | Objetivo de usuario |
| [CU-03](#cu-03) | Emitir alerta urgente con voz e imágenes | Coordinador | Objetivo de usuario |
| [CU-04](#cu-04) | Programar un aviso para fecha y hora | Administrador Académico | Objetivo de usuario |
| [CU-05](#cu-05) | Crear un aviso recurrente | Coordinador | Objetivo de usuario |
| [CU-06](#cu-06) | Recibir y abrir una notificación | Catedrático | Objetivo de usuario |
| [CU-07](#cu-07) | Confirmar la lectura de un mensaje | Catedrático | Objetivo de usuario |
| [CU-08](#cu-08) | Consultar quién confirmó y quién no | Emisor | Objetivo de usuario |
| [CU-09](#cu-09) | Auditar la bitácora | Auditor | Objetivo de usuario |
| [CU-10](#cu-10) | Administrar usuarios, roles y grupos | Coordinador | Objetivo de usuario |
| [CU-11](#cu-11) | Suspender o cancelar una programación | Emisor | Objetivo de usuario |
| [CU-12](#cu-12) | Despachar las ocurrencias vencidas | Planificador | Subfunción |

---

<a id="cu-01"></a>
## CU-01 · Iniciar sesión con cuenta institucional de Google

| | |
|---|---|
| **Actor principal** | Cualquier usuario autorizado |
| **Actores secundarios** | Google Identity · Firebase Authentication · Cloud Function `activarSesion` |
| **Nivel** | Objetivo de usuario |

**Partes interesadas e intereses**

- *El usuario*: entrar sin inventar ni recordar otra contraseña.
- *La coordinación*: que solo entre quien fue autorizado antes.
- *La institución*: que todo intento, exitoso o no, quede registrado.

**Precondiciones**

1. El correo del usuario está en la colección `invitaciones` (lista blanca).
2. El usuario tiene sesión activa en Google en ese navegador, o puede iniciarla.

**Garantía mínima.** Si algo falla, no se crea ninguna cuenta a medias: el
intento queda anotado en bitácora con el correo usado y el motivo del rechazo.

**Garantía de éxito.** El usuario queda autenticado, su token lleva el rol y las
autorizaciones finas, y ve la pantalla que corresponde a su rol.

**Disparador.** El usuario presiona **Entrar con Google**.

**Flujo principal**

1. El sistema muestra la pantalla de ingreso.
2. El usuario presiona **Entrar con Google**.
3. Google solicita elegir cuenta y devuelve el resultado a la aplicación.
4. El sistema llama a `activarSesion`.
5. La Function verifica que el correo esté en la lista blanca.
6. La Function crea o actualiza el perfil en `usuarios` y **asigna los *custom
   claims***: rol, si está activo, y sus autorizaciones finas.
7. La Function marca la invitación como consumida y escribe en bitácora.
8. El sistema refresca el token y enruta según el rol: bandeja si es
   catedrático, panel si no.

**Flujos alternativos**

- *3a. El usuario cierra la ventana de Google*: vuelve a la pantalla de ingreso
  sin cambios ni mensajes de error.
- *8a. El usuario recibe avisos además de emitirlos*: el panel incluye la
  sección **Mis mensajes**.

**Excepciones**

- *5a. El correo no está autorizado.* La Function **borra la credencial recién
  creada** —para no dejar cuentas huérfanas—, anota el intento y el sistema
  muestra «Acceso no autorizado» con el correo usado y qué hacer.
  > La credencial desaparece, y por eso `authStateChanges` no emite ningún
  > cambio. La aplicación afirma el estado por su cuenta; si esperara ese
  > evento, el botón de volver quedaría muerto — que es exactamente lo que pasó
  > en la ronda 3.
- *5b. La cuenta existe pero está desactivada.* Se muestra «Cuenta desactivada»
  y se indica que el historial se conserva.
- *6a. El token todavía no lleva rol.* Se muestra «Sesión sin rol asignado» y se
  indica cerrar sesión y volver a entrar.

**Reglas de negocio.** RN-01 (el rol vive en los claims, no se consulta a la
base para decidir permisos) · RN-10 (desactivar no borra).

**Requisitos trazados.** RF-AUT-01, RF-AUT-03, RF-AUT-04, RF-AUT-08.

---

<a id="cu-02"></a>
## CU-02 · Registrarse con correo y contraseña

| | |
|---|---|
| **Actor principal** | Catedrático |
| **Actores secundarios** | Firebase Authentication · `activarSesion` |
| **Nivel** | Objetivo de usuario |

**Precondiciones.** El correo está en la lista blanca.

**Garantía mínima.** Ninguna cuenta queda creada si el correo no estaba
autorizado; el intento se registra.

**Garantía de éxito.** El usuario tiene credencial propia y sesión activa.

**Disparador.** El usuario elige **¿No tienes cuenta? Regístrate**.

**Flujo principal**

1. El usuario escribe correo, contraseña y su repetición.
2. El sistema evalúa la contraseña **mientras se escribe** y muestra qué le
   falta, en lenguaje llano.
3. El usuario presiona **Crear cuenta**.
4. Firebase crea la credencial.
5. `activarSesion` comprueba la lista blanca, crea el perfil y asigna claims.
6. El sistema enruta según el rol.

**Flujos alternativos**

- *2a. Contraseña débil*: el botón permanece disponible, pero el sistema
  enumera los incumplimientos concretos en vez de un «no válida».

**Excepciones**

- *4a. El correo ya tiene cuenta*: se indica iniciar sesión en lugar de
  registrarse.
- *5a. El correo no está autorizado*: se borra la credencial y se muestra el
  rechazo, igual que en CU-01.

**Caso de uso relacionado.** *Recuperar la contraseña*: el usuario pide el
enlace y recibe un correo. Hoy sale desde un dominio de Google y algunos
servidores lo clasifican como no deseado (**DT-14**).

**Reglas de negocio.** RN-01.

**Requisitos trazados.** RF-AUT-02, RF-AUT-03, RF-AUT-05, RF-AUT-06.

---

<a id="cu-03"></a>
## CU-03 · Emitir una alerta urgente con voz e imágenes

| | |
|---|---|
| **Actor principal** | Coordinador (o Administrador Académico autorizado) |
| **Actores secundarios** | Cloud Storage · `enviarInmediato` · FCM · Catedráticos |
| **Nivel** | Objetivo de usuario |

**Partes interesadas e intereses**

- *El emisor*: que llegue ya, y saber a cuántos llegó.
- *El catedrático*: enterarse aunque no tenga la aplicación abierta.
- *La institución*: constancia de quién sabía qué y desde cuándo.

**Precondiciones**

1. El emisor tiene sesión activa con rol y autorización para urgentes.
2. Existe al menos un destinatario elegible.

**Garantía mínima.** O sale el mensaje **completo**, o no sale ninguno: si un
adjunto no se puede subir, se cancela el envío y se explica cuál falló.

**Garantía de éxito.** El mensaje existe en `mensajes`, hay una entrega por
destinatario, la notificación salió por FCM y quedó asiento en bitácora.

**Disparador.** El emisor entra en **Mensajes** y redacta.

**Flujo principal**

1. El emisor escribe título (≤ 80) y mensaje (≤ 500). El contador avisa
   mientras escribe y no lo deja pasarse.
2. Elige **Ahora mismo**.
3. Adjunta hasta 3 imágenes y 2 notas de voz, en cualquier orden. **El orden en
   que las adjunta es el orden en que se verán.**
4. Marca **Urgente** y **Exigir confirmación de lectura**.
5. Elige destinatarios: todos, o grupos concretos.
6. Presiona **Enviar ahora**.
7. El sistema pide el conteo real al servidor.
8. Muestra la **primera confirmación**: a cuántos va, quién queda fuera y por
   qué, y qué adjuntos lleva.
9. El emisor confirma.
10. Por ser urgente, muestra una **segunda confirmación** distinta.
11. El emisor confirma explícitamente.
12. El sistema reserva el identificador del mensaje y **sube los adjuntos en
    serie**, en orden.
13. Llama a `enviarInmediato` con la lista de adjuntos.
14. La Function valida permisos, contenido, adjuntos, destinatarios y
    programación; crea el mensaje con `create()`, la ocurrencia y las entregas;
    escribe bitácora y despacha por FCM.
15. El sistema informa a cuántos llegó.

> **Por qué se sube después de confirmar y no antes.** Si alguien cancela en el
> diálogo, no se gastaron los datos de nadie. Y **en serie y no en paralelo**
> porque en paralelo el orden de llegada lo decidiría la red: la imagen pequeña
> terminaría antes que la nota de voz que iba delante.

**Flujos alternativos**

- *4a. Aviso informativo*: se omite el paso 10; una sola confirmación.
- *5a. Por grupos*: quien esté en dos grupos recibe el aviso **una sola vez**.
- *9a / 11a. El emisor cancela*: no se sube ni se envía nada.

**Excepciones**

- *7a. Cero destinatarios*: se avisa y no se llega a preguntar nada.
- *12a. Falla la subida de un adjunto*: se cancela el envío y se dice **cuál**
  falló.
- *6a. Hay una grabación en curso*: el botón de enviar se bloquea y explica por
  qué. Una grabación no forma parte del mensaje hasta que se detiene.
- *14a. El emisor no está autorizado para urgentes*: la Function lo rechaza
  aunque la interfaz lo hubiera permitido.

**Reglas de negocio.** RN-03 (enviado no se edita ni se borra) · RN-06 (una
urgente exige doble confirmación) · RN-09 (los adjuntos son inmutables).

**Requisitos trazados.** RF-MSG-01 a RF-MSG-13, RF-ENT-01 a RF-ENT-06.

---

<a id="cu-04"></a>
## CU-04 · Programar un aviso para una fecha y hora

| | |
|---|---|
| **Actor principal** | Administrador Académico |
| **Actores secundarios** | `programarMensaje` · Cloud Scheduler |
| **Nivel** | Objetivo de usuario |

**Precondiciones.** Sesión activa con rol emisor; la fecha elegida es futura.

**Garantía mínima.** Un mensaje mal programado no queda a medias: o se encola
con su fecha, o no se crea.

**Garantía de éxito.** El mensaje queda en estado `PROGRAMADO` con su primera
ocurrencia encolada en `cola_despacho`.

**Disparador.** El emisor elige **En una fecha y hora**.

**Flujo principal**

1. El emisor redacta y adjunta lo que necesite.
2. Elige **En una fecha y hora** y fija día y hora.
3. Elige destinatarios y presiona **Enviar ahora**.
4. Confirma en el diálogo con el conteo y los adjuntos.
5. Se suben los adjuntos y se llama a `programarMensaje`.
6. La Function valida que la fecha sea futura, crea el mensaje en `PROGRAMADO`
   y encola la ocurrencia.

> **Los destinatarios se resuelven al despachar, no al programar.** Entre hoy y
> el día del envío puede entrar o salir gente, y lo que importa es quién está
> cuando el aviso sale.

**Excepciones**

- *6a. La fecha está en el pasado, o a menos de un minuto*: se rechaza. El
  planificador revisa cada minuto, y un aviso puesto para «ya mismo» se
  perdería.

**Reglas de negocio.** RN-05 (toda programación declara zona horaria).

**Requisitos trazados.** RF-PRG-02, RF-PRG-03, RF-PRG-04, RF-PRG-11.

---

<a id="cu-05"></a>
## CU-05 · Crear un aviso recurrente

| | |
|---|---|
| **Actor principal** | Coordinador (o quien tenga la autorización fina) |
| **Actores secundarios** | `vistaPreviaOcurrencias` · `programarMensaje` |
| **Nivel** | Objetivo de usuario |

**Precondiciones.** Sesión activa con autorización para crear recurrentes.

**Garantía mínima.** No se guarda ninguna repetición sin que el emisor haya
visto las fechas que produce.

**Garantía de éxito.** El mensaje queda en `PROGRAMADO` con su patrón y su
primera ocurrencia encolada.

**Flujo principal**

1. El emisor redacta el aviso.
2. Elige **Repetido cada cierto tiempo** y define cada cuánto, a qué hora y
   hasta cuándo.
3. Presiona **Ver las próximas fechas**.
4. El sistema calcula y muestra las diez próximas ocurrencias reales.
5. El emisor las revisa, confirma el envío y el sistema encola la primera.

> **El paso 3 es obligatorio, y no es un trámite.** Un patrón de repetición es
> fácil de equivocar, y diez fechas concretas delante es la única forma de
> darse cuenta antes de que salgan diez avisos equivocados.

**Excepciones**

- *4a. El patrón no produce ninguna fecha*: se dice y se pide revisar el rango,
  los días y la hora.
- *5a. Se intenta guardar sin ver la vista previa*: el sistema lo impide.

**Reglas de negocio.** RN-05 · RF-PRG-14 (tope de 500 ocurrencias como
salvaguarda contra bucles de envío).

**Requisitos trazados.** RF-PRG-05 a RF-PRG-09, RF-PRG-14.

---

<a id="cu-06"></a>
## CU-06 · Recibir y abrir una notificación

| | |
|---|---|
| **Actor principal** | Catedrático |
| **Actores secundarios** | FCM · Service Worker · `marcarAbierto` |
| **Nivel** | Objetivo de usuario |

**Precondiciones**

1. El catedrático concedió el permiso de notificaciones.
2. En iPhone, **la aplicación está instalada en la pantalla de inicio**: Apple
   no entrega notificaciones a una pestaña de Safari.

**Garantía mínima.** Aunque la notificación no llegue, el mensaje está en la
bandeja la próxima vez que se abra la aplicación.

**Garantía de éxito.** La entrega pasa a `ABIERTO` con su marca de tiempo.

**Disparador.** Llega una notificación, o el catedrático abre la aplicación.

**Flujo principal**

1. El servidor envía por FCM un mensaje **solo de datos**.
2. El Service Worker lo recibe y decide cómo presentarlo: prefijo «URGENTE»,
   vibración más larga y sin descarte automático si lo es.
3. El catedrático toca la notificación y se abre la aplicación.
4. La bandeja muestra sus mensajes, con el filtro **Sin leer** activo.
5. Toca un mensaje: la fila se despliega y muestra el texto y los adjuntos **en
   el orden en que se adjuntaron**.
6. El sistema llama a `marcarAbierto`, que pasa la entrega a `ABIERTO`.

> **Se marca al desplegar, no al dibujar la lista.** Antes bastaba con que la
> bandeja se pintara para que todo constara como abierto: un dato de
> seguimiento convertido en una casilla que se marca sola.

**Flujos alternativos**

- *2a. La aplicación está abierta en primer plano*: el navegador no muestra
  nada por su cuenta, así que es la aplicación la que se hace notar.
- *5a. El mensaje trae imagen*: se muestra un botón y la imagen se descarga
  solo al pedirla, para que la bandeja abra rápido con conexión mala.
- *4a. Es una urgente sin confirmar*: nace desplegada y se marca abierta de
  entrada.

**Excepciones**

- *1a. Sin permiso*: la tarjeta superior dice qué falta y cómo darlo.
- *1b. iPhone en una pestaña*: la aplicación muestra el instructivo de
  instalación antes que la bandeja.

**Reglas de negocio.** RES-05 (iOS exige instalación) · RF-CNF-02 (abrir no es
confirmar).

**Requisitos trazados.** RF-ENT-04 a RF-ENT-09, RF-ENT-12, RF-USR-09.

---

<a id="cu-07"></a>
## CU-07 · Confirmar la lectura de un mensaje

| | |
|---|---|
| **Actor principal** | Catedrático |
| **Actores secundarios** | `confirmarLectura` |
| **Nivel** | Objetivo de usuario |

**Partes interesadas e intereses**

- *El catedrático*: dejar constancia de que se enteró.
- *La institución*: poder responder «¿quién sabía del simulacro?» con evidencia.

**Precondiciones**

1. El mensaje exige confirmación y está entregado a este usuario.
2. No ha sido confirmado antes.

**Garantía mínima.** La confirmación es atómica: dos toques rápidos del mismo
botón no producen dos confirmaciones.

**Garantía de éxito.** La entrega pasa a `CONFIRMADO` con identificador, fecha,
hora y dispositivo; el contador del mensaje sube y queda asiento en bitácora.

**Disparador.** El catedrático despliega un mensaje que lo exige.

**Flujo principal**

1. El sistema muestra el botón **Confirmar lectura**.
2. El catedrático lo presiona.
3. El sistema pide una confirmación explícita antes de escribir.
4. `confirmarLectura` localiza la entrega y comprueba que sea confirmable.
5. Dentro de una **transacción**, vuelve a comprobarlo y escribe el estado, la
   marca de tiempo y el dispositivo.
6. Actualiza el contador y escribe en bitácora.
7. La fila deja de destacarse.

> **La transacción cierra la ventana entre comprobar y escribir.** Sin ella,
> dos toques seguidos producirían dos confirmaciones.

**Excepciones**

- *4a. Ya estaba confirmado*: se explica; no es un fallo del sistema.
- *4b. No consta la entrega*: se responde sin detalle — decir «ese mensaje no
  es para ti» ya revelaría que existe.

**Reglas de negocio.** RN-04 (la confirmación es irreversible) · RF-CNF-04 (la
escribe **solo el servidor**: una confirmación fabricable desde la consola del
navegador no probaría nada).

**Requisitos trazados.** RF-CNF-01 a RF-CNF-05.

---

<a id="cu-08"></a>
## CU-08 · Consultar quién confirmó y quién no

| | |
|---|---|
| **Actor principal** | Coordinador o Administrador Académico |
| **Actores secundarios** | `detalleEntregas` |
| **Nivel** | Objetivo de usuario |

**Precondiciones.** Existe al menos un mensaje enviado por quien consulta.

**Garantía de éxito.** El emisor ve, por mensaje, cuántos lo recibieron,
abrieron y confirmaron, y **quiénes faltan, con nombre**.

**Flujo principal**

1. El emisor entra en **Entregas**.
2. El sistema lista los mensajes ya enviados, con su barra de avance.
3. El emisor filtra por **Todos**, **Pendientes** o **Completos**.
4. Presiona **Ver quién falta** en un mensaje.
5. `detalleEntregas` devuelve los destinatarios con su estado **y su nombre**.

> **El nombre lo resuelve el servidor.** Un administrador no puede leer la
> colección `usuarios`, así que si la pantalla intentara resolverlo por su
> cuenta, la consulta se rechazaría entera.

> **«Completo» significa cosas distintas.** Si el aviso pedía confirmación,
> está completo cuando la dieron todos; si no la pedía, basta con que llegara.
> Con una sola vara, la mitad quedaría pendiente para siempre por no haber
> hecho algo que nunca se le pidió.

**Flujos alternativos**

- *3a. Un aviso sin confirmación exigida*: se mide por entrega, y así se
  presenta — no aparece «faltan N por confirmar».

**Reglas de negocio.** RF-CNF-07 (el porcentaje se calcula sobre el total de
destinatarios: a quien no le llegó tampoco lo confirmó).

**Requisitos trazados.** RF-CNF-06, RF-CNF-07, RF-BIT-07, RF-BIT-08.

---

<a id="cu-09"></a>
## CU-09 · Auditar la bitácora

| | |
|---|---|
| **Actor principal** | Auditor |
| **Nivel** | Objetivo de usuario |

**Precondiciones.** Sesión activa con rol auditor o coordinador.

**Garantía de éxito.** El auditor consulta los asientos filtrados, sin poder
alterarlos.

**Flujo principal**

1. El auditor entra en **Bitácora**.
2. El sistema lista los asientos del más reciente al más antiguo.
3. El auditor filtra por tipo de evento y busca por palabras.
4. Cada asiento muestra quién, qué, sobre qué entidad y cuándo.

> **La bitácora solo se escribe, nunca se modifica** (RF-BIT-03). Las reglas
> declaran `allow create, update, delete: if false` para el cliente: los
> asientos los escribe únicamente el servidor. Y se anota **antes** de
> despachar, porque una bitácora que solo registrara lo que salió bien no
> serviría para investigar nada.

**Requisitos trazados.** RF-BIT-01 a RF-BIT-06.

---

<a id="cu-10"></a>
## CU-10 · Administrar usuarios, roles y grupos

| | |
|---|---|
| **Actor principal** | Coordinador |
| **Actores secundarios** | `crearInvitaciones` · `cambiarRol` · `cambiarEstadoUsuario` · `cambiarAutorizacionesFinas` · `guardarGrupo` |
| **Nivel** | Objetivo de usuario |

**Precondiciones.** Sesión activa con rol coordinador.

**Garantía mínima.** Ningún cambio de rol o de estado ocurre sin quedar
registrado en bitácora.

**Garantía de éxito.** La lista blanca, los roles, las autorizaciones finas y
los grupos quedan como el coordinador los dejó, y los claims se actualizan.

**Flujo principal**

1. El coordinador entra en **Usuarios**.
2. Añade correos uno por uno o carga un archivo CSV, asignando rol a cada uno.
3. Cambia roles, activa o desactiva cuentas, y ajusta quién puede emitir
   urgentes o crear recurrentes.
4. En **Grupos**, arma conjuntos de destinatarios por carrera o jornada.

**Flujos alternativos**

- *3a. Un emisor que además debe recibir avisos*: se le activa **recibe
  avisos** y obtiene la sección *Mis mensajes* dentro del mismo panel, sin
  necesitar una segunda cuenta.
- *4a. Grupo desactivado*: desaparece de los destinatarios elegibles sin
  borrarse.

**Excepciones**

- *3b. Desactivar una cuenta*: no borra nada. La persona deja de entrar y de
  recibir, pero su historial se conserva completo (RN-10).

**Requisitos trazados.** RF-USR-01 a RF-USR-06, RF-AUT-02, RF-AUT-08.

---

<a id="cu-11"></a>
## CU-11 · Suspender o cancelar una programación

| | |
|---|---|
| **Actor principal** | Coordinador o Administrador Académico |
| **Actores secundarios** | `cambiarProgramacion` |
| **Nivel** | Objetivo de usuario |

**Precondiciones.** Existe un mensaje programado que todavía no ha salido.

**Garantía mínima.** Un mensaje ya enviado nunca cambia de estado por esta vía.

**Garantía de éxito.** La programación queda suspendida, reanudada o cancelada,
con su asiento en bitácora.

**Flujo principal**

1. El emisor entra en **Programación** y localiza el mensaje.
2. Elige **Suspender**, **Reanudar** o **Cancelar**.
3. La Function valida la transición y actualiza el mensaje y su cola.

**Flujos alternativos**

- *2a. Suspender*: se puede deshacer reanudando.
- *2b. Cancelar*: **no se puede deshacer**, y el sistema lo advierte antes.

**Excepciones**

- *3a. El mensaje ya salió*: no se ofrece ninguna acción. RN-03 lo prohíbe.

**Requisitos trazados.** RF-PRG-10, RF-PRG-11.

---

<a id="cu-12"></a>
## CU-12 · Despachar las ocurrencias vencidas

| | |
|---|---|
| **Actor principal** | Planificador (Cloud Scheduler) |
| **Actores secundarios** | `despachador` · FCM · Firestore |
| **Nivel** | Subfunción — no lo inicia ninguna persona |

**Partes interesadas e intereses**

- *El catedrático*: que el aviso llegue a su hora, y **una sola vez**.
- *La institución*: que un fallo del sistema no haga desaparecer un aviso ni lo
  duplique.

**Precondiciones.** Hay ítems en `cola_despacho` con fecha de ejecución
vencida.

**Garantía mínima.** Un ítem que falla no tumba el ciclo: los demás siguen. Y
**ninguna ocurrencia sale dos veces**.

**Garantía de éxito.** Las ocurrencias vencidas quedan despachadas, y las
recurrentes tienen ya encolada la siguiente.

**Disparador.** Cloud Scheduler, **cada minuto**.

**Flujo principal**

1. El despachador consulta los ítems vencidos y los ordena: **las urgentes
   primero**, y dentro de cada prioridad las más atrasadas antes.
2. Para cada ítem, dentro de una **transacción**, lo toma y lo bloquea.
3. Resuelve los destinatarios **en ese momento**, no cuando se programó.
4. Crea las entregas, despacha por FCM y actualiza el resumen.
5. Escribe en bitácora.
6. Si el mensaje es recurrente, calcula y encola la siguiente ocurrencia.

> **Tres defensas contra el envío doble**, porque Cloud Scheduler no garantiza
> ejecución única y una Function puede reintentarse sola:
>
> 1. **Identificador determinista** del ítem: encolar dos veces escribe el
>    mismo documento, no crea dos.
> 2. **Transacción de bloqueo** al tomarlo: la segunda ejecución lo ve tomado y
>    lo deja pasar.
> 3. **Bloqueo con vencimiento** de cinco minutos: sin él, una ejecución que
>    muriera a mitad dejaría el aviso encallado para siempre.
>
> Un aviso que sale dos veces destruye más confianza que uno que no sale: la
> siguiente vez nadie se lo cree.

**Flujos alternativos**

- *1a. Sin ítems vencidos*: el ciclo termina sin hacer nada.
- *6a. La recurrencia se agotó*: el mensaje pasa a `AGOTADO`.

**Excepciones**

- *2a. La ocurrencia venció hace más de la tolerancia*: se marca **omitida** y
  se registra. Si el sistema estuvo caído dos días, nadie quiere que al volver
  salga de golpe el aviso de un simulacro de anteayer.
- *2b. El mensaje fue cancelado o suspendido*: el ítem se descarta.
- *2c. Se agotaron los intentos*: el ítem pasa a fallido con su motivo.

**Reglas de negocio.** RF-PRG-12 (no se envía dos veces) · RF-PRG-13
(tolerancia de retraso) · RF-PRG-14 (tope de ocurrencias).

**Requisitos trazados.** RF-PRG-12, RF-PRG-13, RF-PRG-14, RF-ENT-14.

---

## Matriz de trazabilidad inversa

Qué caso de uso cubre cada familia de requisitos. Un requisito sin caso de uso
es un requisito que nadie va a probar.

| Familia | Casos de uso que la cubren |
|---|---|
| RF-AUT · Autenticación | CU-01, CU-02, CU-10 |
| RF-USR · Usuarios y grupos | CU-10, CU-06 |
| RF-MSG · Composición | CU-03, CU-04, CU-05 |
| RF-PRG · Programación | CU-04, CU-05, CU-11, CU-12 |
| RF-ENT · Entrega | CU-03, CU-06, CU-12 |
| RF-CNF · Confirmación | CU-06, CU-07, CU-08 |
| RF-BIT · Bitácora | CU-08, CU-09 |
