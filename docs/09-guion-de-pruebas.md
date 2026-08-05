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

> **Si 3.17 vuelve a fallar**, anótalo pero sigue: el segundo intento entra igual. La causa era
> que la autenticación viajaba por un dominio distinto al del sitio y Safari lo bloqueaba la
> primera vez; ya apuntan al mismo, pero conviene confirmarlo en un iPhone real y en frío.

---

## Ronda 4 — Composición y envío inmediato

**Pendiente.** Es la iteración 1.3 y **el momento en que el sistema hace lo que promete**.

### Qué desbloqueará

Escribir un aviso y que llegue a un teléfono real con la aplicación cerrada.

### Pasos previstos

| # | Acción | Resultado esperado |
|---|---|---|
| 4.1 | Como administradora, redacta un aviso informativo de solo texto | Validaciones de 80 y 500 caracteres al pasarse (RF-MSG-06) |
| 4.2 | Envíalo a un grupo | Antes de confirmar, muestra el **conteo exacto** de destinatarios (RF-USR-07) |
| 4.3 | Comprueba en el teléfono | Llega con la aplicación **cerrada**, en menos de 30 segundos (RNF-01) |
| 4.4 | Redacta una alerta **urgente** | Al enviar, exige una **segunda confirmación** distinta del botón inicial (RF-MSG-13) |
| 4.5 | Cancela en esa segunda confirmación | El mensaje queda en borrador, no se envía |
| 4.6 | Envíala de verdad | Llega con sonido y vibración en Android; en iOS con prefijo «URGENTE» (DT-02) |
| 4.7 | Graba una nota de voz y adjunta una imagen | Se reproducen desde el detalle (RF-ENT-08, RF-ENT-09) |
| 4.8 | Intenta una nota de voz de más de 60 segundos | Rechazo con explicación (RF-MSG-07) |
| 4.9 | Como `admin2`, intenta emitir una urgente | **No puede**: no tiene la autorización fina |
| 4.10 | Revisa la bitácora | Cada paso anterior dejó su asiento |

### Criterio de salida

El de la iteración 1.3 del documento 08: **una alerta urgente con voz e imagen llega a un
Android real y a un iPhone real, con la aplicación cerrada, en menos de 30 segundos.**

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
