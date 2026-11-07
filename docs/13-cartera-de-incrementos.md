# 13 · Cartera de incrementos

**Versión:** 1.1 · 6 de noviembre de 2026

**Qué es este documento.** La **única lista** de lo que falta por hacer en SIAN y en qué
orden se pide. Cada propuesta, del responsable o del equipo, se registra aquí **antes** de
implementarse, y su estado se actualiza en el mismo pull request que la cambia. Así se ve de
un vistazo qué está hecho, qué está en camino y qué queda pendiente.

Los demás documentos explican el detalle y no repiten el estado:

- **01** fija el requisito (RF/RNF) cuando una propuesta se aprueba.
- **07** guarda la causa, el impacto y el plan de pago de cada deuda técnica (DT-n).
- **08** lleva el historial de cada versión liberada.
- **12** tiene el análisis de la evolución 1.6, 2.0 y 2.1/2.2, aprobado el 23/09/2026.

---

## Estados

| Estado | Significa |
|---|---|
| Propuesta | Registrada, todavía sin aprobar por el responsable |
| Aprobada | El responsable la aprobó; espera su turno |
| En desarrollo | Rama o PR abierto hacia `develop` |
| En dev | Fusionada y desplegada en desarrollo; falta que el responsable la pruebe |
| En QA | Promovida a `qa` y desplegada |
| En producción | Liberada; se anota la versión y la fecha |
| Descartada | No se hará; se anota por qué |
| Bloqueada | Depende de algo externo; se anota de qué |

**Reglas de orden.** Las correcciones van antes que las mejoras. Lo que tiene fecha límite va
primero. Lo pequeño y visible va antes que lo grande. Las sedes (2.0) van antes que el
repositorio (2.1), para no migrar los datos dos veces.

---

## Tabla principal

La tabla va por grupos para que nada quede escondido dentro de otra fila. Cada
funcionalidad nueva tiene **su propia fila**, con el requisito del documento 01 como ID.

### A. Lo siguiente: correcciones

| Orden | ID | Incremento | Tipo | Prioridad | Estado | Versión | PR | Actualizado |
|---|---|---|---|---|---|---|---|---|
| 1 | DT-35 | Tocar la notificación de una respuesta no la abre en iPhone | Corrección | Media | Aprobada | — | — | 2026-11-06 |

### B. Funcionalidades nuevas aprobadas

Pedidas por el responsable el 23/09/2026 y aprobadas ese mismo día, con todas las decisiones
del documento 12, sección 10. Análisis en el documento 12 (secciones 6 y 7), ADR-009 y ADR-010.
**Ninguna está empezada.** Van en este orden: las sedes primero, para no migrar el repositorio
después.

**2.0 · Varias sedes**

| Orden | ID | Incremento | Tipo | Prioridad | Estado | Versión | PR | Actualizado |
|---|---|---|---|---|---|---|---|---|
| 2 | RF-SED-01 | Cada aviso, grupo, carpeta y registro de bitácora pertenece a una sede | Funcionalidad | Alta | Aprobada | 2.0 | — | 2026-11-06 |
| 3 | RF-SED-02 | Una persona en varias sedes, con un rol en cada una | Funcionalidad | Alta | Aprobada | 2.0 | — | 2026-11-06 |
| 4 | RF-SED-03 | «Enviar a todos» significa todos los de la sede elegida | Funcionalidad | Alta | Aprobada | 2.0 | — | 2026-11-06 |
| 5 | RF-SED-04 | Quien está en más de una sede elige en cuál trabaja; con una sola, no se le pregunta | Funcionalidad | Alta | Aprobada | 2.0 | — | 2026-11-06 |
| 6 | RF-SED-05 | Nadie ve ni modifica nada de una sede a la que no pertenece | Seguridad | Alta | Aprobada | 2.0 | — | 2026-11-06 |
| 7 | RF-SED-06 | Rol de administración general: crea sedes y asigna a sus coordinadores | Funcionalidad | Alta | Aprobada | 2.0 | — | 2026-11-06 |

**2.1 · Repositorio de archivos: administración**

| Orden | ID | Incremento | Tipo | Prioridad | Estado | Versión | PR | Actualizado |
|---|---|---|---|---|---|---|---|---|
| 8 | RF-REP-01 | Crear, renombrar y borrar carpetas, hasta dos niveles | Funcionalidad | Media | Aprobada | 2.1 | — | 2026-11-06 |
| 9 | RF-REP-02 | Subir archivos de tipos permitidos, de hasta 25 MB | Funcionalidad | Media | Aprobada | 2.1 | — | 2026-11-06 |
| 10 | RF-REP-03 | Cupo de almacenamiento por sede (2 GB) que el servidor no deja superar | Funcionalidad | Media | Aprobada | 2.1 | — | 2026-11-06 |
| 11 | RF-REP-04 | El acceso a cada carpeta se da por grupos | Funcionalidad | Media | Aprobada | 2.1 | — | 2026-11-06 |
| 12 | RF-REP-07 | No se aceptan ejecutables ni archivos comprimidos | Seguridad | Media | Aprobada | 2.1 | — | 2026-11-06 |

**2.2 · Repositorio de archivos: catedrático**

| Orden | ID | Incremento | Tipo | Prioridad | Estado | Versión | PR | Actualizado |
|---|---|---|---|---|---|---|---|---|
| 13 | RF-REP-05 | El catedrático ve y descarga solo las carpetas de sus grupos | Funcionalidad | Media | Aprobada | 2.2 | — | 2026-11-06 |
| 14 | RF-REP-06 | Descarga con enlace que caduca a los 10 minutos y queda en la bitácora (cierra DT-04 / S-6) | Seguridad | Media | Aprobada | 2.2 | — | 2026-11-06 |
| 15 | REP-AV | Aviso automático «hay un archivo nuevo en tu carpeta» (opcional) | Funcionalidad | Baja | Propuesta | 2.2 | — | 2026-11-06 |

### C. Seguridad y mantenimiento

| Orden | ID | Incremento | Tipo | Prioridad | Estado | Versión | PR | Actualizado |
|---|---|---|---|---|---|---|---|---|
| 16 | S-4 | Exigir App Check en las funciones | Seguridad | Media | Bloqueada | — | — | 2026-11-06 |
| 17 | DT-13 | La política de contraseñas se aplica solo en el cliente | Seguridad | Media | Propuesta | — | — | 2026-11-06 |
| 18 | DT-12 | Vulnerabilidades moderadas heredadas de `firebase-admin` | Seguridad | Baja | Propuesta | — | — | 2026-11-06 |
| 19 | MNT-M | Versiones mayores pendientes de dependencias | Mantenimiento | Media | Propuesta | — | — | 2026-11-06 |
| 20 | DT-11 | La CLI de Firebase queda anclada por JDK 17 | Deuda técnica | Media | Propuesta | — | — | 2026-11-06 |

### D. Funcionalidades propuestas, sin aprobar

| Orden | ID | Incremento | Tipo | Prioridad | Estado | Versión | PR | Actualizado |
|---|---|---|---|---|---|---|---|---|
| 21 | ALC-1 | Alcance muestra a quién no le aparecen los avisos (lo que queda de DT-31) | Funcionalidad | Media | Propuesta | — | — | 2026-11-06 |
| 22 | RF-CNF-09 | Recordatorio automático a quien no confirma | Funcionalidad | Media | Propuesta | — | — | 2026-11-06 |
| 23 | DT-03 | Aviso urgente también por correo | Funcionalidad | Media | Propuesta | — | — | 2026-11-06 |
| 24 | RF-ADM-04 | Tablero de métricas para la coordinación | Funcionalidad | Baja | Propuesta | — | — | 2026-11-06 |
| 25 | RF-BIT-06 | Exportar la bitácora a CSV | Funcionalidad | Baja | Propuesta | — | — | 2026-11-06 |
| 26 | RF-AUT-10 | Verificación en dos pasos para la coordinación | Seguridad | Baja | Propuesta | — | — | 2026-11-06 |
| 27 | RF-BIT-10 | Encadenamiento criptográfico de la bitácora | Seguridad | Baja | Propuesta | — | — | 2026-11-06 |
| 28 | DT-01 | Distribuir el APK de Android por descarga directa | Funcionalidad | Baja | Propuesta | — | — | 2026-11-06 |

### E. Deuda técnica menor

| Orden | ID | Incremento | Tipo | Prioridad | Estado | Versión | PR | Actualizado |
|---|---|---|---|---|---|---|---|---|
| 29 | DT-30 | Chrome puede marcar los avisos como «posible spam» | Deuda técnica | Media | Propuesta | — | — | 2026-11-06 |
| 30 | DT-15 | Reparación temporal de la fuente de iconos | Deuda técnica | Baja | Propuesta | — | — | 2026-11-06 |
| 31 | DT-16 | `Entorno.configuracionCompleta` no se usa | Deuda técnica | Baja | Propuesta | — | — | 2026-11-06 |

### F. Operación (no es código)

| Orden | ID | Incremento | Tipo | Prioridad | Estado | Versión | PR | Actualizado |
|---|---|---|---|---|---|---|---|---|
| 32 | OPS-1 | Personas sin un canal confiable en producción | Operación | Alta | Aprobada | — | — | 2026-11-06 |
| 33 | OPS-2 | Aparatos con versiones anteriores a 1.6.9 que impiden exigir App Check | Operación | Media | Aprobada | — | — | 2026-11-06 |
| 34 | OPS-3 | Medir la carga inicial en un iPhone real (S-7) | Operación | Baja | Aprobada | — | — | 2026-11-06 |
| 35 | OPS-4 | Registrar el estado del despliegue escalonado (3.2), la estabilización (3.3) y el criterio de salida de la fase 3 | Operación | Media | Aprobada | — | — | 2026-11-06 |

### G. Documentación

| Orden | ID | Incremento | Tipo | Prioridad | Estado | Versión | PR | Actualizado |
|---|---|---|---|---|---|---|---|---|
| 36 | DOC-07 | Estados viejos en el resumen del documento 07 (DT-07, DT-21, DT-23) | Documentación | Baja | En desarrollo | — | — | 2026-11-06 |
| 37 | DOC-CAT | El guion de la cátedra dice 12 pasos de despliegue y son 15 | Documentación | Baja | Aprobada | — | — | 2026-11-06 |

### H. Bloqueadas por algo externo

| Orden | ID | Incremento | Tipo | Prioridad | Estado | Versión | PR | Actualizado |
|---|---|---|---|---|---|---|---|---|
| 38 | DT-14 | Los correos de la cuenta caen en No deseado (C-4) | Corrección | Media | Bloqueada | — | — | 2026-11-06 |
| 39 | RES | Canal de respaldo por SMS o WhatsApp | Funcionalidad | Media | Bloqueada | — | — | 2026-11-06 |
| 40 | DT-02 | Sonido y vibración propios en iPhone | Funcionalidad | Baja | Bloqueada | — | — | 2026-11-06 |

---

## Fichas

### MNT-11 · Actualización mensual de dependencias de noviembre

- **Estado:** En producción (1.6.19, 2026-11-03, PR #217) · **Prioridad:** Media · **Origen:** flujo mensual automático (S-8), 2026-11-01
- **Problema:** las dependencias se desactualizan solas; cada mes sin actualizar acumula
  riesgo.
- **Propuesta:** menores y parches dentro de los rangos declarados, en `app/pubspec.lock`,
  `functions/package-lock.json` y `package-lock.json`.
- **Criterios de aceptación:**
  - [x] La integración continua completa en verde (5 de 5 controles)
  - [x] Despliegue a desarrollo en verde, con sus verificaciones de sistema
  - [x] En QA y producción como 1.6.19 (2026-11-03)
- **Pruebas:** la batería completa de la CI, sin cambios en las pruebas.
- **Accesibilidad y usabilidad:** no aplica (no cambia ninguna pantalla).
- **Documentos tocados:** 08 y notas de la versión (en 1.6.19).
- **Historial:** 2026-11-01 Propuesta (PR automático) · 2026-11-02 En dev · 2026-11-03 En QA y en producción

### DEM-1 · Demostraciones de CI/CD para la cátedra

- **Estado:** En producción (1.6.19, 2026-11-03; PR #214, #215 y #216) · **Prioridad:** Media · **Origen:** responsable, 2026-10-14
- **Problema:** mostrar en clase, con el proyecto real, cómo la CI detiene un error y deja
  pasar su corrección: una prueba de unidad, una de integración y una de interfaz.
- **Propuesta:** tres cambios pequeños que no tocan la aplicación:
  `functions/test/unidad/demostraciones/` (ordenar versiones),
  la colección `demostraciones` de solo lectura en `firestore.rules` con sus dos pruebas, y
  `app/test/demostraciones/contador_avisos.dart` con su prueba de widget.
- **Criterios de aceptación:**
  - [x] Cada demostración falla primero en un control distinto y pasa después de corregirla
  - [x] Desplegadas en desarrollo
  - [x] En QA y producción, y las tres ramas iguales (2026-11-03)
- **Pruebas:** 1 de unidad (Functions), 2 de reglas contra el emulador, 2 de widget.
- **Accesibilidad y usabilidad:** no aplica (no hay pantalla nueva).
- **Documentos tocados:** el guion de la cátedra vive fuera del repositorio
  (`SIAN-Git-CICD-GitHub-Actions.docx`). Su corrección quedó como DOC-CAT.
- **Historial:** 2026-10-14 Aprobada · 2026-10-17 En dev · 2026-11-03 En producción

### DOC-13 · Esta cartera de incrementos

- **Estado:** En producción (1.6.19, 2026-11-03, PR #218; ampliada el 2026-11-06) · **Prioridad:** Alta · **Origen:** responsable, 2026-11-02
- **Problema:** las propuestas estaban repartidas en los documentos 07, 08 y 12, con estados
  que ya no eran ciertos (varias decían «hecho en desarrollo» estando en producción).
- **Propuesta:** una sola lista con formato estándar, estados fijos y fichas con criterios
  marcables.
- **Criterios de aceptación:**
  - [x] Recoge lo pendiente de los documentos 07, 08 y 12
  - [x] El README y los documentos 08 y 12 la enlazan
  - [ ] El responsable la revisa y aprueba el orden
  - [x] Cada funcionalidad nueva tiene su propia fila (1.1, 2026-11-06)
- **Pruebas:** no aplica (solo documentación); la CI completa en verde.
- **Accesibilidad y usabilidad:** no aplica.
- **Documentos tocados:** 13 (nuevo), README, 08, 12.
- **Historial:** 2026-11-02 Aprobada · 2026-11-02 En dev · 2026-11-03 En producción · 2026-11-06 versión 1.1: sedes y repositorio separados por requisito; temas de operación y documentación agregados

### DT-35 · Tocar la notificación de una respuesta no la abre en iPhone

- **Estado:** Aprobada · **Prioridad:** Media · **Origen:** responsable, 2026-09-24
- **Problema:** en Android, tocar la notificación abre la respuesta. En iPhone la aplicación
  se queda en la bandeja. Desde 1.6.15 la respuesta devuelve el aviso a «Sin leer», así que
  no se pierde, pero no se llega directo a ella.
- **Propuesta:** encontrar por qué el mensaje del service worker no llega a la página en la
  PWA de iOS (la página puede estar congelada o restaurarse sin cargar) y llevar a la
  respuesta sin importar el filtro del aviso.
- **Criterios de aceptación:**
  - [ ] En iPhone, tocar la notificación de una respuesta abre esa conversación
  - [ ] Funciona con la aplicación cerrada, en segundo plano y abierta
  - [ ] Android sigue funcionando igual (regresión)
- **Pruebas:** prueba de widget de la apertura y prueba del service worker (`npm run test:sw`);
  prueba manual en iPhone según el guion C6 del documento 09.
- **Accesibilidad y usabilidad:** heurística de Nielsen «estado visible del sistema»: la
  persona debe ver la respuesta que motivó la notificación.
- **Documentos tocados:** 07 (DT-35), 09, manual del catedrático.
- **Historial:** 2026-09-24 Aprobada · 2026-09-28 mitigada en producción (1.6.0, 1.6.15)

### S-4 · Exigir App Check en las funciones

- **Estado:** Bloqueada · **Prioridad:** Media · **Origen:** revisión de registros, 2026-09-23 (DT-33)
- **Problema:** las funciones aceptan llamadas hechas fuera de la aplicación. App Check está
  en modo observación en los tres ambientes desde el 28/09 (`EXIGIR_APP_CHECK = false`).
- **Bloqueo:** si se exige hoy, los aparatos con versiones anteriores a 1.6.9 dejarían de
  funcionar. Al 10/10 eran 4 de 28 en producción.
- **Propuesta:** cuando ningún aparato activo use una versión anterior a 1.6.9, cambiar a
  `EXIGIR_APP_CHECK = true`, primero en desarrollo, luego en QA y por último en producción.
- **Criterios de aceptación:**
  - [ ] Una semana sin llamadas sin token (`MISSING`) en producción
  - [ ] Ningún aparato activo en una versión anterior a 1.6.9 (se ve en Alcance)
  - [ ] Exigido en los tres ambientes, con la prueba de `appCheck.test.ts` actualizada
- **Pruebas:** `functions/test/unidad/appCheck.test.ts`.
- **Accesibilidad y usabilidad:** a quien tenga una versión vieja, la aplicación debe
  decirle que actualice, no fallar en silencio.
- **Documentos tocados:** 07 (DT-33), 11.
- **Historial:** 2026-09-23 Aprobada · 2026-09-28 en observación en los tres ambientes · 2026-11-02 Bloqueada

### DT-13 · La política de contraseñas se aplica solo en el cliente

- **Estado:** Propuesta · **Prioridad:** Media · **Origen:** documento 07
- **Problema:** las reglas de la contraseña (largo y composición) se comprueban en la
  aplicación, no en el servidor.
- **Propuesta:** activar la política de contraseñas de Firebase Authentication en los tres
  ambientes, alineada con `politicaContrasena`.
- **Criterios de aceptación:**
  - [ ] Una contraseña débil se rechaza aunque no venga de la aplicación
  - [ ] El mensaje de error dice qué falta, en lenguaje de usuario
- **Pruebas:** `politicaContrasena.test.ts` y una prueba manual en desarrollo.
- **Accesibilidad y usabilidad:** Nielsen, «mensajes de error que ayudan».
- **Documentos tocados:** 07, 11.

### DT-12 · Vulnerabilidades moderadas heredadas de `firebase-admin`

- **Estado:** Propuesta · **Prioridad:** Baja · **Origen:** documento 07
- **Propuesta:** revisar `npm audit` después de MNT-M; cerrar la ficha si la versión mayor
  nueva las elimina.
- **Criterios de aceptación:**
  - [ ] `npm audit --audit-level=moderate --omit=dev` sin hallazgos, o cada uno justificado en el 07
- **Documentos tocados:** 07.

### MNT-M · Versiones mayores pendientes de dependencias

- **Estado:** Propuesta · **Prioridad:** Media · **Origen:** PR #217 (lista de mayores, 2026-11-01)
- **Problema:** el flujo mensual solo sube menores y parches. Quedan mayores pendientes:
  `firebase-functions` 7, `firebase-admin` 14, `firebase` 13, `eslint` 10, `typescript` 7 y
  los complementos de Firebase para Flutter (`cloud_firestore` 7, `firebase_auth` 7,
  `firebase_core` 5, entre otros).
- **Propuesta:** subirlas de a una familia por PR, leyendo las notas de cada versión, con la
  CI decidiendo.
- **Criterios de aceptación:**
  - [ ] Cada familia en su PR, con la batería completa en verde
  - [ ] El total de pruebas no baja
  - [ ] Probado en desarrollo con un aviso real de punta a punta
- **Pruebas:** regresión completa (Functions, reglas, service worker, aplicación).
- **Documentos tocados:** 06, 07 (DT-12), 11.

### DT-11 · La CLI de Firebase queda anclada por JDK 17

- **Estado:** Propuesta · **Prioridad:** Media · **Origen:** documento 07
- **Problema:** `firebase-tools` 14 o posterior exige JDK 21; esta Mac y el documento 06 usan
  JDK 17, así que la CLI queda en la serie 13.
- **Propuesta:** instalar JDK 21, subir `firebase-tools` y actualizar el documento 06.
- **Criterios de aceptación:**
  - [ ] Los emuladores y los despliegues funcionan con la versión nueva
- **Documentos tocados:** 06, 07.

### 2.0 · Varias sedes (RF-SED-01 a RF-SED-06)

- **Estado:** Aprobada (2026-09-23), sin empezar · **Prioridad:** Alta · **Origen:** responsable, pedido del 23/09/2026: «esto puede crecer a nuevas sedes y cada usuario puede pertenecer a diferentes sedes»
- **Propuesta:** un solo proyecto con los datos separados por sede, no un proyecto por sede.
  Las membresías (`membresias: { bdm: 'COORDINADOR', … }`) viajan en el token de sesión,
  como hoy el rol. Un selector de sede en la barra, que solo aparece con más de una sede.
  Migración en siete pasos, de ampliar y después contraer: la app vieja sigue funcionando
  hasta que las reglas exigen la sede. Detalle en el documento 12, sección 6, y en el ADR-009.
- **Criterios de aceptación (uno por requisito):**
  - [ ] RF-SED-01 · Mensajes, grupos, bitácora y carpetas llevan `sedeId`; un guion idempotente pone `bdm` en todo lo existente
  - [ ] RF-SED-02 · Una persona tiene un rol distinto en cada sede
  - [ ] RF-SED-03 · «Enviar a todos» resuelve solo dentro de la sede elegida
  - [ ] RF-SED-04 · El selector aparece solo con más de una sede
  - [ ] RF-SED-05 · Una persona de la sede A no ve nada de la B: avisos, grupos ni bitácora
  - [ ] RF-SED-06 · Solo la administración general crea sedes y asigna coordinadores
  - [ ] Respaldo de producción verificado antes de migrar; correr la migración dos veces deja lo mismo
  - [ ] Probado en desarrollo y QA con datos parecidos a los de producción
- **Pruebas:** reglas por sede contra el emulador, dominio («todos» por sede), migración
  contra el emulador, guion en el documento 09; regresión completa.
- **Accesibilidad y usabilidad:** la sede actual siempre visible (estado del sistema); el
  selector con etiqueta para lectores de pantalla y navegable con el tabulador.
- **Documentos tocados:** 01, 02, 05, 09, 10, 11, ADR-009, los dos manuales.

### 2.1 · Repositorio de archivos: administración (RF-REP-01 a 04 y 07)

- **Estado:** Aprobada (2026-09-23), sin empezar; va después de 2.0 · **Prioridad:** Media · **Origen:** responsable, 23/09/2026: carpetas, archivos con límite de tamaño y acceso por grupos, «validar si esto es posible en firebase … y que no dispare costos»
- **Costo (comprobado el 23/09):** cabe en la cuota gratuita de Storage en `us-central1`
  (5 GB guardados, 100 GB de descarga al mes). Hoy los adjuntos ocupan 1,5 MB.
- **Propuesta:** `sedes/{s}/carpetas/{c}` y sus `archivos/{a}`; el archivo en
  `repositorio/{sede}/{carpeta}/{archivo}`. Detalle en el documento 12, sección 7, y en el ADR-010.
- **Criterios de aceptación:**
  - [ ] RF-REP-01 · Coordinación y administración crean, renombran y borran carpetas, hasta dos niveles
  - [ ] RF-REP-02 · Suben PDF, Word, Excel, PowerPoint, imágenes y texto de hasta 25 MB
  - [ ] RF-REP-03 · El servidor rechaza la subida que pasaría el cupo de la sede (2 GB), con un mensaje claro
  - [ ] RF-REP-04 · Dan y quitan acceso a una carpeta por grupos
  - [ ] RF-REP-07 · Ejecutables y comprimidos se rechazan
  - [ ] La coordinación ve el cupo usado
- **Pruebas:** reglas (un catedrático no sube ni lista carpetas), dominio (cupo, tipos,
  acceso), regresión completa.
- **Accesibilidad y usabilidad:** subir con progreso visible y opción de cancelar; errores
  que digan qué pasó y qué hacer.
- **Documentos tocados:** 01, 02, 05, 09, 10, ADR-010, manual de coordinación.

### 2.2 · Repositorio de archivos: catedrático (RF-REP-05 y 06, REP-AV)

- **Estado:** Aprobada (2026-09-23), sin empezar · **Prioridad:** Media · **Origen:** responsable, 23/09/2026: «luego se agregará al catedrático esta opción … para que descargue los archivos si tiene acceso»
- **Propuesta:** una sección **Archivos** con solo sus carpetas. La descarga la entrega una
  función con un enlace firmado de 10 minutos, después de comprobar el acceso; el mismo
  mecanismo cierra DT-04 para los adjuntos de los avisos.
- **Criterios de aceptación:**
  - [ ] RF-REP-05 · El catedrático ve solo las carpetas de sus grupos
  - [ ] RF-REP-06 · La descarga usa un enlace que caduca y queda en la bitácora
  - [ ] Quitarle el acceso a un grupo surte efecto de inmediato
  - [ ] DT-04 · Un catedrático no puede descargar un adjunto que no le corresponde, aunque conozca la ruta
  - [ ] REP-AV (opcional, Propuesta) · Aviso automático de archivo nuevo en una carpeta
- **Pruebas:** reglas y función de enlace; de punta a punta en QA: subir un PDF, verlo
  como catedrático del grupo y **no** verlo como catedrático de otro grupo.
- **Accesibilidad y usabilidad:** nombres de archivo legibles por lectores de pantalla,
  tamaño y tipo visibles antes de descargar.
- **Documentos tocados:** 05, 07 (DT-04), 09, 10, manual del catedrático.

### ALC-1 · Alcance muestra a quién no le aparecen los avisos

- **Estado:** Propuesta · **Prioridad:** Media · **Origen:** lo que queda de DT-31 (documento 07)
- **Problema:** el acuse ya registra si el aparato **mostró** el aviso, pero ninguna pantalla
  lista a quién le llegan los avisos sin que los vea.
- **Propuesta:** en Alcance, una lista plegable de personas cuyos aparatos no mostraron los
  últimos avisos, para saber a quién llamar.
- **Criterios de aceptación:**
  - [ ] La lista sale de los acuses, sin lecturas extra por cada persona
  - [ ] Distingue «no lo mostró» de «no sabe acusar» (versión vieja)

### RF-CNF-09 · Recordatorio automático a quien no confirma

- **Estado:** Propuesta · **Prioridad:** Media · **Origen:** documentos 08 y 12
- **Propuesta:** volver a avisar, una sola vez y tras un plazo configurable, a quien no
  confirmó un aviso que pedía confirmación.

### DT-03 · Redundancia por correo para los avisos urgentes

- **Estado:** Propuesta · **Prioridad:** Media · **Origen:** documento 08 (cartera, prioridad 1)
- **Propuesta:** enviar también por correo los avisos urgentes. Depende de DT-14 para que el
  correo no caiga en No deseado.

### RF-ADM-04 · Tablero de métricas para la coordinación

- **Estado:** Propuesta · **Prioridad:** Baja · **Origen:** documento 08

### RF-BIT-06 · Exportar la bitácora a CSV

- **Estado:** Propuesta · **Prioridad:** Baja · **Origen:** documento 08

### RF-AUT-10 · Verificación en dos pasos para la coordinación

- **Estado:** Propuesta · **Prioridad:** Baja · **Origen:** documento 08

### RF-BIT-10 · Encadenamiento criptográfico de la bitácora

- **Estado:** Propuesta · **Prioridad:** Baja · **Origen:** documento 08

### DT-30 · Chrome puede marcar los avisos como «posible spam»

- **Estado:** Propuesta · **Prioridad:** Media · **Origen:** documento 07

### DT-15 · Reparación temporal de la fuente de iconos

- **Estado:** Propuesta · **Prioridad:** Baja · **Origen:** documento 07

### DT-16 · `Entorno.configuracionCompleta` no se usa

- **Estado:** Propuesta · **Prioridad:** Baja · **Origen:** documento 07

### DT-01 · Distribuir el APK de Android por descarga directa

- **Estado:** Propuesta · **Prioridad:** Baja · **Origen:** documentos 07 y 08
- **Nota:** distribuirlo por Play Store (TWA) no es una salida segura sin comprobarlo antes.

### OPS-1 · Personas sin un canal confiable en producción

- **Estado:** Aprobada · **Prioridad:** Alta · **Origen:** documento 07 (DT-31)
- **Problema:** 8 personas dependen de un canal débil antes de que falle nada: 3 sin ningún
  aparato registrado, 4 con la aplicación sin instalar en el celular y 1 solo en una
  computadora. **No es código**: hay que contactarlas.
- **Criterios de aceptación:**
  - [ ] La lista actual sale de Alcance en producción
  - [ ] Cada persona contactada, con la guía de instalación del manual
  - [ ] Se vuelve a medir y se anota el resultado aquí

### OPS-2 · Aparatos que impiden exigir App Check

- **Estado:** Aprobada · **Prioridad:** Media · **Origen:** S-4
- **Problema:** al 10/10 había 4 de 28 aparatos de producción con versiones anteriores a 1.6.9:
  uno en Android que debe actualizar, un iPhone del responsable con un registro viejo y dos
  registros de computadora que la sonda debía retirar hacia el 26–27/10.
- **Criterios de aceptación:**
  - [ ] Comprobar en Alcance de producción qué aparatos quedan en versiones anteriores a 1.6.9
  - [ ] Cada uno actualizado o retirado
  - [ ] Con cero, S-4 pasa de Bloqueada a Aprobada

### OPS-3 · Medir la carga inicial en un iPhone real (S-7)

- **Estado:** Aprobada · **Prioridad:** Baja · **Origen:** documento 12, «Medición de la carga inicial»
- **Lo hace el responsable:** abrir SIAN instalada dos veces seguidas, con buena señal y con
  datos móviles, y comparar con lo que tardaba antes de la 1.6.11.
- **Criterios de aceptación:**
  - [ ] Resultado anotado en el documento 12

### OPS-4 · Estado del despliegue escalonado y de la estabilización

- **Estado:** Aprobada · **Prioridad:** Media · **Origen:** documento 08, iteraciones 3.2 y 3.3
- **Problema:** el documento 08 planifica el despliegue por etapas (coordinación, una
  facultad, toda la institución), la estabilización del primer mes y un criterio de salida
  (un mes con más de 95 % de entrega y sin incidencias graves), pero no registra en qué punto
  está cada uno.
- **Criterios de aceptación:**
  - [ ] El responsable indica qué etapa se alcanzó
  - [ ] La tasa de entrega del último mes se mide con los acuses y se anota
  - [ ] El documento 08 marca cada iteración como hecha o en curso

### DOC-07 · Estados viejos en el resumen del documento 07

- **Estado:** En desarrollo (este PR) · **Prioridad:** Baja · **Origen:** revisión del 2026-11-06
- **Problema:** el resumen decía «Pagada (en desarrollo y QA)» para DT-07, DT-21 y DT-23, que
  están en producción desde la 1.5.11 (2026-09-14).
- **Criterios de aceptación:**
  - [x] El resumen dice «en producción desde 1.5.11»

### DOC-CAT · El guion de la cátedra dice 12 pasos y son 15

- **Estado:** Aprobada · **Prioridad:** Baja · **Origen:** demostración del 2026-10-17
- **Problema:** el documento `SIAN-Git-CICD-GitHub-Actions.docx` (fuera del repositorio)
  dice que el job de despliegue tiene 12 pasos; tiene 15 propios.
- **Criterios de aceptación:**
  - [ ] El guion dice «los pasos del despliegue» o el número correcto

### DT-14 · Los correos de la cuenta caen en No deseado (C-4)

- **Estado:** Bloqueada · **Prioridad:** Media · **Origen:** documento 07
- **Bloqueo:** depende de Sistemas de la UMG (un buzón propio y los registros SPF/DKIM del
  dominio). No hay nada que hacer en el código.

### RES · Canal de respaldo por SMS o WhatsApp

- **Estado:** Bloqueada · **Prioridad:** Media · **Origen:** documento 12, sección 8
- **Bloqueo:** aplazado por decisión del responsable. Es lo único que cubre a quien no abre
  la aplicación; se retoma cuando se decida.

### DT-02 · Sonido y vibración propios en iPhone

- **Estado:** Bloqueada · **Prioridad:** Baja · **Origen:** documento 07
- **Bloqueo:** exige una aplicación nativa y la cuenta de desarrollador de Apple (99 USD al
  año).

---

## Ya liberado

Lo terminado no se repite aquí. El detalle de cada versión está en el documento 08, y el de
cada deuda pagada, en el 07. En resumen:

| Versión | En producción | Qué cerró |
|---|---|---|
| 1.5.11 | 2026-09-14 | Web Push directo con llaves VAPID propias, responder a un aviso (DT-27), acuse de lo mostrado (DT-31), manual dentro de la aplicación (DT-28) |
| 1.5.13 | 2026-09-24 | Node.js 22 (DT-32 / S-1), respaldos diarios de Firestore (S-2), presupuestos (S-3) |
| 1.6.0 a 1.6.17 | 2026-09-28 | C-6, U-1 a U-7, App Check en observación (S-4), fallos del aparato (S-5 / DT-34), carga inicial (S-7), dependencias mensuales y rotación de VAPID (S-8, S-9), mensajes de 1000 caracteres, plantillas (RF-MSG-14), respuestas en «Sin leer» |
| 1.6.18 | 2026-10-15 | Mantenimiento de octubre y resumen de la sonda |
| 1.6.19 | 2026-11-03 | Mantenimiento de noviembre (MNT-11), demostraciones de CI/CD (DEM-1) y esta cartera (DOC-13) |
