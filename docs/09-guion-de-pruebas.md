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

Todas con contraseña **`Simulacro2026`**:

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

**Pendiente de construir.** Cierra la iteración 1.2.

### Qué desbloqueará

Que un usuario **que no existe todavía** pueda entrar por primera vez, y que el sistema le
cree el perfil y le siembre el rol a partir de la invitación. Es el corazón de RF-AUT-03.

### Pasos previstos

| # | Acción | Resultado esperado |
|---|---|---|
| 2.1 | Como coordinador, registra un correo nuevo en Usuarios con rol Catedrático | Aparece en la lista como invitación **no consumida** |
| 2.2 | Cierra sesión y entra con ese correo por primera vez | Se crea el perfil, se siembra el rol y aterriza en la bandeja |
| 2.3 | Revisa la bitácora como coordinador | Hay un asiento `USUARIO_CREADO` con actor, rol y fecha |
| 2.4 | Intenta entrar con un correo **no** invitado | Rechazo explicativo, **sin** crear perfil |
| 2.5 | Revisa la bitácora otra vez | Hay un asiento `SESION_RECHAZADA` — es el criterio de aceptación literal de RF-AUT-03 |
| 2.6 | Desactiva una cuenta y entra con ella | «Cuenta desactivada». Su historial sigue intacto (RN-10) |
| 2.7 | Carga varios correos por CSV | Todos quedan invitados en una sola operación (RF-USR-01) |
| 2.8 | Crea un grupo y agrégale catedráticos | El conteo de miembros coincide (RF-USR-03, RF-USR-04) |

### Fuera de alcance

Envío de mensajes, notificaciones, programación.

---

## Ronda 3 — Google, dispositivos e instalación en iOS

**Pendiente.** Cierra la iteración 1.2 y **exige desplegar a `sian-umg-bdm-dev`**: los
emuladores no sirven aquí.

### Qué desbloqueará

Entrar con la cuenta institucional de Google, registrar el dispositivo y recibir la primera
notificación real.

### Pasos previstos

| # | Acción | Resultado esperado |
|---|---|---|
| 3.1 | Entra con Google desde un correo invitado | Mismo resultado que con contraseña, mismo rol |
| 3.2 | Entra con Google desde un correo **no** invitado | Rechazo, sin perfil, con asiento en bitácora |
| 3.3 | Concede el permiso de notificaciones | Llega una **notificación de prueba** al registrar el dispositivo |
| 3.4 | Deniega el permiso | La aplicación lo detecta y explica cómo revertirlo (RES-07) |
| 3.5 | Abre en **Safari en iPhone** sin instalar | Aparece el instructivo de instalación **obligatorio** (RES-05) |
| 3.6 | Instala en la pantalla de inicio y vuelve a entrar | El instructivo ya no aparece; el dispositivo queda registrado como PWA instalada |

### Fuera de alcance

Envío de mensajes reales. Aquí solo se prueba la notificación de registro.

> **Ojo con esta ronda.** Es donde se materializa o se descarta el riesgo R-02: si el
> catedrático no instala la PWA, en iOS **no hay notificaciones en absoluto**.

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
