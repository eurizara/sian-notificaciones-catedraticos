# 09 — Guion de pruebas por ronda

**Versión:** 1.0 · 3 de agosto de 2026

Este documento acompaña al plan de iteraciones (documento 08) desde el otro lado: por cada
incremento entregado dice **qué probar, en qué orden, qué debe pasar y qué queda fuera**.

## Cómo se usa

Cada ronda tiene tres partes, y las tres importan:

| Parte | Para qué sirve |
|---|---|
| **Alcance** | Qué se está validando y, sobre todo, **qué NO**. Probar algo fuera de alcance y darlo por roto es la forma más rápida de perder una tarde |
| **Pasos** | La secuencia exacta, con el resultado esperado de cada uno |
| **Criterio de salida** | Qué tiene que cumplirse para avanzar a la siguiente ronda |

Un paso que falla se anota como incidencia en GitHub con la etiqueta de su ronda, y se
clasifica como defecto, mejora o requisito nuevo (documento 08, iteración 2.2).

> **Estas rondas son de validación de alcance, no de calidad final.** Corren contra
> emuladores y datos sembrados. La validación con usuarios reales, el simulacro y la prueba
> de resistencia en iOS son la fase 2 (documento 08) y tienen sus propios criterios.

---

## Preparación, una sola vez por sesión

Dos terminales. En la primera:

```bash
cd ~/Proyectos/sian && npx firebase emulators:start --project sian-umg-bdm-dev
```

En la segunda:

```bash
cd ~/Proyectos/sian && FIRESTORE_EMULATOR_HOST=localhost:8080 FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 npx tsx scripts/seed-dev.ts
```

Y para ver la aplicación, cualquiera de las dos vías:

| Vía | Comando | Cuándo conviene |
|---|---|---|
| Compilada | ya servida en **http://127.0.0.1:5050** | Probar la PWA tal como la verá el catedrático |
| En caliente | `cd app && flutter run -d chrome --web-port=5000 --dart-define=USE_EMULATOR=true` | Desarrollo: recarga al guardar |

Si cambias el código y usas la vía compilada, hay que reconstruir:
`cd app && flutter build web --dart-define=USE_EMULATOR=true`

### Cuentas sembradas

Todas con contraseña **`Aula#Magna2047`**:

| Correo | Rol | Particularidad |
|---|---|---|
| `coordinacion@umg.edu.gt` | Coordinador | Todos los permisos |
| `admin1@umg.edu.gt` | Administradora | **Sí** puede emitir urgentes |
| `admin2@umg.edu.gt` | Administradora | **No** puede emitir urgentes |
| `auditoria@umg.edu.gt` | Auditor | Solo lectura |
| `catedratico1@umg.edu.gt` | Catedrático | Su entrega está **CONFIRMADA** |
| `catedratico2@umg.edu.gt` | Catedrático | Su entrega está **ABIERTA**, sin confirmar |
| `catedratico3@umg.edu.gt` … `10` | Catedrático | Su entrega está **ENTREGADA**, sin abrir |

---

## Ronda 1 — Identidad, sesión y roles

**Estado: lista para probar.** Corresponde a la iteración 1.1 y a la primera rebanada de la 1.2.

### Alcance

**Sí se valida:** identidad institucional, inicio y cierre de sesión con correo y contraseña,
enrutado según rol, filtrado del menú por la matriz RBAC, lectura real del historial del
catedrático a través de las reglas de seguridad, y el rechazo explicativo de RF-AUT-03.

**No se valida todavía, y no es un defecto si no funciona:**

- Inicio de sesión con Google
- Alta de un usuario nuevo desde la lista blanca
- Crear, enviar o programar mensajes
- Notificaciones push de cualquier tipo
- Confirmar la lectura de un mensaje

### Pasos

| # | Acción | Resultado esperado |
|---|---|---|
| 1.1 | Abre la aplicación | Banda azul marino con el escudo de la UMG sobre un disco blanco, **SIAN UMG-BDM**, nombre completo del sistema, universidad y sede. El botón **Entrar con Google** se ve sin desplazar |
| 1.2 | Entra con `coordinacion@umg.edu.gt` | Panel con **6 secciones**: Mensajes, Programación, Grupos, Usuarios, Entregas, Bitácora |
| 1.3 | Recorre las 6 secciones | **Todas están construidas** desde la iteración 1.4: Mensajes, Programación, Grupos, Usuarios, Entregas y Bitácora |
| 1.4 | Cierra sesión y entra con `admin1@umg.edu.gt` | Mismo panel **sin Usuarios ni Bitácora**. Solo 4 secciones |
| 1.5 | Cierra sesión y entra con `auditoria@umg.edu.gt` | **Solo 2 secciones**: Entregas y Bitácora. Ninguna de emisión |
| 1.6 | Cierra sesión y entra con `catedratico1@umg.edu.gt` | Bandeja, **no** panel. Un mensaje: «Simulacro de evacuación» con distintivo rojo **URGENTE** |
| 1.7 | Observa el estado del mensaje | Dice **Confirmado**, en verde. **No** aparece el aviso de pendientes |
| 1.8 | Cierra sesión y entra con `catedratico2@umg.edu.gt` | El mismo mensaje, pero en estado **Abierto** y **sí** aparece «Tienes 1 alerta urgente sin confirmar» |
| 1.9 | Compara 1.7 con 1.8 | Es RF-CNF-02 en pantalla: **abrir un mensaje no lo confirma**. Son estados distintos y el sistema los trata distinto |
| 1.10 | Pulsa «Confirmar lectura» | Pide una confirmación aparte y avisa de que **no se puede deshacer**. Lo escribe el servidor, nunca el cliente (RF-CNF-04) |
| 1.11 | Entra con un correo inventado, por ejemplo `nadie@gmail.com` | «Correo o contraseña incorrectos» — **nunca** «ese correo no existe»: distinguirlo permitiría averiguar quién tiene cuenta |
| 1.12 | Reduce la ventana del navegador a ancho de teléfono | Nada se desborda. El menú del panel pasa a cajón desplegable; el nombre cede el sitio en la barra |
| 1.13 | Instala la PWA desde el navegador | El icono es el escudo completo, y bajo él dice **SIAN UMG-BDM**. En Android el anillo con «UNIVERSIDAD MARIANO GÁLVEZ» se ve **entero**, sin recortar por los bordes |
| 1.14 | Mira el icono de la pestaña del navegador | **No** es el escudo: es la marca reducida, anillo rojo y campo azul con la inicial. A ese tamaño el escudo completo es ilegible |

### Criterio de salida

- [ ] Los cuatro roles entran y ven exactamente lo que su rol permite (1.2, 1.4, 1.5, 1.6)
- [ ] La comparación 1.7 contra 1.8 muestra la diferencia entre abierto y confirmado
- [ ] Ningún mensaje de error revela si un correo existe (1.11)
- [ ] Nada desborda en ancho de teléfono (1.12)
- [ ] El branding institucional es correcto en aplicación, pestaña e icono instalado

---

## Ronda 2 — Lista blanca y alta de usuarios

**Estado: lista para probar.**

> **Antes de empezar, reinicia los emuladores.** Esta ronda estrena las
> primeras Cloud Functions, y el emulador solo carga las definiciones al
> arrancar. Si los tenías corriendo desde la ronda 1, deténlos con `Ctrl+C` y
> vuelve a levantarlos.

### Qué desbloquea

Que un usuario **que no existe todavía** pueda entrar por primera vez, y que el sistema le
cree el perfil y le siembre el rol a partir de la invitación. Es el corazón de RF-AUT-03.

### Alcance

**Sí se valida:** registro con correo y contraseña, la lista blanca como única
puerta de entrada, alta automática de perfil y rol al primer acceso, rechazo
explicativo con su asiento en bitácora, carga masiva por CSV, cambio de rol,
autorizaciones finas, desactivación y reactivación, y consulta filtrada de la
bitácora.

**No se valida todavía:** inicio de sesión con Google, grupos desde la interfaz
—las Functions existen, la pantalla llega después—, envío de mensajes,
notificaciones y programación.

### Pasos

| # | Acción | Resultado esperado |
|---|---|---|
| 2.1 | Entra como `coordinacion@umg.edu.gt` → **Usuarios** → pestaña Invitaciones | Ves las invitaciones sembradas, las no usadas primero |
| 2.2 | Pulsa **Invitar**, modo «Una a una». Correo `nuevo.docente@umg.edu.gt`, rol Catedrático | Aparece en la lista como **sin usar** |
| 2.3 | Cierra sesión → **¿No tienes cuenta? Regístrate** | El aviso de lista blanca aparece **antes** del formulario, no después de fallar |
| 2.4 | Registra `nuevo.docente@umg.edu.gt` con contraseña `Aula#Magna2047` | Entra directo a su bandeja, ya con rol de catedrático |
| 2.5 | Prueba una contraseña débil, por ejemplo `abc` | Enumera **todos** los incumplimientos de una vez, no uno cada vez |
| 2.5a | Prueba `Password#2047` | Rechazada por **demasiado conocida**, aunque cumpla longitud y composición |
| 2.5b | Prueba una que contenga tu propio correo, por ejemplo `Nuevo.Docente#47` | Rechazada: sería lo primero que probaría quien te conoce |
| 2.5c | Prueba `Xk#Trueno1234` | Rechazada por **secuencia obvia** |
| 2.5d | Escribe `Trueno#47x` y ve alargándola | La barra de fuerza sube al alargar. Es la señal: **la longitud pesa más que añadir otro símbolo** |
| 2.6 | Vuelve como coordinador → Usuarios → Invitaciones | La invitación de 2.2 aparece ahora como **ya usada**, y sin botón de revocar |
| 2.7 | Pestaña Usuarios | `nuevo.docente` aparece en la lista con su rol |
| 2.8 | **Bitácora** → filtro «Altas de usuario» | Hay un `USUARIO_CREADO` con actor, rol y fecha |
| 2.9 | Cierra sesión y regístrate con `intruso@gmail.com` | **Rechazo explicativo.** No se crea perfil, y la credencial se borra |
| 2.10 | Vuelve como coordinador → Bitácora → filtro «Accesos rechazados» | Hay un `SESION_RECHAZADA` **destacado en rojo**, con el correo del intento. Es el criterio de aceptación literal de RF-AUT-03 |
| 2.11 | Repite 2.9 con el mismo correo | Vuelve a rechazarse. No queda ninguna cuenta huérfana acumulándose |
| 2.11a | En el ingreso, escribe un usuario y contraseña incorrectos | **Ambos campos se borran** y el cursor vuelve al correo. El mensaje de error sigue visible |
| 2.12 | Usuarios → despliega `admin2` → activa «Puede emitir alertas urgentes» | Confirmación. En Bitácora queda el cambio anotado |
| 2.13 | Despliega un catedrático → cambia su rol a Auditor | Se aplica, y al volver a entrar esa cuenta ve solo Entregas y Bitácora |
| 2.14 | Intenta cambiar **tu propio** rol | Se rechaza: dejarías el sistema sin quien lo administre |
| 2.15 | Desactiva la cuenta de `nuevo.docente` | Confirmación, con el aviso de que su historial se conserva |
| 2.16 | Cierra sesión y entra con `nuevo.docente` | «Cuenta desactivada», **distinto** de «no autorizado» (RN-10) |
| 2.17 | Reactívala y vuelve a entrar | Entra con normalidad, con su historial intacto |
| 2.18 | Invitar → modo **CSV**, con una línea buena y una mala a propósito | Informa cuántas creó y cuántas rechazó, con el **número de línea** y el motivo de cada rechazo |
| 2.19 | Revoca una invitación sin usar | Desaparece de la lista, con asiento en bitácora |
| 2.20 | Entra como `admin1` e intenta llegar a Usuarios o Bitácora | No están en su menú. Y si forzaras la ruta, las Functions rechazarían igual (RN-01) |

### Criterio de salida

- [ ] Un correo invitado puede registrarse y queda con su rol (2.2 a 2.4)
- [ ] Un correo **no** invitado es rechazado, sin perfil y con asiento (2.9, 2.10)
- [ ] La desactivación se distingue del no autorizado y es reversible (2.15 a 2.17)
- [ ] El CSV informa cada línea rechazada con su número (2.18)
- [ ] Ninguna contraseña débil, conocida o personal se acepta (2.5 a 2.5d)
- [ ] Un fallo de credenciales limpia el formulario y devuelve el foco (2.11a)
- [ ] Ningún rol ve secciones que no le corresponden (2.20)

### Fuera de alcance

Google, grupos desde la interfaz, envío de mensajes, notificaciones y
programación.

---

## Ronda 3 — Google, dispositivos e instalación en iOS

**Estado: desplegada y lista para probar** en **https://sian-umg-bdm-dev.web.app**

> Esta ronda corre contra el proyecto real, no contra emuladores. FCM no tiene emulador, así
> que la llegada de una notificación solo se comprueba aquí. Puedes probar desde cualquier
> equipo o teléfono; no hace falta tener nada encendido en tu Mac.

### Alcance

**Sí se valida:** inicio de sesión con la cuenta de Google, la lista blanca aplicándose
también a Google, permiso de notificaciones, registro del dispositivo, notificación de
prueba real, guía para revertir un permiso denegado, e instructivo de instalación en iOS con
detección automática.

**No se valida todavía:** redactar y enviar mensajes, programación, recurrencia y
confirmación de lectura. La notificación que llega en esta ronda es la **de prueba** que
emite el registro del dispositivo, no un aviso redactado por nadie.

### Qué desbloquea

Entrar con la cuenta institucional de Google, registrar el dispositivo y recibir la primera
notificación real.

### Pasos

| # | Acción | Resultado esperado |
|---|---|---|
| 3.1 | Abre la aplicación | **Entrar con Google** aparece arriba, antes del formulario |
| 3.2 | Entra con Google usando un correo **invitado** | Mismo resultado que con contraseña, mismo rol. El selector de cuenta aparece siempre |
| 3.3 | Cierra sesión y entra con Google con un correo **no** invitado | Pantalla roja de acceso no autorizado. Sin perfil, y con asiento en bitácora |
| 3.4 | Como coordinador, invita tu correo con rol **Catedrático** y entra con él | Aterrizas en la bandeja, con la tarjeta de notificaciones arriba |
| 3.5 | Pulsa **Activar notificaciones** y concede el permiso | La tarjeta pasa a verde y **llega una notificación de prueba real** |
| 3.6 | Revisa la bitácora como coordinador | Hay un asiento del registro del dispositivo, con plataforma y si la PWA está instalada |
| 3.7 | Deniega el permiso en otro navegador | La tarjeta se pone roja y explica **dónde** desbloquearlo en ese navegador concreto (RES-07) |
| 3.8 | Cierra la pestaña y pide que te vuelvan a registrar el dispositivo | Llega la notificación **con la aplicación cerrada** (RF-ENT-06) |
| 3.9 | Abre la aplicación en **Safari en iPhone**, sin instalar | Aparece el **instructivo de instalación** antes que la bandeja, no escondido en una ayuda |
| 3.10 | Ábrela en **Chrome en iPhone** | El instructivo avisa de que solo Safari puede añadir a la pantalla de inicio |
| 3.11 | Pulsa «Seguir sin instalar» | Entras a la bandeja, con la advertencia de que no te avisará de nada |
| 3.12 | Instala en la pantalla de inicio y abre desde el icono | El instructivo ya no aparece. El icono es el escudo y dice SIAN UMG-BDM |
| 3.13 | Activa las notificaciones desde la PWA instalada | Ahora sí llegan. En bitácora el dispositivo consta como instalado |
| 3.14 | Abre y cierra la aplicación varias veces | El identificador se refresca solo en cada apertura — mitigación del riesgo R-01 |
| 3.15 | Con la aplicación **instalada** y cerrada, pide que te manden dos avisos | Sobre el icono aparece el número **2** |
| 3.16 | Abre la aplicación y mira la fila de filtros | Dice **Sin leer (2)**: el mismo número que traía el icono |
| 3.17 | Abre los dos avisos y sal | El número desaparece del icono. **No** queda un «0» pegado |
| 3.18 | Abre uno que pida confirmación, no lo confirmes y sal | El icono **no** muestra número. La insignia cuenta lo que está sin abrir, no lo que está sin confirmar |
| 3.19 | Repite 3.15 desde una **pestaña** del navegador, sin instalar | No aparece ningún número, y las notificaciones siguen llegando igual: la insignia necesita un icono donde pintarse |

### Criterio de salida

- [ ] Google entra y respeta la lista blanca igual que el correo y contraseña (3.2, 3.3)
- [ ] Llega una notificación real a un dispositivo real (3.5)
- [ ] Un permiso denegado explica dónde revertirse, en ese navegador (3.7)
- [ ] En iPhone sin instalar, el instructivo aparece solo (3.9)
- [ ] Instalada en iPhone, las notificaciones llegan (3.13)
- [ ] El número del icono coincide con el del filtro «Sin leer», y desaparece al leerlo todo (3.15, 3.16, 3.17)

### Fuera de alcance

Redactar y enviar mensajes, programación, recurrencia y confirmación de lectura.

> **La comparación que más importa de esta ronda es 3.9 contra 3.13.** Es donde se ve, en un
> dispositivo real, que sin instalar la PWA un catedrático con iPhone está incomunicado sin
> saberlo. Es el riesgo R-02 del documento 02, y el mayor riesgo de adopción del proyecto.

> **Ojo con esta ronda.** Es donde se materializa o se descarta el riesgo R-02: si el
> catedrático no instala la PWA, en iOS **no hay notificaciones en absoluto**.

### Android y escritorio: nada que probar aquí

Las notificaciones llegan **en una pestaña normal, sin instalar nada**. Instalar es opcional y
lo resuelve el propio navegador con su botón. No hay nada que SIAN tenga que explicar, así que
no se prueba ni se muestra ningún aviso: sería estorbar sin motivo.

Que en iPhone no llegue **ninguna** notificación sin instalar es precisamente lo que hace de
iOS el único caso especial, y lo único que justifica el instructivo. Los pasos 3.9 a 3.13 lo
cubren.

### Ronda 3-bis — reprueba de lo corregido (4 de agosto de 2026)

Tres hallazgos de la primera pasada, ya corregidos. Estos pasos son los que los verifican.

| # | Qué hacer | Qué debe ocurrir |
|---|---|---|
| 3.15 | Entra con un correo **no invitado** y pulsa «Volver al inicio de sesión» | Vuelve al formulario. Antes el botón no hacía nada: la pantalla se quedaba clavada |
| 3.16 | Repite 3.15 con Google en vez de correo | Mismo resultado: el botón funciona en los dos caminos |
| 3.17 | En iPhone, **primer** intento de «Entrar con Google» del día | Abre el selector de cuenta de Google. Antes moría en un `400. That's an error` y solo funcionaba al segundo intento |
| 3.18 | Abre el sitio en Safari en iPhone, **sin entrar** | Al pie del formulario aparece «Instálala en tu iPhone». Antes no había ninguna pista, y en iPhone ningún navegador ofrece botón de instalar |
| 3.19 | Toca ese aviso | Se abre el instructivo, con el paso de **Compartir** explícito — el botón del cuadrado con la flecha, no el menú de los tres puntos |
| 3.20 | Repite 3.18 desde Chrome en iPhone | Avisa de que solo Safari puede añadir a la pantalla de inicio. En Chrome para iOS **no se puede**, es una restricción de Apple |

> **Sobre 3.17.** Se intentó arreglar apuntando la autenticación al mismo dominio del sitio, y
> el remedio fue peor: el cliente de OAuth en Google Cloud solo autoriza el redirector de
> `.firebaseapp.com`, así que entrar con Google dejó de funcionar del todo con
> `Error 400: redirect_uri_mismatch`. Está revertido. El primer intento en Safari puede volver
> a fallar; el segundo entra. Ver la nota al final de esta sección.

### Antes de probar el ingreso con correo y contraseña

**Comprueba primero que esa cuenta existe con contraseña.** Es la causa más frecuente de
«no me reconoce las credenciales», y no es un fallo:

- Entrar con Google **no crea contraseña**. Una cuenta creada así solo entra por Google.
- Un correo que no estaba en la lista blanca queda **sin credencial**: el servidor la borra al
  rechazarlo, para no dejar cuentas huérfanas. Volver a intentarlo con ese correo dará
  «credenciales incorrectas», que es lo correcto.

Para tener una cuenta con contraseña: invítala primero desde Usuarios, y **regístrala** con
«¿No tienes cuenta? Regístrate», no con «Entrar».

Puedes ver qué credenciales existen de verdad:

```bash
npx firebase auth:export /tmp/usuarios.json --project sian-umg-bdm-dev --format=json
```

> **La recuperación de contraseña responde lo mismo exista o no la cuenta.** Es deliberado
> (RF-AUT-05): si dijera «ese correo no está registrado», cualquiera podría averiguar qué
> correos tienen cuenta probando uno por uno. El coste es que, al probar, un correo que no
> llega es indistinguible de un fallo. Si no llega nada, comprueba con el comando de arriba que
> la cuenta existe **y tiene contraseña**, y mira la carpeta de correo no deseado: el remitente
> es `noreply@sian-umg-bdm-dev.firebaseapp.com` y los filtros lo mandan ahí a menudo.

---

## Ronda 4 — Composición y envío inmediato

**Lista.** Es la iteración 1.3 y **el momento en que el sistema hace lo que promete**.

### Qué desbloquea

Escribir un aviso y que llegue a un teléfono real con la aplicación cerrada.

### Antes de empezar

Necesitas **dos cuentas**: la tuya de coordinación para redactar, y una de catedrático —en el
teléfono— para recibir. Con la del catedrático entra al menos una vez y activa las
notificaciones: sin dispositivo registrado no hay a dónde entregar (RN-02).

### Pasos

| # | Acción | Resultado esperado |
|---|---|---|
| 4.1 | En **Mensajes**, escribe un título muy largo | Se corta a los 80 caracteres y el contador lo dice. Igual el cuerpo a los 500 (RF-MSG-06) |
| 4.2 | Pulsa **Enviar ahora** con el formulario vacío | Avisa de lo que falta y **no llega ni a contar** destinatarios |
| 4.3 | Redacta un aviso informativo a **todos los catedráticos** y pulsa enviar | Antes de nada muestra el **conteo exacto**: «llegará a N personas» (RF-USR-07) |
| 4.4 | Si hay cuentas desactivadas, míralo en ese mismo diálogo | Dice **cuántas quedan fuera y por qué**. «43 de 45» sin motivo no ayudaría a nadie |
| 4.5 | Pulsa **Cancelar** | No se envía nada. El texto sigue escrito |
| 4.6 | Vuelve a enviar y confirma | Aviso de éxito con cuántos lo recibieron, y el formulario se limpia |
| 4.7 | Comprueba en el teléfono, **con la aplicación cerrada** | Llega en menos de 30 segundos (RNF-01) |
| 4.8 | Redacta una **alerta urgente** y envíala | Tras el conteo pide una **segunda confirmación distinta**, en rojo (RF-MSG-13) |
| 4.9 | Cancela en esa segunda confirmación | No se envía. El botón de enviar **no cuenta** como confirmación |
| 4.10 | Envíala de verdad | Llega con **«URGENTE ·»** delante y no se descarta sola |
| 4.11 | En **Grupos**, crea uno con un catedrático dentro y envía **solo a ese grupo** | El conteo refleja el grupo, no a todos |
| 4.12 | Mete al mismo catedrático en dos grupos y envía a ambos | Recibe **un solo aviso**, no dos |
| 4.13 | Como `admin2` **sin** autorización de urgentes, mira la clasificación | La opción **Urgente** está bloqueada y explica por qué |
| 4.13a | Como **coordinador**, mira la misma opción | **Disponible**, sin necesidad de bandera: la matriz le da alcance total (documento 01, §2.2) |
| 4.14 | Envía a alguien que nunca registró dispositivo | Consta como **no entregado**, con el motivo, y a los demás sí les llega |
| 4.15 | Revisa la **bitácora** | Hay dos asientos por envío: creación y resultado, con cuántos y a cuántos |

### Grupos de destinatarios (RF-USR-03, RF-USR-04, DT-08)

Un grupo decide a quién le llega una alerta de emergencia. Equivocarse de grupo al redactar es
enviar un aviso a veinte personas creyendo que van cuarenta y cinco, y eso no se descubre hasta
que alguien pregunta por qué no le avisaron.

| # | Acción | Resultado esperado |
|---|---|---|
| 4.29 | Entra en **Grupos** por primera vez | Explica para qué sirven, en vez de una lista vacía sin más |
| 4.30 | **Nuevo grupo**, ponle nombre y guarda sin elegir a nadie | No lo guarda: un grupo vacío no le llegaría a nadie |
| 4.31 | Guarda sin nombre | Tampoco. Dice qué falta |
| 4.32 | Elige dos catedráticos y guarda | Aparece en la lista con el **número de miembros** visible en el círculo |
| 4.33 | Fíjate en la lista de personas del editor | Las cuentas **desactivadas** y el auditor no aparecen: no reciben mensajes |
| 4.34 | Usa el buscador con un nombre o un correo | Filtra por ambos |
| 4.35 | Edita el grupo, quita a uno y guarda | El número baja en la lista |
| 4.36 | Pulsa **Desactivar** | Pide confirmación y explica que **no se borra**, para que los avisos ya enviados sigan diciendo a quién fueron |
| 4.37 | Cancela esa confirmación | Sigue activo |
| 4.38 | Desactívalo de verdad y ve a **Mensajes** → Grupos concretos | **No aparece** como destinatario |
| 4.39 | Vuelve a Grupos y **Reactiva** | Sin confirmación —no destruye nada— y vuelve a estar disponible al redactar |

> **El paso que más enseña es 4.38.** Un grupo desactivado sigue en la lista de administración
> —tachado, con su historia— pero desaparece de los destinatarios elegibles. Ofrecerlo sería
> tender la trampa: el servidor rechaza el envío a un grupo inactivo.

### Nota de voz e imagen (RF-MSG-03, 04, 05, 07, 08 · RF-ENT-08, 09)

Una nota de voz existe porque **escribir con prisa es difícil**: quien tiene que avisar de una
fuga de gas no va a redactar 500 caracteres.

| # | Acción | Resultado esperado |
|---|---|---|
| 4.16 | Pulsa **Grabar nota de voz** y concede el micrófono | Empieza a contar, con barra y segundos restantes |
| 4.17 | Habla unos segundos y detén | Queda adjunta, con su duración y su peso |
| 4.18 | Graba y **deja pasar los 60 segundos** | Se **corta sola** al llegar al límite y lo dice. La grabación se conserva (RF-MSG-07) |
| 4.19 | Deniega el permiso del micrófono y vuelve a intentarlo | Explica **dónde** se vuelve a permitir, no un «no se pudo» |
| 4.20 | Mientras grabas, mira el indicador del teléfono | Al detener o salir de la pantalla, **se apaga**. El micrófono no puede quedarse abierto |
| 4.21 | **Adjuntar imagen** y elige una foto | Aparece con vista previa, nombre y peso |
| 4.22 | Intenta adjuntar un PDF | Rechazo con motivo: solo JPEG, PNG y WebP (RF-MSG-08) |
| 4.23 | Intenta una imagen de más de 5 MB | Rechazo con motivo, **antes** de subir nada |
| 4.24 | Quita un adjunto con la ✕ | Desaparece. El texto sigue intacto |
| 4.25 | Envía un aviso con **texto, voz e imagen** a la vez | Se suben los dos y el aviso sale (RF-MSG-05) |
| 4.26 | En el teléfono del catedrático, abre la bandeja | La nota de voz **se reproduce** y la imagen se ve (RF-ENT-08, 09) |
| 4.27 | Toca la imagen | Se amplía a pantalla completa y se puede acercar |
| 4.28 | Graba en **Safari** y escucha en **Chrome**, y al revés | Se oye en los dos. Safari graba `mp4` y Chrome `webm`, y el reproductor entiende ambos |

### Criterio de salida

- [ ] Un aviso llega a un teléfono real con la aplicación **cerrada** (4.7)
- [ ] Una urgente exige **dos** confirmaciones y cancelar en la segunda no envía (4.8, 4.9)
- [ ] El conteo previo coincide con lo que de verdad se envía (4.3, 4.11)
- [ ] Quien está en dos grupos recibe **una** vez (4.12)
- [ ] Una alerta urgente **con voz e imagen** llega a un Android y a un iPhone reales, con la
      aplicación cerrada, en menos de 30 segundos (4.25, 4.26) — es el criterio de la
      iteración 1.3
- [ ] El micrófono se suelta siempre (4.20)
- [ ] Un grupo desactivado desaparece de los destinatarios elegibles (4.38)
- [ ] Cada envío deja su rastro en bitácora (4.15)

### Fuera de alcance

Programación, recurrencia y confirmación de lectura: son la ronda 5.

> **Lo que de verdad se pone a prueba aquí es 4.7.** Todo lo demás es interfaz; ese paso es el
> criterio de la iteración 1.3 y la razón de ser del sistema. Si un aviso no llega a un
> teléfono con la aplicación cerrada, nada del resto importa.

> **Y 4.9 es el que protege de un accidente.** Una alerta urgente hace sonar el teléfono de
> todos los catedráticos. Que el botón de enviar no baste para dispararla es lo que separa un
> simulacro de un incidente.

---

## Ronda 5 — Programación, recurrencia y confirmación

**Lista.** Es la iteración 1.4 y **cierra el ciclo funcional del sistema**.

### Qué desbloquea

Dejar un aviso preparado para que salga solo, repetirlo mientras haga falta, y saber con
evidencia quién declaró haberlo leído.

### Antes de empezar

El planificador corre **cada minuto**. Para no esperar de más, programa a **2 o 3 minutos
vista** en vez de a una hora.

### Programar a fecha y hora (RF-PRG-02, 03, 04)

| # | Acción | Resultado esperado |
|---|---|---|
| 5.1 | Redacta un aviso y elige **En una fecha y hora** | Aparecen los selectores de fecha y hora |
| 5.2 | Pulsa programar sin elegir fecha | Avisa de que falta, y no programa |
| 5.3 | Elige una hora **ya pasada** | Rechazo: «esa fecha y hora ya pasaron» (RF-PRG-04) |
| 5.4 | Programa para dentro de 3 minutos y confirma | Aviso de programado. El botón decía **Programar envío**, no «Enviar ahora» |
| 5.5 | Ve a **Programación** | Aparece con su próxima salida y estado *Programado* |
| 5.6 | Espera a la hora, con el teléfono cerrado | **Llega solo**, sin que nadie toque nada (RNF-01) |
| 5.7 | Vuelve a Programación | Ahora dice *Enviado* y ya **no ofrece** suspender ni cancelar (RN-03) |

### Repetición (RF-PRG-05..09)

| # | Acción | Resultado esperado |
|---|---|---|
| 5.8 | Elige **Repetido cada cierto tiempo** | Aparecen intervalo, rango de fechas, hora y días |
| 5.9 | Intenta programar sin ver las próximas fechas | **No deja**: hay que mirarlas antes (RF-PRG-09) |
| 5.10 | Deja la fecha de fin vacía | Avisa de que es obligatoria: una repetición sin fin es un envío sin freno |
| 5.11 | Pon «cada 1 día, a las 07:00, lunes y miércoles» y pulsa ver fechas | Salen hasta **10 fechas concretas**, y todas caen en lunes o miércoles |
| 5.12 | Cambia a «cada 2 minutos» y vuelve a ver | Las fechas cambian. **Cambiar el patrón borra la vista previa**: hay que volver a mirarla |
| 5.13 | Programa una repetición cada 2 minutos, con fin en 10 minutos | Llegan varias, separadas 2 minutos |
| 5.14 | Deja correr hasta la fecha de fin | Se detiene sola. El estado pasa a *Repeticiones agotadas* |

### Suspender y cancelar (RF-PRG-10, 11)

| # | Acción | Resultado esperado |
|---|---|---|
| 5.15 | En una repetición activa, pulsa **Suspender** | Se detiene **sin pedir confirmación**: se puede deshacer |
| 5.16 | Comprueba que no llega nada mientras está suspendida | Silencio |
| 5.17 | Pulsa **Reanudar** | Vuelve a salir |
| 5.18 | Pulsa **Cancelar** | **Sí pide confirmación**, y explica la diferencia con suspender |
| 5.19 | Fíjate en el botón de descartar ese diálogo | Dice **«No, dejarla activa»**, no «Cancelar»: dos botones diciendo lo mismo con significados opuestos sería una trampa |
| 5.20 | Confirma la cancelación | Se detiene definitivamente y ya no ofrece reanudar |

### Confirmación de lectura (RF-CNF-01..07)

| # | Acción | Resultado esperado |
|---|---|---|
| 5.21 | Envía un aviso con **Exigir confirmación de lectura** | Llega al catedrático con el botón **Confirmar lectura** activo |
| 5.22 | Abre la bandeja **sin** confirmar, y mira el reporte de entregas | Consta como **abierto**, no como confirmado. Es RF-CNF-02 en pantalla |
| 5.23 | Pulsa Confirmar lectura | Pide confirmación y avisa de que **no se puede deshacer** |
| 5.24 | Cancela ahí | No confirma nada |
| 5.25 | Confirma de verdad | Mensaje de éxito, y el botón desaparece |
| 5.26 | Vuelve a intentarlo desde otro dispositivo | «Ya estaba confirmado». Una confirmación no se repite (RF-CNF-05) |
| 5.27 | Como coordinador, ve a **Entregas** | Barra de progreso, entregados y **porcentaje de confirmación** |
| 5.27a | Mira la fecha de cada aviso | Dice **cuándo se envió**, no cuándo saldrá. Un envío inmediato también la tiene |
| 5.27b | Mira un aviso recurrente | Dice **última salida** y, aparte, la próxima. «Enviado el…» sería engañoso en algo que sale una y otra vez |
| 5.28 | Con 1 de 2 confirmados, mira el porcentaje | **50 %**, no 100 %. Se calcula sobre el TOTAL, no sobre los entregados |
| 5.28a | Mira ahora un aviso que **no** exigía confirmación | Dice «no exigía confirmación» y su barra mide **entrega**. **No** dice «faltan N por confirmar»: nadie tenía que confirmarlo |
| 5.28b | Comprueba que tampoco marca 100 % de confirmación | Sería igual de falso: afirmaría que confirmaron algo que nunca se les pidió |
| 5.29 | Revisa la **bitácora** | Hay asiento de programación, de cada ocurrencia disparada y de cada confirmación |

### Idempotencia y retraso (RF-PRG-12, 13, 14)

| # | Acción | Resultado esperado |
|---|---|---|
| 5.30 | Deja una repetición corriendo 15 minutos | **Ni un solo aviso duplicado**. El despachador puede solaparse consigo mismo y no debe notarse |
| 5.31 | Programa algo, y comprueba una hora después | Si venció hace más de 30 minutos, **no sale**: queda *omitida* con su asiento. Nadie quiere el aviso de un simulacro de anteayer |

### Criterio de salida

- [ ] Un aviso programado llega **solo**, con el teléfono cerrado (5.6)
- [ ] Una repetición produce las fechas que la vista previa prometió (5.11, 5.13)
- [ ] No se puede programar una repetición sin haber visto las fechas (5.9)
- [ ] Suspender se deshace; cancelar no, y se avisa (5.15, 5.18)
- [ ] Abrir y confirmar son estados **distintos** (5.22)
- [ ] Una confirmación no se repite ni se deshace (5.26)
- [ ] El porcentaje se calcula sobre el total de destinatarios (5.28)
- [ ] Un aviso sin confirmación exigida se mide por entrega, no por confirmación (5.28a)
- [ ] **Ningún aviso duplicado** en 15 minutos de repetición (5.30)

> **El paso que más vale de toda la ronda es 5.30.** Un aviso que sale dos veces destruye más
> confianza que uno que no sale: la siguiente vez nadie se lo cree. El despachador corre cada
> minuto y puede solaparse consigo mismo, así que la ausencia de duplicados no es casualidad
> sino tres defensas en capas — y esto es lo único que lo demuestra en la práctica.

## Registro de rondas ejecutadas

| Ronda | Fecha | Quién | Resultado | Incidencias |
|---|---|---|---|---|
| 1 | 3 ago 2026 | Coordinación | Superada | — |
| 2 | 4 ago 2026 | Coordinación | Superada | — |
| 3 | 4 ago 2026 | Coordinación | Superada tras reprueba | Botón muerto tras el rechazo · Google rechazaba el ingreso · sin instructivo en móvil |
| 4 | 8–10 ago 2026 | Coordinación | Superada tras reprueba | Adjuntos perdidos · audio mudo al primer intento · envío con adjunto a medias |
| 5 | 10 ago 2026 | Coordinación | Superada | — |

> Las tres rondas que necesitaron reprueba tienen algo en común: **el defecto
> no estaba en lo que se probaba, sino en lo que se daba por hecho**. El botón
> de volver, los adjuntos que se subían pero no se declaraban, el permiso de
> notificaciones que la propia aplicación se denegaba. Ninguno habría salido de
> una prueba de escritorio.

## Hallazgos posteriores a las rondas

Encontrados usando el sistema, no ejecutando el guion. Se anotan aquí porque
cada uno señala un paso que al guion le falta.

| Hallazgo | Qué lo destapó | Paso que hay que añadir |
|---|---|---|
| La insignia del icono no aparecía nunca en iPhone | Instalar la aplicación y mandarse un aviso | Probar la insignia **en el aparato instalado**, no solo con pruebas |
| La insignia decía 3 donde había 1 mensaje | Un aviso que necesitó sus reintentos de entrega | Comprobar el número **después de un reintento**, no solo tras una entrega limpia |
| La bandeja tardaba segundos en mostrar el aviso nuevo | Abrir la aplicación al recibir uno | Cronometrar **desde que se abre hasta que aparece**, no solo que aparezca |
| Un mensaje abierto se veía igual que uno cerrado | Leer cuatro avisos seguidos en el celular | Abrir un mensaje **y mirar la lista**, no solo el mensaje |
| La separación del detalle no se veía en los ya leídos | Abrir un mensaje viejo, sin nada pendiente | Probar cada cambio visual **en los cuatro estados**, no solo en el que se estaba mirando |
| La bandeja no abría con una cuenta de catedrático | Entrar con un catedrático real | Recorrer **cada ronda** con una cuenta de cada rol, no solo con la de coordinación |
| Un icono nuevo tardaba una semana en aparecer | Un despliegue con un botón nuevo | Comprobar los cambios en la **aplicación instalada**, no solo en una pestaña |
| Girar el teléfono borraba el mensaje a medio escribir | Redactar en el celular | Girar el aparato **en mitad de cada formulario** |
| iOS decía «notificaciones bloqueadas» estándolo | Abrir la aplicación varias veces seguidas | Reabrir la aplicación instalada tres veces y mirar la tarjeta |

> **La insignia merece una nota aparte.** El código llamaba a
> `clearAppBadge()` cuando `registration.getNotifications()` daba cero. En
> Android esa lista trae las notificaciones que siguen en pantalla y todo
> cuadraba; en iOS devuelve vacío para las que muestra el propio service worker,
> así que cada aviso que llegaba **apagaba** la insignia en lugar de encenderla.
> Ninguna prueba podía verlo: la lógica de conteo era correcta y estaba probada,
> y lo que fallaba era una suposición sobre el navegador. Solo aparece con la
> aplicación instalada en un iPhone de verdad, que es exactamente el escenario
> que el guion daba por cubierto.

> **El más caro de todos es el de los roles.** Todas las rondas se recorrieron
> con cuentas de coordinación, que pueden leer los mensajes sin condiciones; la
> pantalla del catedrático nunca se ejecutó con un catedrático. Una prueba con
> el rol equivocado no es media prueba: es ninguna.

## Certificación del ambiente de calidad

Antes de que QA sirva para probar el sistema, hay que probar el ambiente. Un fallo de
aprovisionamiento se disfraza de fallo de la aplicación y se persigue durante horas en el
lugar equivocado, así que estas comprobaciones se hacen primero y se dejan escritas.

Ejecutadas contra `sian-umg-bdm-qa` el 24 de agosto de 2026:

| # | Qué se comprueba | Cómo | Resultado |
|---|---|---|---|
| C-1 | Las reglas de seguridad están puestas | Leer `mensajes` sin autenticar por REST | `PERMISSION_DENIED` |
| C-2 | Las 19 Functions existen y arrancaron | Listar funciones de `us-central1` | 19 de 19 en estado `ACTIVE` |
| C-3 | Las Functions rechazan a quien no se identificó | `POST` a `activarSesion` sin token | HTTP 401, `UNAUTHENTICATED` |
| C-4 | El navegador puede llamarlas | `OPTIONS` con `Origin` de QA | HTTP 204 |
| C-5 | El despachador quedó programado | Listar jobs de Cloud Scheduler | 1 job, cada minuto, `ENABLED` |
| C-6 | La aplicación servida apunta a QA | Leer `/firebase-config.js` del sitio | `projectId: 'sian-umg-bdm-qa'` |
| C-7 | La aplicación arranca de verdad | Abrir el sitio y mirar la consola | Pantalla de ingreso, consola sin errores |
| C-8 | Los manuales y sus imágenes se sirven | Pedir las dos portadas y tres capturas | HTTP 200, `image/png`, tamaño correcto |
| C-9 | Los manuales no se quedan cacheados | Leer la cabecera de `/manuales/` | `cache-control: no-cache` |
| C-10 | La base arranca limpia | Contar documentos de las seis colecciones | `invitaciones` 2 · todo lo demás 0 |
| C-11 | Solo entran los dos usuarios previstos | Leer `invitaciones` | COORDINADOR y CATEDRATICO, uno cada uno |
| C-12 | El código que se desplegó pasa sus pruebas | `npm test`, `flutter test`, lint, analyze | 257 + 290 pruebas, sin hallazgos |
| C-13 | La clave VAPID viaja en el paquete servido | Buscarla dentro de `main.dart.js` ya publicado | presente |
| C-14 | El proveedor de Google quedó habilitado | Consultar `defaultSupportedIdpConfigs` | `google.com` activo |
| C-15 | Google acepta la URL de retorno | Pedir el `authorize` de Google con el `redirect_uri` de QA | HTTP 302 a la pantalla de acceso |

**C-6 no es una formalidad.** El script que genera la configuración cargaba `.env.local`
por encima de las variables exportadas, así que el primer paquete compilado «para QA»
apuntaba a desarrollo y no lo decía. Se detectó porque esta comprobación existe. Mientras
haya más de un ambiente, verificar contra cuál habla el paquete servido es parte del
despliegue, no un extra.

**C-15 tampoco es una formalidad.** En desarrollo, cambiar el dominio de autenticación
dejó el ingreso con Google roto con un `Error 400: redirect_uri_mismatch`, y el síntoma
aparece recién al pulsar el botón, con una cuenta real. La comprobación pide a Google el
`authorize` con la URL de retorno del ambiente y mira si responde: si el `redirect_uri`
no estuviera registrado, Google contesta el error ahí mismo, sin necesidad de entrar con
ninguna cuenta.

Lo que esta certificación **no** cubre es el recorrido completo con cuentas reales:
entrar, redactar, enviar, recibir la notificación en el aparato y confirmar la lectura.
Eso son las rondas 1 a 5, y se recorren con una cuenta de cada rol —la ronda que se
recorrió solo con coordinación fue la que dejó pasar el defecto más caro del proyecto.
