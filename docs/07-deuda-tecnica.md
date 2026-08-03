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
| **Mitigación actual** | Flutter fue elegido precisamente para poder compilar a nativo sin reescribir. Existe plan de contingencia documentado (documento 02, sección 11) |
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
| **Mitigación actual** | Prefijo visible «URGENTE» en el título. Sonido reproducido desde la aplicación cuando está en primer plano. Insistencia visual sobre mensajes urgentes no confirmados |
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
| **Estado** | Abierta |
| **Decisión** | La versión 1 no incluye monitoreo proactivo de fallos de entrega |
| **Motivo** | Reducir el alcance del prototipo para validar más rápido |
| **Consecuencia** | Si el despachador falla o si las entregas empiezan a fallar masivamente, nadie se entera hasta que alguien lo nota |
| **Mitigación actual** | Los registros de Cloud Functions quedan disponibles en la consola de Google Cloud, aunque hay que ir a buscarlos |
| **Plan de pago** | Alertas de Cloud Monitoring por tasa de error de la función despachadora, más un tablero de tasa de entrega en el panel. Costo: dentro de la capa gratuita. Esfuerzo estimado: 1 a 2 días |
| **Disparador para pagarla** | Antes de producción, o al primer incidente no detectado a tiempo |

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

### DT-11 · Firebase CLI anclada a la versión 13 por el requisito de JDK

| | |
|---|---|
| **Origen** | Plataforma y tiempo |
| **Severidad** | Baja |
| **Estado** | Abierta |
| **Decisión** | `firebase-tools` queda fijada a `^13.35.1` en lugar de la última versión mayor |
| **Motivo** | A partir de la versión 14, `firebase-tools` exige **JDK 21 o superior** para levantar los emuladores. El documento 06, etapa A.1, fija **JDK 17** como requisito del entorno, y esa es la versión instalada en las máquinas de desarrollo actuales. Subir la CLI obligaría a subir el JDK de todo el que replique el proyecto, en mitad de la iteración de cimientos |
| **Consecuencia** | El proyecto no recibe correcciones ni funcionalidad nueva de la línea 14/15 de la CLI. Las versiones 13.x siguen recibiendo mantenimiento, pero no indefinidamente |
| **Mitigación actual** | La versión está fijada explícitamente en `package.json` y en el flujo de integración continua, de modo que el entorno local y el de CI usan exactamente lo mismo |
| **Plan de pago** | Actualizar a JDK 21 en el documento 06 (etapas A.1 y A.2), subir `firebase-tools` a la última versión mayor y volver a ejecutar las pruebas de reglas. Costo: 0 USD. Esfuerzo estimado: menos de medio día |
| **Disparador para pagarla** | Cuando la línea 13.x deje de recibir correcciones de seguridad, o cuando se necesite una funcionalidad de la CLI que solo exista en la 14 o posterior |

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

## Resumen

| ID | Deuda | Origen | Severidad | Estado | Costo de pagarla |
|----|-------|--------|:---:|--------|:---:|
| DT-01 | Sin aplicación nativa ni tiendas | Alcance / Costo | Alta | Abierta | 0 USD (Android) |
| DT-02 | Sin sonido ni vibración en iOS | Plataforma | Alta | Abierta | 99 USD/año |
| DT-03 | Inestabilidad de push en iOS | Plataforma | Alta | Abierta | 0 USD |
| DT-04 | Acceso a adjuntos sin verificar destinatario | Plataforma | Media | Abierta | 0 USD |
| DT-05 | Precisión del planificador de 60 s | Costo | Baja | Aceptada | — |
| DT-06 | Dominio duplicado Dart / TypeScript | Conocimiento | Media | Mitigada | 0 USD |
| DT-07 | Sin observabilidad ni alertas | Alcance | Media | Abierta | 0 USD |
| DT-08 | Grupos limitados a 200 miembros | Alcance | Baja | Aceptada | 0 USD |
| DT-09 | Sin multi-idioma | Alcance | Baja | Mitigada | 0 USD |
| DT-10 | Sin cifrado de extremo a extremo | Alcance | Baja | Aceptada | — |
| DT-11 | Firebase CLI anclada a la versión 13 | Plataforma | Baja | Abierta | 0 USD |
| DT-12 | Vulnerabilidades moderadas de `firebase-admin` | Plataforma | Baja | Abierta | 0 USD |

**Prioridad de pago recomendada, en orden:** DT-03 → DT-07 → DT-04 → DT-01.

Las tres primeras cuestan cero y eliminan los riesgos operativos más serios. DT-02 es la
única deuda que exige presupuesto real, y solo se paga si la institución decide que las
alertas de emergencia deben sonar distinto en iPhone sin excepción.

---

## Procedimiento de actualización

1. Toda decisión que introduzca deuda se registra **en el mismo pull request** que la
   introduce.
2. Cada entrada nueva recibe el siguiente ID correlativo y no se reutilizan IDs.
3. Al pagar una deuda, no se borra la entrada: se cambia su estado a **Pagada** y se anota la
   fecha y el commit que la resolvió. El historial es parte del valor didáctico del proyecto.
4. Este documento se revisa al cierre de cada fase del plan de iteraciones.
