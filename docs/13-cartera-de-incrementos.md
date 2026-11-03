# 13 · Cartera de incrementos

**Versión:** 1.0 · 2 de noviembre de 2026

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

| Orden | ID | Incremento | Tipo | Prioridad | Estado | Versión | PR | Actualizado |
|---|---|---|---|---|---|---|---|---|
| 1 | MNT-11 | Actualización mensual de dependencias de noviembre | Mantenimiento | Media | En dev | 1.6.19 | #217 | 2026-11-02 |
| 2 | DEM-1 | Demostraciones de CI/CD para la cátedra | CI/CD | Media | En dev | 1.6.19 | #214, #215, #216 | 2026-11-02 |
| 3 | DOC-13 | Esta cartera de incrementos | Documentación | Alta | En desarrollo | 1.6.19 | este PR | 2026-11-02 |
| 4 | DT-35 | Tocar la notificación de una respuesta no la abre en iPhone | Corrección | Media | Aprobada | — | — | 2026-11-02 |
| 5 | S-4 | Exigir App Check en las funciones | Seguridad | Media | Bloqueada | — | — | 2026-11-02 |
| 6 | DT-13 | La política de contraseñas se aplica solo en el cliente | Seguridad | Media | Propuesta | — | — | 2026-11-02 |
| 7 | DT-12 | Vulnerabilidades moderadas heredadas de `firebase-admin` | Seguridad | Baja | Propuesta | — | — | 2026-11-02 |
| 8 | MNT-M | Versiones mayores pendientes de dependencias | Mantenimiento | Media | Propuesta | — | — | 2026-11-02 |
| 9 | DT-11 | La CLI de Firebase queda anclada por JDK 17 | Deuda técnica | Media | Propuesta | — | — | 2026-11-02 |
| 10 | SED | Varias sedes; una persona en más de una | Mejora | Alta | Aprobada | 2.0 | — | 2026-11-02 |
| 11 | REP-A | Repositorio de archivos: administración | Mejora | Media | Aprobada | 2.1 | — | 2026-11-02 |
| 12 | REP-C | Repositorio de archivos: catedrático (cierra DT-04 / S-6) | Mejora | Media | Aprobada | 2.2 | — | 2026-11-02 |
| 13 | RF-CNF-09 | Recordatorio automático a quien no confirma | Mejora | Media | Propuesta | — | — | 2026-11-02 |
| 14 | DT-03 | Redundancia por correo para los avisos urgentes | Mejora | Media | Propuesta | — | — | 2026-11-02 |
| 15 | RF-ADM-04 | Tablero de métricas para la coordinación | Mejora | Baja | Propuesta | — | — | 2026-11-02 |
| 16 | RF-BIT-06 | Exportar la bitácora a CSV | Mejora | Baja | Propuesta | — | — | 2026-11-02 |
| 17 | RF-AUT-10 | Verificación en dos pasos para la coordinación | Seguridad | Baja | Propuesta | — | — | 2026-11-02 |
| 18 | RF-BIT-10 | Encadenamiento criptográfico de la bitácora | Seguridad | Baja | Propuesta | — | — | 2026-11-02 |
| 19 | DT-30 | Chrome puede marcar los avisos como «posible spam» | Deuda técnica | Media | Propuesta | — | — | 2026-11-02 |
| 20 | DT-15 | Reparación temporal de la fuente de iconos | Deuda técnica | Baja | Propuesta | — | — | 2026-11-02 |
| 21 | DT-16 | `Entorno.configuracionCompleta` no se usa | Deuda técnica | Baja | Propuesta | — | — | 2026-11-02 |
| 22 | DT-01 | Distribuir el APK de Android por descarga directa | Mejora | Baja | Propuesta | — | — | 2026-11-02 |
| 23 | DT-14 | Los correos de la cuenta caen en No deseado (C-4) | Corrección | Media | Bloqueada | — | — | 2026-11-02 |
| 24 | RES | Canal de respaldo por SMS o WhatsApp | Mejora | Media | Bloqueada | — | — | 2026-11-02 |
| 25 | DT-02 | Sonido y vibración propios en iPhone | Mejora | Baja | Bloqueada | — | — | 2026-11-02 |

---

## Fichas

### MNT-11 · Actualización mensual de dependencias de noviembre

- **Estado:** En dev (PR #217, fusionado el 2026-11-02) · **Prioridad:** Media · **Origen:** flujo mensual automático (S-8), 2026-11-01
- **Problema:** las dependencias se desactualizan solas; cada mes sin actualizar acumula
  riesgo.
- **Propuesta:** menores y parches dentro de los rangos declarados, en `app/pubspec.lock`,
  `functions/package-lock.json` y `package-lock.json`.
- **Criterios de aceptación:**
  - [x] La integración continua completa en verde (5 de 5 controles)
  - [x] Despliegue a desarrollo en verde, con sus verificaciones de sistema
  - [ ] En QA y producción como 1.6.19
- **Pruebas:** la batería completa de la CI, sin cambios en las pruebas.
- **Accesibilidad y usabilidad:** no aplica (no cambia ninguna pantalla).
- **Documentos tocados:** 08 y notas de la versión (en 1.6.19).
- **Historial:** 2026-11-01 Propuesta (PR automático) · 2026-11-02 En dev

### DEM-1 · Demostraciones de CI/CD para la cátedra

- **Estado:** En dev (PR #214, #215 y #216, del 2026-10-17) · **Prioridad:** Media · **Origen:** responsable, 2026-10-14
- **Problema:** mostrar en clase, con el proyecto real, cómo la CI detiene un error y deja
  pasar su corrección: una prueba de unidad, una de integración y una de interfaz.
- **Propuesta:** tres cambios pequeños que no tocan la aplicación:
  `functions/test/unidad/demostraciones/` (ordenar versiones),
  la colección `demostraciones` de solo lectura en `firestore.rules` con sus dos pruebas, y
  `app/test/demostraciones/contador_avisos.dart` con su prueba de widget.
- **Criterios de aceptación:**
  - [x] Cada demostración falla primero en un control distinto y pasa después de corregirla
  - [x] Desplegadas en desarrollo
  - [ ] En QA y producción, para que las tres ramas queden iguales
- **Pruebas:** 1 de unidad (Functions), 2 de reglas contra el emulador, 2 de widget.
- **Accesibilidad y usabilidad:** no aplica (no hay pantalla nueva).
- **Documentos tocados:** el guion de la cátedra vive fuera del repositorio
  (`SIAN-Git-CICD-GitHub-Actions.docx`). Pendiente en ese guion: el despliegue tiene 15
  pasos propios, no 12.
- **Historial:** 2026-10-14 Aprobada · 2026-10-17 En dev

### DOC-13 · Esta cartera de incrementos

- **Estado:** En desarrollo · **Prioridad:** Alta · **Origen:** responsable, 2026-11-02
- **Problema:** las propuestas estaban repartidas en los documentos 07, 08 y 12, con estados
  que ya no eran ciertos (varias decían «hecho en desarrollo» estando en producción).
- **Propuesta:** una sola lista con formato estándar, estados fijos y fichas con criterios
  marcables.
- **Criterios de aceptación:**
  - [x] Recoge lo pendiente de los documentos 07, 08 y 12
  - [x] El README y los documentos 08 y 12 la enlazan
  - [ ] El responsable la revisa y aprueba el orden
- **Pruebas:** no aplica (solo documentación); la CI completa en verde.
- **Accesibilidad y usabilidad:** no aplica.
- **Documentos tocados:** 13 (nuevo), README, 08, 12.
- **Historial:** 2026-11-02 Aprobada · 2026-11-02 En desarrollo

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

### SED · Varias sedes; una persona en más de una (2.0)

- **Estado:** Aprobada (2026-09-23) · **Prioridad:** Alta · **Origen:** responsable
- **Propuesta:** un solo proyecto con los datos separados por sede, con un rol por sede.
  Migración en dos tiempos, detrás de un interruptor. Análisis completo en el documento 12,
  sección 6, y en el ADR-009.
- **Criterios de aceptación:**
  - [ ] Respaldo de producción verificado antes de migrar
  - [ ] Migración probada en desarrollo y QA con datos parecidos a los de producción
  - [ ] Una persona con rol distinto en dos sedes ve lo que le toca en cada una
  - [ ] Reglas de Firestore por sede, con sus pruebas contra el emulador
- **Pruebas:** unidad, reglas por sede, migración contra el emulador, guion en el documento 09.
- **Accesibilidad y usabilidad:** el cambio de sede debe verse siempre (estado visible).
- **Documentos tocados:** 01, 02, 05, 09, 10, 11, ADR-009, manuales.

### REP-A · Repositorio de archivos: administración (2.1)

- **Estado:** Aprobada (2026-09-23) · **Prioridad:** Media · **Origen:** responsable
- **Propuesta:** carpetas y grupos; descargas por enlace temporal de 10 minutos con registro
  en la bitácora; 25 MB por archivo y 2 GB por sede. Documento 12, sección 7, y ADR-010.
- **Criterios de aceptación:**
  - [ ] La coordinación crea carpetas, sube archivos y define quién los ve
  - [ ] Se respetan los límites, con un mensaje claro al pasarlos
- **Documentos tocados:** 01, 02, 05, 09, 10, ADR-010, manual de coordinación.

### REP-C · Repositorio de archivos: catedrático (2.2)

- **Estado:** Aprobada (2026-09-23) · **Prioridad:** Media · **Origen:** responsable
- **Propuesta:** el catedrático ve y descarga lo de sus grupos. Cierra DT-04 / S-6, porque
  los adjuntos pasan al mismo mecanismo de enlace temporal.
- **Criterios de aceptación:**
  - [ ] Un catedrático no puede descargar un archivo que no le corresponde, aunque conozca la ruta
- **Documentos tocados:** 05, 07 (DT-04), manual del catedrático.

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
