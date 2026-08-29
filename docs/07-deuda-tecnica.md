# 07 — Registro de deuda técnica

**Versión:** 1.0 · 2 de agosto de 2026

Este documento es de actualización obligatoria. Toda decisión que sacrifique calidad,
funcionalidad o robustez por razones de costo, tiempo o alcance se registra aquí **en el
momento de tomarla**, no después.

## Cómo se clasifica

| Campo | Valores |
|-------|---------|
| **Origen** | Costo · Alcance · Plataforma · Tiempo · Conocimiento |
| **Severidad** | Alta (afecta la operación) · Media (afecta la calidad) · Baja (afecta la comodidad) |
| **Estado** | Abierta · Mitigada · Pagada · Aceptada permanentemente |

---

## Deuda registrada

### DT-01 · Sin aplicación nativa ni distribución por tiendas

| | |
|---|---|
| **Origen** | Alcance y costo |
| **Severidad** | Alta |
| **Estado** | Abierta — aceptada para la versión 1 |
| **Decisión** | La aplicación se distribuye exclusivamente como PWA vía Firebase Hosting |
| **Motivo** | Requisito explícito de no usar tiendas. App Store exige 99 USD anuales y un proceso de revisión que retrasaría semanas la validación |
| **Consecuencia** | Las notificaciones en iOS dependen de la implementación web de Apple, que es menos capaz y menos confiable que APNs nativo. En Android se pierde el acceso a canales de notificación completos y a alarmas exactas |
| **Mitigación actual** | Flutter fue elegido precisamente para poder compilar a nativo sin reescribir. Existe plan de contingencia documentado (documento 02, sección 14) |
| **Plan de pago** | Compilar a Android nativo y distribuir el APK firmado por descarga directa desde Hosting, sin tienda. Costo: 0 USD. Esfuerzo estimado: 2 a 3 días |
| **Disparador para pagarla** | Si la prueba de resistencia del prototipo demuestra pérdida de notificaciones, o si el coordinador reporta que una alerta urgente no llegó |

---

### DT-02 · Sin sonido personalizado ni vibración en iOS

| | |
|---|---|
| **Origen** | Plataforma |
| **Severidad** | Alta |
| **Estado** | Abierta — sin solución técnica dentro del alcance actual |
| **Decisión** | En iOS-PWA, las alertas urgentes se distinguen por prefijo visible en el título y por tratamiento diferenciado dentro de la aplicación |
| **Motivo** | La implementación de Web Push de Safari no expone control de sonido personalizado ni patrones de vibración. No es una limitación del proyecto sino de la plataforma |
| **Consecuencia** | Un catedrático con iPhone recibe la alerta de simulacro con el mismo sonido que cualquier otra notificación. En una emergencia real, eso importa |
| **Mitigación actual** | Prefijo visible «URGENTE» en el título y `requireInteraction`, para que una alerta urgente no se descarte sola. Con la aplicación en primer plano se le pide igualmente al sistema operativo que muestre la notificación, usando el mismo registro de service worker que la entrega en segundo plano: así suena y vibra con los ajustes del dispositivo, en vez de quedarse dentro de la pantalla. Insistencia visual sobre mensajes urgentes no confirmados |
| **Plan de pago** | Solo se resuelve con aplicación nativa en iOS, lo que exige App Store. Costo: 99 USD anuales más el esfuerzo de publicación |
| **Disparador para pagarla** | Decisión institucional de que las alertas de emergencia deben tener tratamiento diferenciado en toda plataforma sin excepción |

---

### DT-03 · Inestabilidad conocida de las notificaciones web en iOS

| | |
|---|---|
| **Origen** | Plataforma |
| **Severidad** | Alta |
| **Estado** | Abierta — pendiente de verificación en el prototipo |
| **Decisión** | Se asume el riesgo en la versión 1, con verificación obligatoria antes de producción |
| **Motivo** | Existen reportes consistentes de la comunidad sobre PWAs en iOS que reciben notificaciones al principio y dejan de recibirlas tras varios envíos, acompañado de un cambio del identificador de dispositivo |
| **Consecuencia** | Riesgo de que un catedrático quede silenciosamente incomunicado sin que él ni el emisor lo sepan |
| **Mitigación actual** | Refresco y sincronización del token en cada apertura de la aplicación. Notificación de prueba automática al registrar el dispositivo. Prueba de resistencia obligatoria de 20 envíos en 24 horas antes de producción |
| **Plan de pago** | Redundancia por correo electrónico para todo mensaje urgente, usando un proveedor transaccional en capa gratuita. Costo: 0 USD. Esfuerzo estimado: 1 día |
| **Disparador para pagarla** | La prueba de resistencia falla, o se detecta cualquier pérdida de notificación en producción |
| **Recomendación** | Implementar la redundancia por correo **desde el prototipo**, no esperar al disparador. Es barata y elimina el riesgo más grave del proyecto |

---

### DT-04 · Control de acceso a adjuntos sin verificación de destinatario

| | |
|---|---|
| **Origen** | Plataforma |
| **Severidad** | Media |
| **Estado** | Abierta |
| **Decisión** | Las reglas de Cloud Storage permiten lectura a cualquier usuario autenticado del sistema |
| **Motivo** | Las reglas de Storage no pueden consultar Firestore para verificar si quien lee es destinatario del mensaje |
| **Consecuencia** | Un usuario autenticado que conozca la ruta exacta de un adjunto podría leerlo aunque no fuera destinatario del mensaje |
| **Mitigación actual** | Las rutas incluyen identificadores aleatorios no adivinables. Todos los usuarios del sistema son personal institucional autorizado, no público general |
| **Plan de pago** | Servir los adjuntos exclusivamente mediante URLs firmadas de vigencia corta, generadas por una Cloud Function que valide la pertenencia contra Firestore. Costo: 0 USD. Esfuerzo estimado: 1 día |
| **Disparador para pagarla** | Antes del paso a producción si se manejará información sensible; en todo caso, en la versión 2 |

---

### DT-05 · Precisión del planificador limitada a 60 segundos

| | |
|---|---|
| **Origen** | Costo |
| **Severidad** | Baja |
| **Estado** | Aceptada permanentemente |
| **Decisión** | Un solo job de Cloud Scheduler por ambiente, ejecutándose cada minuto |
| **Motivo** | Cloud Scheduler incluye 3 jobs gratuitos por cuenta de facturación. Un job por mensaje agotaría la cuota al cuarto mensaje programado |
| **Consecuencia** | Un mensaje programado para las 07:00:00 puede despacharse a las 07:00:45. Cumple RNF-04 pero no permite precisión al segundo |
| **Mitigación actual** | Ninguna necesaria: 60 segundos de desviación es irrelevante para el caso de uso institucional |
| **Plan de pago** | No se pagará. Se acepta de forma permanente |
| **Nota** | Si en el futuro apareciera un requisito de precisión al segundo, la solución no es más jobs sino Cloud Tasks con retraso programado |

---

### DT-06 · Lógica de dominio duplicada entre Dart y TypeScript

| | |
|---|---|
| **Origen** | Conocimiento y plataforma |
| **Severidad** | Media |
| **Estado** | Mitigada |
| **Decisión** | El dominio existe en Dart para Flutter y en TypeScript para las Cloud Functions |
| **Motivo** | Son dos entornos de ejecución distintos. No existe forma directa de compartir código de dominio entre ambos |
| **Consecuencia** | Riesgo de que una regla se corrija en un lado y no en el otro, produciendo comportamiento divergente entre cliente y servidor |
| **Mitigación actual** | Las reglas críticas —cálculo de recurrencia, transiciones de estado, autorización— viven **únicamente en TypeScript**, del lado del servidor. El cliente solo hace validación de conveniencia para dar retroalimentación rápida, y nunca es la fuente de verdad |
| **Plan de pago** | Suite de pruebas de contrato que ejecute los mismos casos contra ambas implementaciones y compare resultados. Esfuerzo estimado: 2 días |
| **Disparador para pagarla** | Al detectar la primera divergencia de comportamiento entre cliente y servidor |

---

### DT-07 · Sin panel de observabilidad ni alertas operativas

| | |
|---|---|
| **Origen** | Alcance |
| **Severidad** | Media |
| **Estado** | **Pagada a medias** desde el 26 de agosto de 2026 |
| **Decisión** | La versión 1 no incluye monitoreo proactivo de fallos de entrega |
| **Motivo** | Reducir el alcance del prototipo para validar más rápido |
| **Consecuencia** | Si el despachador falla o si las entregas empiezan a fallar masivamente, nadie se entera hasta que alguien lo nota |
| **Mitigación actual** | Dos alertas de Cloud Monitoring por ambiente avisan por correo cuando el despachador falla o deja de correr (ver abajo). Los registros de Cloud Functions siguen disponibles en la consola para el diagnóstico |
| **Lo que falta** | El indicador de tasa de entrega en el panel: hoy, saber si los avisos de la semana llegaron sigue exigiendo abrir mensaje por mensaje en Entregas |
| **Plan de pago** | Una tarjeta en el panel con la tasa de entrega y de confirmación de los últimos 7 días, alimentada por lo que ya se guarda en `ocurrencias/entregas`. Esfuerzo estimado: medio día |
| **Disparador para pagarla** | Al abrir a toda la institución, o cuando coordinación pregunte por segunda vez «¿llegó?» sin poder responderse sola |

**Las alertas que ya están puestas.** Las crea `scripts/configurar-alertas.py`, una vez por
ambiente, y avisan a `eurizara1@miumg.edu.gt`:

| Alerta | Salta cuando | Por qué ese umbral |
|---|---|---|
| El despachador está fallando | más de 5 ejecuciones con error en 10 minutos | Corre 60 veces por hora: un fallo suelto es ruido normal, y una alerta que salta con el primero enseña a ignorarla |
| El despachador dejó de correr | ninguna ejecución en 15 minutos | Corre cada minuto, así que quince de silencio no admiten otra lectura |

> **Hacen falta las dos, y la segunda es la que importa.** El despachador puede dejar de
> funcionar de dos maneras que no se parecen: fallando —se ejecuta y revienta, deja errores
> contables— o **callándose**: no se ejecuta, porque murió él o murió el reloj de Cloud
> Scheduler que lo despierta. Callado no produce ningún error, así que una alerta por tasa
> de error miraría un cero y lo daría por bueno. La avería más silenciosa es justo la que
> DT-07 describe.

Cada alerta lleva escrito en su propio cuerpo qué mirar y en qué orden, para que quien la
reciba a las once de la noche no tenga que reconstruirlo. Costo: cero, dentro de la capa
gratuita.

---

### DT-08 · Grupos limitados a 200 miembros por restricción del modelo

| | |
|---|---|
| **Origen** | Alcance |
| **Severidad** | Baja |
| **Estado** | Aceptada para la escala actual |
| **Decisión** | Los miembros de un grupo se guardan como arreglo dentro del documento del grupo |
| **Motivo** | Simplicidad y menor costo de lectura a la escala prevista, de decenas de usuarios |
| **Consecuencia** | Un documento de Firestore no puede superar 1 MiB, y un arreglo grande genera contención de escritura al modificarlo concurrentemente |
| **Mitigación actual** | Validación que impide superar 200 miembros por grupo |
| **Plan de pago** | Migrar los miembros a subcolección `grupos/{id}/miembros/{uid}`. Esfuerzo estimado: 1 día más una migración de datos |
| **Disparador para pagarla** | Al llegar a 150 miembros en cualquier grupo, o al superar los 500 usuarios totales |

---

### DT-09 · Sin traducción ni soporte multi-idioma activo

| | |
|---|---|
| **Origen** | Alcance |
| **Severidad** | Baja |
| **Estado** | Mitigada |
| **Decisión** | La interfaz está solo en español |
| **Motivo** | No hay necesidad institucional de otro idioma |
| **Consecuencia** | Ninguna hoy |
| **Mitigación actual** | Los textos residen en archivos de recursos, nunca incrustados en el código (RNF-21), de modo que agregar un idioma no exige refactorizar |
| **Plan de pago** | Agregar el paquete de internacionalización y el archivo del nuevo idioma. Esfuerzo estimado: menos de 1 día |
| **Disparador para pagarla** | Requerimiento institucional explícito |

---

### DT-10 · Sin cifrado de extremo a extremo del contenido de los mensajes

| | |
|---|---|
| **Origen** | Alcance |
| **Severidad** | Baja |
| **Estado** | Aceptada |
| **Decisión** | Los mensajes se cifran en tránsito y en reposo por la plataforma, pero Google puede leerlos técnicamente |
| **Motivo** | El cifrado de extremo a extremo impediría la búsqueda, la trazabilidad del contenido y la auditoría, que son requisitos del proyecto |
| **Consecuencia** | El contenido de los avisos no es secreto frente al proveedor de nube |
| **Mitigación actual** | Ninguna necesaria: se trata de avisos institucionales, no de información confidencial |
| **Plan de pago** | No se pagará salvo cambio en la naturaleza de la información transmitida |

---

### DT-11 · SDK de Firebase anclado por el requisito de JDK

| | |
|---|---|
| **Origen** | Plataforma y tiempo |
| **Severidad** | Media |
| **Estado** | Abierta |
| **Decisión** | `firebase-tools` queda fijada a `^13.35.1`, y con ella `firebase-functions` a `^6` y `firebase-admin` a `^13` en lugar de la última versión mayor |
| **Motivo** | A partir de la versión 14, `firebase-tools` exige **JDK 21 o superior** para levantar los emuladores. El documento 06, etapa A.1, fija **JDK 17** como requisito del entorno, y esa es la versión instalada en las máquinas de desarrollo actuales. Subir la CLI obligaría a subir el JDK de todo el que replique el proyecto, en mitad de la iteración de cimientos |
| **Consecuencia** | El proyecto no recibe correcciones ni funcionalidad nueva de la línea 14/15 de la CLI. Las versiones 13.x siguen recibiendo mantenimiento, pero no indefinidamente. **Y arrastra al resto del SDK:** el emulador de la CLI 13 no puede cargar Functions escritas con `firebase-functions` 7 —falla con `functions.config() has been removed`—, así que `firebase-functions` queda en `^6` y `firebase-admin` en `^13`. Un ancla se convirtió en tres |
| **Mitigación actual** | La versión está fijada explícitamente en `package.json` y en el flujo de integración continua, de modo que el entorno local y el de CI usan exactamente lo mismo |
| **Plan de pago** | Actualizar a JDK 21 en el documento 06 (etapas A.1 y A.2), y subir **a la vez** `firebase-tools` a 15, `firebase-functions` a 7 y `firebase-admin` a 14. Van juntas: subir una sola rompe el emulador. Costo: 0 USD. Esfuerzo estimado: menos de medio día |
| **Disparador para pagarla** | Cuando la línea 13.x deje de recibir correcciones de seguridad, o cuando se necesite una funcionalidad que solo exista en las versiones nuevas. Descubierto al desplegar las primeras Functions en la iteración 1.2 |

---

### DT-12 · Vulnerabilidades moderadas heredadas de `firebase-admin`

| | |
|---|---|
| **Origen** | Plataforma |
| **Severidad** | Baja |
| **Estado** | Abierta — vigilada |
| **Decisión** | Se acepta instalar `firebase-admin` con 7 vulnerabilidades moderadas reportadas por `npm audit`, todas en dependencias transitivas suyas (`teeny-request` → `retry-request`) |
| **Motivo** | No hay versión de `firebase-admin` publicada que las resuelva. Forzar `npm audit fix --force` degradaría o rompería el SDK oficial, que es peor remedio que la enfermedad |
| **Consecuencia** | El reporte de auditoría de dependencias no está limpio, lo que a la larga entrena a ignorarlo |
| **Mitigación actual** | La integración continua falla solo ante severidad **alta o crítica**, no ante moderada, y `dependabot` avisará en cuanto exista versión corregida. Ninguna de las rutas afectadas se ejecuta con datos controlados por el usuario final |
| **Plan de pago** | Actualizar `firebase-admin` en cuanto publique una versión que cierre el aviso. Costo: 0 USD. Esfuerzo estimado: minutos |
| **Disparador para pagarla** | Publicación de la corrección aguas arriba, o elevación de la severidad a alta |

---

### DT-13 · La política de contraseñas se aplica solo en el cliente

| | |
|---|---|
| **Origen** | Plataforma |
| **Severidad** | Media |
| **Estado** | Abierta |
| **Decisión** | La política reforzada de RF-AUT-06 —longitud, composición, datos personales, listas de uso común, secuencias y repeticiones— se comprueba en la aplicación, no en el servidor |
| **Motivo** | Firebase Authentication crea la credencial **desde el cliente** con `createUserWithEmailAndPassword`: la contraseña viaja directa al servicio de Google y nunca pasa por nuestras Cloud Functions, así que no hay dónde interceptarla. La política del lado del servidor la ofrece Identity Platform, que ADR-008 descartó por su modelo de precios |
| **Consecuencia** | Quien invoque la API de Firebase directamente, saltándose la aplicación, puede registrarse con una contraseña débil. **Contradice el espíritu de RN-01**, que exige que la autorización no dependa de la buena fe del cliente. El alcance del daño es acotado: sigue necesitando estar en la lista blanca, y la contraseña débil solo compromete su propia cuenta |
| **Mitigación actual** | La política se comprueba en la aplicación y está duplicada palabra por palabra en el dominio de TypeScript, con una prueba de paridad que compara los mismos casos en ambas implementaciones. El día que exista un camino de servidor, la regla ya está escrita y probada ahí |
| **Plan de pago** | Dos opciones. **(a)** Habilitar la política de contraseñas de Identity Platform, que sí se aplica del lado del servicio; revisar antes su impacto en el costo. **(b)** Mover el registro a una Cloud Function que valide y cree la credencial con el SDK de administración, lo que exige extremar el cuidado para no registrar jamás la contraseña en un log. Esfuerzo estimado: 1 día cualquiera de las dos |
| **Disparador para pagarla** | Antes de abrir el registro a toda la institución, o al primer indicio de cuentas con contraseñas débiles |

---

## Resumen

| ID | Deuda | Origen | Severidad | Estado | Costo de pagarla |
|----|-------|--------|:---:|--------|:---:|
| DT-01 | Sin aplicación nativa ni tiendas | Alcance / Costo | Alta | Abierta | 0 USD (Android) |
| DT-02 | Sin sonido ni vibración en iOS | Plataforma | Alta | Abierta | 99 USD/año |
| DT-03 | Inestabilidad de push en iOS | Plataforma | Alta | Abierta | 0 USD |
| DT-04 | Acceso a adjuntos sin verificar destinatario | Plataforma | Media | Abierta | 0 USD |
| DT-05 | Precisión del planificador de 60 s | Costo | Baja | Aceptada | — |
| DT-06 | Dominio duplicado Dart / TypeScript | Conocimiento | Media | Mitigada | 0 USD |
| DT-07 | Sin observabilidad ni alertas | Alcance | Media | **Pagada a medias** | 0 USD |
| DT-08 | Grupos limitados a 200 miembros | Alcance | Baja | Aceptada | 0 USD |
| DT-09 | Sin multi-idioma | Alcance | Baja | Mitigada | 0 USD |
| DT-10 | Sin cifrado de extremo a extremo | Alcance | Baja | Aceptada | — |
| DT-11 | SDK de Firebase anclado por el requisito de JDK | Plataforma | **Media** | Abierta | 0 USD |
| DT-12 | Vulnerabilidades moderadas de `firebase-admin` | Plataforma | Baja | Abierta | 0 USD |
| DT-13 | Política de contraseñas solo en el cliente | Plataforma | Media | Abierta | 0 USD |
| DT-14 | Los correos salen del dominio de Firebase y caen en No deseado | Plataforma | **Media** | Abierta | 0 USD |
| DT-15 | Reparación temporal de la fuente de iconos en `index.html` | Plataforma | Baja | Abierta | 0 USD |
| DT-16 | `Entorno.configuracionCompleta` promete un diagnóstico que nadie pinta | Conocimiento | Baja | Abierta | 0 USD |
| DT-17 | El service worker no tiene ninguna prueba automatizada | Alcance | **Media** | Abierta | 0 USD |
| DT-18 | Se acumula un token de FCM por cada ingreso en iOS | Plataforma | **Alta** | **Pagada** | 0 USD |
| DT-19 | Entrar con Google falla en la PWA de iOS por aislamiento de almacenamiento | Plataforma | Alta | **Pagada** | 0 USD |
| DT-20 | Instalada como aplicación, nada dice en qué ambiente se está | Conocimiento | **Media** | Abierta | 0 USD |
| DT-21 | El tema oscuro está construido pero apagado, y no se puede elegir | Alcance | Baja | Abierta | 0 USD |
| DT-22 | Un token muerto solo se descubre cuando falla un aviso real | Alcance | **Media** | Abierta | 0 USD |
| DT-23 | El service worker no atiende `pushsubscriptionchange` | Plataforma | **Media** | Abierta | 0 USD |
| DT-24 | Un envío con algún fallo deja la pantalla igual y se manda dos veces | Conocimiento | **Alta** | **Pagada** | 0 USD |
| DT-25 | El entorno local compila con un Flutter distinto del que despliega | Conocimiento | **Media** | Abierta | 0 USD |

**Prioridad de pago recomendada, en orden:** DT-03 → DT-14 → DT-04 → DT-01.

DT-07 sale de la lista: las alertas ya están puestas y lo que queda —el indicador de tasa
de entrega— es comodidad, no ceguera.

Las tres primeras cuestan cero y eliminan los riesgos operativos más serios. DT-02 es la
única deuda que exige presupuesto real, y solo se paga si la institución decide que las
alertas de emergencia deben sonar distinto en iPhone sin excepción.

---

### DT-14 · Los correos de la cuenta salen del dominio de Firebase y caen en No deseado

| | |
|---|---|
| **Origen** | Plataforma |
| **Severidad** | Media |
| **Estado** | Abierta |
| **Decisión** | Los correos de restablecimiento de contraseña se envían con el remitente que Firebase da por omisión, `noreply@sian-umg-bdm-dev.firebaseapp.com`, sin servidor de correo propio |
| **Motivo** | Usar un remitente `@umg.edu.gt` exige un servidor SMTP y control del DNS del dominio institucional para publicar SPF y DKIM. Ninguna de las dos cosas está al alcance de un proyecto de cátedra, y ADR-008 ya descartó pagar servicios adicionales |
| **Consecuencia** | **Comprobado en pruebas reales:** los correos llegan a *No deseado* en `miumg.edu.gt`, que es Google Workspace. El catedrático que olvide su contraseña concluye que la recuperación «no funciona» —exactamente lo que ocurrió en las pruebas de la ronda 3— y llama a coordinación. Agravado porque la pantalla responde lo mismo exista o no la cuenta (RF-AUT-05), así que no hay forma de distinguir «no llegó» de «no existe» |
| **Mitigación actual** | Tres cosas, ninguna suficiente por sí sola: **(a)** los correos salen en español, fijando el idioma al arrancar, porque un correo en inglés parece más una suplantación; **(b)** el nombre público del proyecto sustituye a `project-863854823370`, que era lo que más lo delataba; **(c)** el guion de pruebas avisa de mirar en No deseado antes de dar por rota la recuperación |
| **Plan de pago** | Configurar SMTP propio en Firebase Authentication → Plantillas → Configuración de SMTP, con un buzón institucional y los registros SPF y DKIM del dominio publicados. Depende de que Sistemas de la UMG ceda un buzón y una entrada de DNS, no de programación. Esfuerzo: 2 horas de configuración, más el tiempo institucional de conseguir el acceso |
| **Disparador para pagarla** | Antes de abrir el sistema a catedráticos reales. Mientras solo se prueba con cuentas propias es un incordio; con cien catedráticos es una avalancha de llamadas a coordinación |

---

## Procedimiento de actualización

1. Toda decisión que introduzca deuda se registra **en el mismo pull request** que la
   introduce.
2. Cada entrada nueva recibe el siguiente ID correlativo y no se reutilizan IDs.
3. Al pagar una deuda, no se borra la entrada: se cambia su estado a **Pagada** y se anota la
   fecha y el commit que la resolvió. El historial es parte del valor didáctico del proyecto.
4. Este documento se revisa al cierre de cada fase del plan de iteraciones.

---

## DT-15 — Reparación temporal de la fuente de iconos

**Estado:** abierta, con fecha de retirada · **Impacto:** bajo

`app/web/index.html` pide la fuente de iconos saltándose la caché antes de
arrancar Flutter, una sola vez por dispositivo.

Existe porque `assets/**` llegó a servirse con una semana de caché. Flutter
recorta esa fuente en cada compilación para dejar solo los iconos que la
aplicación usa, y la publica siempre con el mismo nombre: el contenido cambia,
el nombre no. Al añadir un icono nuevo, quien tuviera guardada la copia anterior
seguía usándola, y el icono **no se dibujaba** — con el botón funcionando y su
ayuda emergente visible. Sin error, sin hueco, sin nada roto.

La cabecera ya está corregida, pero cambiarla no rescata las copias guardadas:
mientras no caduquen, el navegador ni siquiera pregunta. Pedir el archivo
saltándose la caché es lo único que las repara desde el propio sitio.

**Cuándo se retira:** pasada una semana desde el 11 de agosto de 2026 no queda
ninguna copia con la caché antigua, y el bloque sobra.

**La regla que deja:** una ruta sin huella de contenido no se puede cachear
largo. Flutter Web no la pone ni en `main.dart.js` ni en `assets/`; para el
primero ya estaba contemplado, para el segundo no.

## DT-16 — `Entorno.configuracionCompleta` no se usa en ninguna parte

**Qué pasa.** `app/lib/core/entorno.dart` expone `configuracionCompleta`, documentado
así: «sirve para dar un diagnóstico honesto en pantalla en lugar de fallar con un error
críptico de Firebase a mitad del arranque». Ninguna pantalla lo consulta. La búsqueda en
`app/lib` y `app/test` devuelve una sola línea: su propia definición.

**Por qué importa.** El daño no es el código muerto, que ocupa una línea. Es que
cualquiera que lea el archivo concluye que la aplicación avisa cuando le falta
configuración, y decide sin preocuparse. No avisa. Al aprovisionar el ambiente de calidad
el 24 de agosto de 2026 se compiló sin clave VAPID y la aplicación arrancó normal, sin
una palabra: se entra, se leen y se envían mensajes, y las notificaciones simplemente
nunca llegan. Eso se persigue en el lugar equivocado durante bastante rato.

**Cómo se paga.** Dos caminos, y el barato sirve. O se pinta el diagnóstico que el
comentario promete —una tarjeta al arrancar cuando `configuracionCompleta` es falso—, o
se borra la propiedad y con ella la promesa. Lo que no puede quedarse es la promesa sin
la conducta.

**Mientras tanto.** El documento 11, sección 4, lista las cosas que hay que hacer a
mano por ambiente y que ningún despliegue verifica. La clave VAPID es la primera.

## DT-17 — El service worker no tiene ninguna prueba automatizada

**Qué pasa.** `app/web/firebase-messaging-sw.js` son 300 líneas de JavaScript sin una sola
prueba. No hay dónde ponerlas: es un archivo que carga el navegador, fuera del paquete de
Flutter y fuera del de Functions, y ninguno de los dos arneses lo alcanza. Se comprueba
mirando un teléfono.

**Por qué importa.** Es la pieza que decide qué se ve cuando llega un aviso con la
aplicación cerrada — o sea, **la razón de ser del sistema**. Y la evidencia de que ahí se
esconden defectos ya no es teórica: las notificaciones en iOS se rompieron **seis veces**, y las seis las encontró una
persona mirando su pantalla, nunca una prueba.

| Cuándo | Qué pasaba | Por qué ninguna prueba podía verlo |
|---|---|---|
| 25 ago 2026 | El número no aparecía nunca en iPhone | El worker llamaba a `clearAppBadge()` porque `getNotifications()` devuelve vacío en iOS. Es una suposición sobre el navegador, no una regla del dominio |
| 25 ago 2026 | Decía «3» donde había 1 mensaje | Contaba `push` recibidos, y la entrega se reintenta hasta tres veces |
| 26 ago 2026 | Decía «2» donde había 1 mensaje | Contaba la notificación de prueba del registro, que no es un mensaje |
| 27 ago 2026 | El número solo subía, nunca bajaba | El aviso de la aplicación se iba al service worker de Flutter, no al de mensajería |
| 28 ago 2026 | Con la aplicación cerrada no notificaba nada | El manejador de `push` se salía justo en ese caso y delegaba en el SDK |
| 28 ago 2026 | Notificaba dos veces | Dos sitios mostraban, confiando en que el `tag` los fundiría. En iOS no funde |
| 28 ago 2026 | El arreglo funcionaba en desarrollo y no en producción | Nadie pedía comprobar si había un worker nuevo. La aplicación se renovaba, el worker no |

Los seis defectos vivían **enteros** dentro del worker. Las 307 pruebas de Flutter y las
261 de Functions estaban en verde durante los tres.

**El agravante.** El lado de Dart sí tiene pruebas —`insignia_bandeja_test.dart` ata la
insignia al conteo del filtro «Sin leer»—, y eso da una falsa sensación de cobertura: lo
probado es la mitad que casi nunca falla.

**Un agravante que se descubrió tarde.** Servir el archivo con `no-store` evita que el
navegador se quede con una copia vieja **cuando va a buscarla**, pero no lo obliga a ir. Una
PWA de iOS que se reabre puede seguir ejecutando el worker de hace días, y como la
aplicación **sí** se renueva en cada arranque, se llega a tener el código nuevo con el
worker viejo por debajo. Los arreglos parecen no haber llegado, y desinstalar los hace
aparecer — lo que confunde aún más, porque parece un problema del aparato.

Se vio el 28 de agosto de 2026: la misma versión desplegada notificaba en desarrollo,
recién reinstalado, y no en producción. Ahora la aplicación pide `update()` sobre todos los
registros en cada arranque, así que **cerrar y volver a abrir basta para que un arreglo
llegue**. Esto no cierra DT-17: sigue sin haber pruebas del worker. Solo hace que lo que se
arregle llegue de verdad.

**Cómo se paga.** Extraer del worker las decisiones que son lógica pura —qué cuenta para la
insignia, cómo se compone una notificación, cuándo se muestra en primer plano— a un módulo
que un runner de Node pueda importar, y dejar en el archivo del worker solo el pegamento
con las APIs del navegador. Esfuerzo estimado: 1 día, más un runner de Node para `app/web`,
que hoy no existe.

**Mientras tanto.** El guion de pruebas tiene las comprobaciones manuales, y hay que
hacerlas **en un teléfono con la aplicación instalada**: en el escritorio, dos de los tres
defectos de arriba no se reproducen.

## DT-18 — Se acumula un token de FCM por cada ingreso en iOS

**Qué pasa.** El documento del dispositivo se guarda con el token como identificador, y el
comentario del código dice: «reabrir la aplicación cien veces no crea cien dispositivos,
refresca el mismo». Eso es cierto donde el token es estable. **En iOS no lo es**: Safari lo
rota, así que cada ingreso escribe un documento nuevo y el anterior se queda.

Medido en producción el 27 de agosto de 2026: **cuatro tokens del mismo iPhone**, de una
sola persona, en un par de horas.

**Consecuencia.** Cada mensaje se envía tantas veces como tokens tenga esa persona. Con
cuatro, un aviso a un catedrático son cuatro `push`. Se paga en cuota, y despierta el
service worker cuatro veces casi al mismo instante, que es lo que destapó la falta de
atomicidad en el contador de la insignia. La cifra crece con el uso: no se estabiliza sola.

**Mitigación actual.** El worker deduplica por identificador de mensaje —ahora de forma
atómica—, así que el número del icono es correcto aunque lleguen cuatro. Y la limpieza de
tokens rechazados por el servicio de push retira los muertos, pero solo cuando el servicio
los rechaza, que puede tardar.

**Cómo se paga.** Guardar el documento con el **identificador de instalación** de Firebase
—que sí es estable por aparato— en lugar del token, y dejar el token como un campo dentro.
Un ingreso con token nuevo actualizaría el mismo documento en vez de crear otro. Esfuerzo
estimado: medio día, más una migración que borre los duplicados existentes.

**Disparador para pagarla.** Al abrir a toda la institución. Con veinte personas y varios
ingresos cada una, el número de envíos por mensaje se multiplica sin que nadie lo note.

---

**Subida a severidad alta y pagada el 28 de agosto de 2026.** Dejó de ser desperdicio para
convertirse en **fallos de entrega reales**. En los tres primeros avisos a la planta, cuatro
personas constaron como no localizadas; dos de ellas —con la aplicación instalada y el
permiso concedido— porque **todos** sus tokens estaban muertos. Una acumulaba nueve, otra
catorce.

El arreglo tiene tres partes, y hacían falta las tres:

| | Qué resuelve |
|---|---|
| El documento se identifica por **instalación**, no por token | Deja de crearse un dispositivo por cada apertura |
| El envío **retira** los tokens que el servicio de push rechaza | Limpia lo ya acumulado, sin migración |
| El registro borra el documento viejo con ese mismo token | Evita que convivan los dos esquemas y llegue duplicado |

> **La limpieza estaba escrita como comentario y no existía como código.** Encima del
> lugar donde debía ir se leía «se limpia cualquier registro anterior de este mismo usuario
> que el servicio de push ya haya rechazado (RF-USR-10)», y debajo no había nada. Es el
> tercer caso en este proyecto de un comentario que describe una intención que nadie
> implementó — como el `merge` que iba a proteger `consumida` (documento 05, 2.10) y el
> diagnóstico de `Entorno.configuracionCompleta` (DT-16). Vale la pena desconfiar de un
> comentario que afirma un comportamiento y no señala el código que lo hace.

**El identificador de instalación** lo genera la aplicación y lo guarda en `localStorage`:
sobrevive a cerrar sesión, a cerrar la aplicación y a reiniciar el teléfono. Solo se pierde
si se borran los datos del sitio o se desinstala, y ahí empezar de cero es lo correcto.

**Los clientes que no lo mandan siguen funcionando**: el servidor cae al token, como antes.
Así la actualización no rompe a quien va un despliegue atrás. Basta con que cierre y vuelva
a abrir la aplicación; **no hace falta reinstalar**.

**Lo acumulado se limpia solo.** No hay migración: en el próximo envío, cada token muerto
que el servicio rechace se retira. Las nueve y catorce entradas se van solas.

> **Este arreglo se rompió a sí mismo, y hay que contarlo.** Se cambió el lado que
> **escribe** el dispositivo —el identificador pasó a ser la instalación— y se olvidó el
> que **lee**: `tokensDe` seguía devolviendo el identificador del documento como si fuera
> el token. Así que a partir de ese despliegue el envío mandaba a `ins_vg7tmesv…` como si
> fuera un token de FCM.
>
> El daño fue mayor que el problema original, por dos motivos que se sumaron. Firebase
> rechazaba ese identificador como token inválido, **y la limpieza de tokens muertos
> borraba el documento del dispositivo**. Reinstalar no servía de nada: al primer envío
> volvía a desaparecer. Y empeoraba solo, porque cada persona que reabría la aplicación
> migraba al esquema nuevo y dejaba de recibir.
>
> Dos lecciones, y la segunda vale más que la primera:
>
>   · **Cambiar el identificador de una colección obliga a revisar todo lo que la lee.**
>     No basta con que compile: `d.id` seguía siendo una cadena válida.
>   · **Una limpieza que puede borrar lo bueno tiene que decir qué está autorizada a
>     tocar.** Ahora solo borra por identificador si lo recibido tiene forma de token y no
>     de instalación, así que un error aguas arriba ya no se convierte en pérdida de datos.

**Lo que queda, y por qué DT-18 no está cerrada del todo.** La causa está resuelta: ya no
se crea un dispositivo por cada ingreso, y se comprueba mirando los datos —la mayoría de
las personas tiene un solo documento del esquema nuevo por más veces que hayan entrado.

Lo que no se resolvió es **el arrastre**: quedan 71 documentos del esquema viejo, de antes
del arreglo. Se retiran cuando el servicio de push declara muerto su token, y Apple no los
mata al dejar de usarse: pueden seguir vivos semanas. Se dijo que bajarían en dos o tres
envíos y fue optimista.

No rompen nada —al enviar basta con que uno llegue— pero se paga en cuota y ensucian el
diagnóstico cuando hay que averiguar por qué alguien no recibió. Las dos vías para pagarlo
están en el documento 08, entre los pendientes de la próxima iteración; la recomendada es
retirar por antigüedad, no un borrado a mano.

> **Reinstalar sigue creando un documento nuevo**, porque borra `localStorage` y con él el
> identificador de instalación. Es correcto —el navegador olvidó todo, empezar de cero es
> lo apropiado— y para quien instala una vez no se nota. Solo se acumula en un aparato que
> se usa para probar.

---

## DT-19 — Entrar con Google falla en la PWA de iOS

**Qué pasa.** En un iPhone con la aplicación instalada, entrar con Google falla con
«Unable to process request due to missing initial state».

La aplicación pide `signInWithPopup`, pero una PWA en iOS no puede abrir ventanas
emergentes, así que el SDK cae a redirección. El manejador de autenticación vive en
`sian-umg-bdm.firebaseapp.com` y la aplicación en `sian-umg-bdm.web.app`: **dos orígenes
distintos**. iOS aísla el almacenamiento entre ellos, el estado que se escribe antes de
salir no se encuentra al volver, y el ingreso se rompe.

Es intermitente, que es lo peor: falla, se reintenta, se queda pensando, y a la tercera
entra. Quien lo sufre no sabe si hizo algo mal.

**Consecuencia.** Es el camino de ingreso que el manual recomienda primero y el que la
institución quiere por omisión. Entrar con correo y contraseña sigue funcionando, así que
nadie queda fuera, pero la primera impresión de un catedrático con su iPhone es que el
sistema no anda.

**Cómo se paga.** Servir el manejador desde el mismo origen que la aplicación:
`authDomain` pasa de `sian-umg-bdm.firebaseapp.com` a `sian-umg-bdm.web.app`. Comprobado
que `https://sian-umg-bdm.web.app/__/auth/handler` ya responde.

**Falta un paso que no tiene API.** Google rechaza hoy esa URL de retorno con
`redirect_uri_mismatch`, porque el cliente OAuth solo tiene registrada la de
`firebaseapp.com`. Hay que agregarla a mano en Google Cloud Console → APIs y servicios →
Credenciales → el cliente «Web client (auto created by Google Service)» → URIs de
redireccionamiento autorizados:

    https://sian-umg-bdm.web.app/__/auth/handler

Es **aditivo**: no rompe la que ya existe, de modo que se puede agregar sin prisa y cambiar
el `authDomain` después.

> **Este cambio ya salió mal una vez.** Cambiar el `authDomain` en desarrollo dejó el
> ingreso con Google roto con `Error 400: redirect_uri_mismatch`. Por eso se hace en ese
> orden —primero registrar la URL, después cambiar el dominio— y se prueba en desarrollo
> antes de tocar producción.

**Pagada el 27 de agosto de 2026.** Se siguió ese orden: se registró la URL de retorno, se
cambió el `authDomain` en desarrollo y se comprobó en un iPhone real entrando, saliendo y
volviendo a entrar tres veces seguidas, que era el escenario que fallaba. Después se llevó
a los demás ambientes.

**Cada ambiente necesita lo suyo**, porque el cliente OAuth es uno por proyecto: hay que
registrar `https://<proyecto>.web.app/__/auth/handler` en cada uno antes de cambiarle el
`authDomain`. Está en el documento 11, sección 4, entre las cosas que se hacen una vez por
ambiente.


---

## DT-20 — Instalada como aplicación, nada dice en qué ambiente se está

**Origen:** conocimiento · **Severidad:** media · **Estado:** abierta · **Costo:** 0 USD

En el navegador el ambiente se lee en la barra de direcciones: `sian-umg-bdm-dev`,
`-qa` o `-prd` están en el propio dominio. **Instalada como aplicación esa barra
desaparece**, y las tres se ven exactamente iguales: mismo escudo, mismo azul, misma
pantalla de ingreso.

### Por qué importa más de lo que parece

La consecuencia no es incomodidad, es un envío equivocado. Quien administra tiene las
tres instaladas para poder probar, y desde dentro no hay nada que distinga la de
producción —donde hay 26 catedráticos reales— de la de pruebas. Basta abrir la que no era
y redactar un aviso.

El riesgo es asimétrico: mandar un mensaje de prueba a QA no le pasa nada a nadie; mandar
uno de prueba a producción lo reciben veintiséis personas en el teléfono.

### Cómo se pagaría

El dato ya está disponible en tiempo de ejecución: `Firebase.app().options.projectId`
devuelve `sian-umg-bdm-dev`, `sian-umg-bdm-qa` o `sian-umg-bdm`. No hace falta un
`--dart-define` nuevo ni tocar el flujo de compilación.

> **Ojo con el nombre de producción.** Los tres no siguen el mismo patrón: producción es
> `sian-umg-bdm`, **sin sufijo**, porque se creó antes que los otros dos. Comparar por
> «termina en `-prd`» no encuentra nada y deja producción sin identificar, que es
> justamente el ambiente donde equivocarse cuesta. Conviene una tabla explícita de los tres
> identificadores, o preguntar por `-dev` y `-qa` y tratar todo lo demás como producción.

Lo que falta es decidirlo bien, y conviene pensarlo al revés de como suele hacerse:

> **Producción no debería llevar distintivo.** Es el estado normal y el que van a ver los
> catedráticos; llenarles la pantalla de etiquetas técnicas no les aporta nada. Los que
> deben gritar son desarrollo y QA.

Una franja de color con el nombre del ambiente, visible en todas las pantallas y no solo
al ingresar —porque el error se comete al redactar, no al entrar—, y ausente en
producción. Verificar el contraste contra RNF-13 y comprobar que no tape nada en pantalla
de teléfono.

---

## DT-21 — El tema oscuro está construido pero apagado, y no se puede elegir

**Origen:** alcance · **Severidad:** baja · **Estado:** abierta · **Costo:** 0 USD

`TemaSian.oscuro()` existe, está completo y está conectado como `darkTheme`. Lo que lo
mantiene apagado es una sola línea en `app/lib/main.dart`:

```dart
themeMode: ThemeMode.light,
```

### Por qué se dejó así, y por qué no basta con quitar esa línea

La razón está escrita junto a la línea y sigue siendo válida:

  · El escudo institucional tiene fondo blanco y un anillo rojo que sobre superficies
    oscuras pierde definición.
  · El azul `#1C72A5` se aclara tanto en modo oscuro que deja de ser el color de la
    universidad.

Servir un tema oscuro sin comprobar el contraste sería incumplir RNF-13 (WCAG 2.1 AA) sin
que nadie se dé cuenta, porque las pruebas actuales no lo miran.

Así que **es más trabajo del que aparenta**: no es activar una bandera, es verificar una
paleta.

### Cómo se pagaría

1. Revisar la paleta oscura contra WCAG 2.1 AA, par por par, y ajustar el azul
   institucional a una variante que mantenga el contraste sin dejar de ser reconocible.
2. Resolver el escudo sobre fondo oscuro — probablemente una variante con borde, que ya se
   genera desde `scripts/generar-iconos.py`.
3. Recién entonces, cambiar la línea a `ThemeMode.system` para que siga al sistema
   operativo.
4. Agregar la preferencia del usuario —claro, oscuro o el del sistema— guardada localmente,
   con «el del sistema» como opción por omisión.

El orden importa: los pasos 3 y 4 sin los pasos 1 y 2 producen una aplicación que se ve
mal y que además incumple un requisito no funcional.


---

## DT-22 — Un token muerto solo se descubre cuando falla un aviso real

**Origen:** alcance · **Severidad:** media · **Estado:** abierta · **Costo:** 0 USD

Nada degrada el canal por dejar de enviar: un token de FCM no caduca porque nadie mande
mensajes. Lo que lo degrada es lo que ocurre **en el aparato** —el navegador rota la
suscripción, retira el permiso de un sitio sin uso, o borra los datos del sitio— y eso pasa
sin que el servidor se entere.

La aplicación mitiga la mayor parte: refresca el identificador **en cada apertura**, en
silencio, cuando el permiso ya está concedido. Quien abra la aplicación de vez en cuando no
pierde el canal nunca.

Queda el caso de quien **no la abre durante semanas**. Su token puede morir, el servidor
sigue creyéndolo bueno, y **la única cosa que lo descubre es un aviso real que falla**.

### Por qué importa

Ocurrió el 29 de agosto de 2026. Una persona arrastraba un token muerto; el primer mensaje
del coordinador lo descubrió, la limpieza lo retiró, y el segundo mensaje —diecinueve
segundos después— salió ya sin dispositivo. Se recuperó sola al volver a entrar.

El sistema se cura, pero **el precio es el mensaje que hizo el descubrimiento**. En una
prueba no cuesta nada. En una emergencia, esa persona no se entera.

### La propuesta: una sonda, no un mensaje

La primera idea fue mandar un aviso de canal cada cierto tiempo. **No sirve, y conviene
dejar escrito por qué**, porque es la solución que parece obvia:

> **En web no existe la notificación invisible.** El navegador exige que todo push termine
> en algo visible —Chrome obliga a `userVisibleOnly`—, y si el service worker no muestra
> nada, lo muestra el navegador con un texto genérico. Repetirlo puede costar la
> suscripción. Un aviso silencioso periódico terminaría matando justo aquello que pretende
> conservar.

Lo que sí es invisible es el **envío en seco** de FCM, que ya está en el SDK que usa el
proyecto:

```ts
getMessaging().sendEach(mensajes, /* dryRun */ true);
```

En este modo FCM **valida el token y no entrega nada**. No hay notificación, ni sonido, ni
insignia: el teléfono no se entera. Y devuelve los mismos códigos que ya sabemos leer, así
que `esTokenMuerto()` y `retirarTokensMuertos()` sirven sin tocarlos.

Una función programada que recorra los dispositivos registrados, los valide en seco y
retire los que FCM rechace. Es completamente invisible **para el catedrático**; el
resultado se le muestra al coordinador, que es quien puede hacer algo con él.

> **Lo que la sonda hace y lo que no.** Detecta, no revive. Un token muerto no se arregla
> validándolo: hace falta que la persona abra la aplicación. Por eso la mitad visible del
> trabajo es avisarle al coordinador quién se quedó sin dispositivo, para que pueda
> buscarle antes de necesitarlo.

### Dónde se ve el resultado

La sonda sin destinatario no sirve de nada: alguien tiene que enterarse. Dos sitios, y son
distintos a propósito.

**1 · Un apartado en la pantalla del coordinador — «Dispositivos que necesitan atención».**

Una lista permanente de a quién hay que buscar, con lo que hace falta para decidir:

| Columna | Para qué |
|---|---|
| Persona y rol | A quién buscar |
| Estado | Sin dispositivo · solo en pestaña · sin actividad reciente · permiso denegado |
| Desde cuándo | Distingue «se le murió ayer» de «lleva un mes» |
| Plataforma y si está instalada | Cambia por completo lo que hay que pedirle |

Debe ordenar por gravedad, no alfabéticamente: primero quien no puede recibir nada.

**2 · Un aviso al emisor, al redactar y antes de enviar.**

El apartado anterior sirve para mantener la casa en orden; este sirve en el momento que
importa. Al elegir destinatarios, decir cuántos de ellos **no van a enterarse**, y
repetirlo en la confirmación de envío:

> De 19 destinatarios, **5 no recibirán aviso en el aparato**: 4 solo tienen la aplicación
> en una pestaña y 1 no tiene dispositivo registrado. Verán el mensaje al abrir.

Sin bloquear el envío. El emisor decide; lo que no puede es enterarse después.

> **Conviene calcularlo al redactar y también al confirmar.** Entre una cosa y otra puede
> pasar un rato, y en un mensaje programado pasan días: la cifra que se vio al escribir
> puede no ser la del momento del envío.

### Cada cuánto

El tiempo de vida no lo fija FCM, lo fija cada navegador, y no es uno solo:

| Qué lo mata | Plazo aproximado |
|---|---|
| Safari borra los datos de un sitio **sin instalar** que no se toca | alrededor de una semana |
| Chrome retira el permiso de sitios sin uso | meses |
| iOS rota el token de una aplicación instalada | sin plazo fijo, puede ser cualquier apertura |
| FCM da por obsoleto un token que nunca se usa | del orden de nueve meses |

El plazo que manda es el más corto que aplique a la población real, y aquí la población es
mayoritariamente iPhone con la aplicación instalada, donde el plazo **no está documentado**.

Así que la recurrencia no debería fijarse de memoria. **Semanal para empezar** —se alinea
con el plazo más corto conocido y ningún hueco supera una semana— y que la propia sonda
anote la antigüedad de cada token al morir. Con dos o tres meses de esos datos, la
recurrencia se ajusta con hechos de esta población en vez de con cifras generales.

### Costo

Ninguno relevante. El envío en seco no cuesta, hoy hay 36 dispositivos, y Cloud Scheduler
regala tres trabajos por cuenta de facturación: el proyecto usa uno —el despachador, cada
minuto—, así que el segundo sigue dentro de lo gratuito.


---

## DT-23 — El service worker no atiende `pushsubscriptionchange`

**Origen:** plataforma · **Severidad:** media · **Estado:** abierta · **Costo:** 0 USD

**Se trabaja antes que DT-22.** La sonda de DT-22 informa de un problema; esto lo reduce.
Hacerlo al revés es construir un panel para vigilar algo que se podía haber evitado.

### Lo primero, que no tiene vuelta de hoja

**Desde el servidor no se puede revivir un token muerto.** No es una carencia del proyecto:
es cómo está hecho Web Push. La suscripción vive en el navegador; el servidor guarda una
cadena opaca que solo sirve para pedirle a FCM que entregue. Cuando el navegador la rota o
la descarta, **solo el navegador puede crear otra**, y solo mientras algo suyo esté
corriendo. No hay API, ni truco, ni permiso que lo cambie.

Así que la pregunta útil no es cómo revivirlo, sino **quién crea el reemplazo y si hace
falta molestar a alguien para conseguirlo**.

### El mecanismo que el estándar sí ofrece

El estándar de Push define el evento **`pushsubscriptionchange`**: cuando el navegador
invalida o rota una suscripción, despierta al service worker y se lo dice. El service
worker puede suscribirse de nuevo y mandar el identificador nuevo al servidor **sin que la
persona haga nada y sin que se entere**.

Hoy el service worker de SIAN no lo escucha. Atiende `install`, `activate`, `message`,
`push` y `notificationclick`; `pushsubscriptionchange` no aparece en ninguna parte del
proyecto.

Es exactamente el caso que hoy obliga a que alguien abra la aplicación.

### Lo que hay que verificar en desarrollo, y es el punto entero

**En Chrome y Android está soportado desde hace años.** El caso dudoso es iOS, que es justo
donde está la mayoría de los catedráticos:

  · WebKit implementa el estándar de Push desde iOS 16.4, así que el evento debería existir.
  · Lo que **no está documentado** es si iOS despierta al service worker de una aplicación
    instalada para entregárselo mientras la aplicación está cerrada. Y una suscripción suele
    morir precisamente estando cerrada.

Eso no se resuelve leyendo: se resuelve probándolo en desarrollo con un iPhone real, que es
como se encontraron los siete defectos de notificación.

### Lo que se descartó

**Periodic Background Sync** resolvería el caso de raíz —el navegador despierta a la
aplicación cada cierto tiempo y ella refresca su identificador—, pero **no existe en Safari
ni en iOS**. Serviría para Android y dejaría fuera a la mayoría, así que no puede ser la
solución; a lo sumo una mejora añadida más adelante.

### Hasta dónde llega, y por qué DT-22 sigue haciendo falta

Con `pushsubscriptionchange` funcionando, la dependencia de que alguien abra la aplicación
**se reduce mucho**, pero no desaparece. Queda fuera lo que ningún mecanismo web alcanza:

  · Quien desinstala la aplicación.
  · Quien retira el permiso de notificaciones.
  · Quien tiene el aparato apagado o sin red durante mucho tiempo.
  · iOS, si resulta que no despierta al service worker con la aplicación cerrada.

Una aplicación nativa escaparía de esto con el push silencioso, que iOS concede a las
nativas y no a la web. Ya está registrado como **DT-01** y **DT-02**, y cuesta 99 USD/año.

El techo realista es **quitar casi toda la dependencia de una persona, no toda**. Por eso
DT-22 sigue haciendo falta: como red, no como mecanismo principal.

### Así lo resuelven otras aplicaciones instalables

No hay magia; es la misma escalera de cuatro peldaños, y SIAN tiene dos:

| Peldaño | En SIAN |
|---|---|
| Refrescar el identificador en cada apertura | **ya está** |
| Atender `pushsubscriptionchange` en el service worker | **falta — es DT-23** |
| Retirar del servidor lo que el servicio de push declare muerto | **ya está** |
| Mostrar a quien opera quién quedó incomunicado | **falta — es DT-22** |

Quien nunca abre la aplicación termina siendo inalcanzable en todas ellas. Es una propiedad
de la plataforma, no de este proyecto.


---

## DT-24 — Un envío con algún fallo deja la pantalla igual y el aviso se manda dos veces

**Origen:** conocimiento · **Severidad:** alta · **Estado:** abierta · **Costo:** 0 USD

**Está pasando en producción.** El 29 de agosto de 2026 el coordinador mandó dos avisos y
salieron cuatro:

```
  06:58:26  «lista de aaistencia»           ENVIADO_CON_FALLOS
  06:58:46  «lista de aaistencia»           ENVIADO_CON_FALLOS   ← 20 segundos después
  14:21:29  «sobres para Entrega de exá…»   ENVIADO_CON_FALLOS
  14:24:22  «sobres para Entrega de exá…»   ENVIADO_CON_FALLOS   ← 2 min 53 s después
```

Mismo título, mismo cuerpo, mismos destinatarios. Veinte catedráticos recibieron dos veces
el mismo aviso urgente.

### La causa, y es una línea

En `app/lib/presentation/admin/seccion_mensajes.dart`:

```dart
if (!r.huboFallos) {
  _limpiar();
}
```

**El formulario se vacía solo cuando el envío sale perfecto.** Basta que un destinatario
falle —alguien en pestaña, un token muerto— para que el título y el cuerpo sigan escritos
en pantalla exactamente como estaban antes de pulsar enviar.

A eso se suma que el único acuse es un aviso flotante **de color rojo** durante seis
segundos, porque se pinta con `error: r.huboFallos`. Y rojo, en esta aplicación, es el
color de lo urgente y de lo que salió mal.

Puesto junto, lo que ve quien envía es: un aviso rojo que se va solo, y el formulario
intacto con su texto. La lectura natural es «no se envió». Vuelve a pulsar.

### Por qué es alta y no media

**Los datos lo confirman sin ambigüedad.** De los mensajes enviados en producción, se
duplicaron **todos** los que terminaron en `ENVIADO_CON_FALLOS` y **ninguno** de los que
terminaron en `ENVIADO`. Tres incidentes distintos, dos personas distintas, uno de ellos
por triplicado.

Y el fallo parcial no es raro: mientras haya alguien con la aplicación en una pestaña
—hoy son seis— **casi todo envío a todos termina con fallos**. O sea que la trampa está
armada permanentemente.

### La ironía del identificador

Un mensaje **con adjunto** no puede duplicarse, y uno de solo texto sí.

Con adjunto, el cliente reserva un identificador antes de subir los archivos y el servidor
crea el documento con `create`, que falla si ya existe. Sin adjunto, `mensajeId` viaja nulo
y el servidor genera uno nuevo en cada llamada:

```ts
const refMensaje = datos.mensajeId
  ? db.collection(RUTAS.mensajes).doc(datos.mensajeId)
  : db.collection(RUTAS.mensajes).doc();   // ← identificador nuevo cada vez
```

La protección ya existe y está construida. Solo que el camino más usado no pasa por ella.

### Cómo se paga

Tres cosas, y la primera sola ya elimina el caso:

1. **Vaciar el formulario siempre que el mensaje se haya creado**, con fallos o sin ellos.
   Un fallo parcial no es un envío fallido: el mensaje existe, quedó registrado y la mayoría
   lo recibió. Volver a mandarlo no arregla nada, porque a quien falló le volverá a fallar.
2. **No pintarlo de rojo.** Un envío con fallos parciales no es un error; es información. El
   texto ya lo dice bien —«Enviado a 19 de 20»—, es el color el que miente.
3. **Reservar el identificador siempre**, no solo cuando hay adjuntos, y renovarlo al
   vaciar el formulario. Así, si alguien vuelve a pulsar por lo que sea, el servidor
   rechaza el duplicado con el `create` que ya está escrito.

> **Sobre el punto 3.** Hay que renovar el identificador después de un envío correcto; si no,
> quien quiera mandar el mismo aviso dos veces a propósito no podría. El objetivo es impedir
> el segundo pulsar sobre **el mismo formulario sin tocar**, no impedir repetir un mensaje.

### Cómo quedó pagada

Las tres cosas, el 29 de agosto de 2026.

**1 · El formulario se vacía siempre que el mensaje se haya creado.** Ya no depende de que
el envío salga perfecto.

**2 · Un envío con fallos parciales ya no se pinta de rojo.** Se añadió `TonoAviso` con tres
estados —correcto, atención, error— en vez del booleano de antes, que solo sabía de
celebración y de alarma. El fallo parcial sale en dorado oscurecido, 5.03:1 con blanco
encima, que cumple AA (RNF-13).

**3 · El identificador se reserva siempre**, no solo con adjuntos, y se suelta al vaciar.
Un segundo envío del mismo formulario lo rechaza el servidor con el `create` que ya estaba
escrito, y `traducirError` lo traduce a «Este aviso ya se envió. No se mandó de nuevo.» en
lugar del «fallo interno» de antes, que invitaba a pulsar otra vez.

> **Un efecto secundario que valía la pena.** Reservar siempre el identificador arrastraba
> una dependencia de Firestore al camino sin adjuntos, y las pruebas lo detectaron: el envío
> dejó de completarse. Se resolvió generando el identificador en local —mismo formato de
> veinte caracteres, con `Random.secure()`— porque Firestore también lo genera en local y no
> se pierde nada. De paso, `RepositorioAdjuntos` dejó de depender de Firestore.

**Y la prueba que afirmaba lo contrario.** Existía una llamada «un envío con fallos NO
limpia, para poder reintentar», con el argumento de que el emisor no quiere perder el texto
recién escrito. Suena razonable y es falso: reintentar es exactamente lo que no debe
hacerse. Ahora afirma lo correcto y conserva escrito el porqué del cambio, para que a nadie
le parezca buena idea revertirlo.

### Se relaciona con DT-22

El aviso previo al envío que pide DT-22 —«5 de 19 no recibirán aviso en el aparato»— habría
evitado además la confusión de fondo: quien envía sabría que ese fallo era esperado y no una
avería, antes de pulsar.


---

## DT-25 — El entorno local compila con un Flutter distinto del que despliega

**Origen:** conocimiento · **Severidad:** media · **Estado:** abierta · **Costo:** 0 USD

| | |
|---|---|
| Flutter en la máquina de trabajo | **3.47.0** · Dart 3.13.0 |
| Flutter en la integración continua | **3.44.9** · el que compila todo lo desplegado |
| Flutter documentado | 3.44.8 · Dart 3.12.2 |

**Todo lo que se prueba en local corre sobre un compilador distinto del que produce lo
que reciben los catedráticos.** Las 314 pruebas de Flutter, el analizador y cualquier
despliegue hecho a mano usan 3.47; lo que sirve la nube lo compiló 3.44.9.

### Cómo se descubrió

Por un rastro pequeño. El primer despliegue automático selló `limpio: false`, y al hacer
que el sello dijera **qué** estaba sin confirmar salió `app/pubspec.lock`: la integración
continua lo reescribía porque su pub resolvía versiones distintas de las que resolvió el
pub de la máquina de trabajo.

Es la misma familia que la deriva entre ambientes, un piso más abajo: no diferían los
ambientes, diferían los compiladores.

### Lo que ya se hizo

**Fijar la versión exacta en la integración continua.** Antes decía `3.44.x`, así que cada
ejecución podía traer un parche distinto sin que nadie lo decidiera. Ahora dice `3.44.9`,
que es lo que ya venía usando: **fijarlo no cambió nada de lo desplegado**, solo impide que
cambie mañana.

**Enseñar el cambio del bloqueo.** El despliegue avisa si `flutter pub get` reescribe
`app/pubspec.lock` y muestra el cambio. No falla, informa: sin eso el único rastro era un
`limpio: false` que no decía de qué hablaba.

### Lo que falta, y por qué no se hizo

Alinear la máquina de trabajo con 3.44.9. **No se toca sin decisión de quien la usa**, y
hay dos caminos con consecuencias muy distintas:

  · **Bajar el entorno local a 3.44.9.** Lo que se prueba pasa a ser lo que se despliega.
    Es lo recomendado, y no toca nada de lo que ya funciona.
  · **Subir la nube a 3.47.** Cambiaría el compilador de la aplicación que ya está en
    producción, en una semana en que recién se estabilizó. Si algún día se hace, que sea
    una tarea con su propia ronda de pruebas y no un efecto colateral.

> **Mientras tanto, hay una regla que no cuesta nada:** ningún despliegue a mano. Todo por
> la tubería, que es la que tiene el compilador correcto. Desde que `develop` despliega
> solo, esa regla se cumple sin que nadie tenga que acordarse.
