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
- Contenido de las secciones del panel: hoy declaran qué harán y en qué iteración

### Pasos

| # | Acción | Resultado esperado |
|---|---|---|
| 1.1 | Abre la aplicación | Escudo de la UMG, **SIAN UMG-BDM**, nombre completo del sistema, universidad y sede. Pestaña del navegador con el mismo nombre y el escudo como icono |
| 1.2 | Entra con `coordinacion@umg.edu.gt` | Panel con **6 secciones**: Mensajes, Programación, Grupos, Usuarios, Entregas, Bitácora |
| 1.3 | Recorre las 6 secciones | Cada una dice qué hará, qué requisitos cubre y en qué iteración llega |
| 1.4 | Cierra sesión y entra con `admin1@umg.edu.gt` | Mismo panel **sin Usuarios ni Bitácora**. Solo 4 secciones |
| 1.5 | Cierra sesión y entra con `auditoria@umg.edu.gt` | **Solo 2 secciones**: Entregas y Bitácora. Ninguna de emisión |
| 1.6 | Cierra sesión y entra con `catedratico1@umg.edu.gt` | Bandeja, **no** panel. Un mensaje: «Simulacro de evacuación» con distintivo rojo **URGENTE** |
| 1.7 | Observa el estado del mensaje | Dice **Confirmado**, en verde. **No** aparece el aviso de pendientes |
| 1.8 | Cierra sesión y entra con `catedratico2@umg.edu.gt` | El mismo mensaje, pero en estado **Abierto** y **sí** aparece «Tienes 1 alerta urgente sin confirmar» |
| 1.9 | Compara 1.7 con 1.8 | Es RF-CNF-02 en pantalla: **abrir un mensaje no lo confirma**. Son estados distintos y el sistema los trata distinto |
| 1.10 | Pulsa «Confirmar lectura» | El botón está **visible pero inerte**, con la explicación debajo. Confirmar es irreversible y con valor probatorio: solo lo escribirá el servidor (RF-CNF-04) |
| 1.11 | Entra con un correo inventado, por ejemplo `nadie@gmail.com` | «Correo o contraseña incorrectos» — **nunca** «ese correo no existe»: distinguirlo permitiría averiguar quién tiene cuenta |
| 1.12 | Reduce la ventana del navegador a ancho de teléfono | Nada se desborda. El menú del panel pasa a cajón desplegable; el nombre cede el sitio en la barra |
| 1.13 | Instala la PWA desde el navegador | El icono es el escudo, y bajo él dice **SIAN UMG-BDM** |

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

### Criterio de salida

- [ ] Google entra y respeta la lista blanca igual que el correo y contraseña (3.2, 3.3)
- [ ] Llega una notificación real a un dispositivo real (3.5)
- [ ] Un permiso denegado explica dónde revertirse, en ese navegador (3.7)
- [ ] En iPhone sin instalar, el instructivo aparece solo (3.9)
- [ ] Instalada en iPhone, las notificaciones llegan (3.13)

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
| 4.11 | Crea un grupo, mete a un catedrático y envía **solo a ese grupo** | El conteo refleja el grupo, no a todos |
| 4.12 | Mete al mismo catedrático en dos grupos y envía a ambos | Recibe **un solo aviso**, no dos |
| 4.13 | Como `admin2` **sin** autorización de urgentes, mira la clasificación | La opción **Urgente** está bloqueada y explica por qué |
| 4.13a | Como **coordinador**, mira la misma opción | **Disponible**, sin necesidad de bandera: la matriz le da alcance total (documento 01, §2.2) |
| 4.14 | Envía a alguien que nunca registró dispositivo | Consta como **no entregado**, con el motivo, y a los demás sí les llega |
| 4.15 | Revisa la **bitácora** | Hay dos asientos por envío: creación y resultado, con cuántos y a cuántos |

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

**Pendiente.** Es la iteración 1.4.

### Pasos previstos

| # | Acción | Resultado esperado |
|---|---|---|
| 5.1 | Programa un mensaje para dentro de 3 minutos | Llega puntual, con desviación menor a 60 segundos (RNF-04) |
| 5.2 | Programa uno para una hora ya pasada | Rechazo (RF-PRG-04) |
| 5.3 | Crea un recurrente cada 2 minutos con fin en 10 | Antes de guardar muestra las **próximas 10 ocurrencias** (RF-PRG-09) |
| 5.4 | Espera | Llegan exactamente las ocurrencias previstas, ni una más |
| 5.5 | Suspende la recurrencia y reanúdala | Deja de disparar y vuelve a disparar (RF-PRG-10) |
| 5.6 | Cancela un mensaje programado | No se envía nunca (RF-PRG-11) |
| 5.7 | Confirma la lectura desde el teléfono | El panel lo refleja **en tiempo real** |
| 5.8 | Intenta confirmar dos veces | La segunda no hace nada: es irreversible y no se duplica (RF-CNF-04, RF-CNF-05) |
| 5.9 | Consulta quién confirmó y quién no | Porcentaje sobre el total de destinatarios (RF-CNF-07) |
| 5.10 | Revisa la trazabilidad de un mensaje | Ciclo de vida completo, destinatario por destinatario (RF-BIT-07, RF-BIT-08) |

### Criterio de salida

El de la iteración 1.4: **toda la lista de verificación del documento 06, etapa E.6, incluida
la prueba de resistencia en iOS de 20 notificaciones durante 24 horas.**

Si esa prueba falla, no se cruza la puerta a la fase 2 hasta implementar la redundancia por
correo (DT-03). No se lleva a usuarios reales un canal de alertas que puede callar sin avisar.

---

## Registro de rondas ejecutadas

| Ronda | Fecha | Quién | Resultado | Incidencias abiertas |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |
