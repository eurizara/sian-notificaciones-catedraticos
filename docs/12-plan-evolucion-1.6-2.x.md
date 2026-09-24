# 12 · Plan de evolución: iteraciones 1.6, 2.0 y 2.1

**Estado:** **aprobado** por el responsable el 23/09/2026, con todas las recomendaciones de la
sección 10. En curso: **1.5.13** (en desarrollo). Escrito sobre lo que había en `develop`
(1.5.12), `qa` y `main` (1.5.11).

**Qué es este documento.** Recoge lo que pidió el responsable del proyecto el 23/09/2026 y
lo que se encontró al revisar el código para pedirlo. Para cada punto explica qué hay hoy, qué
se propone, cómo hacerlo sin romper lo que ya funciona, cómo se prueba y en qué orden va.
Cuando algo se apruebe, pasa al documento 08 como iteración y sus requisitos quedan firmes en
el documento 01.

---

## 1. Resumen

| # | Qué | Tamaño | Riesgo | Toca datos | Versión propuesta |
|---|-----|:---:|:---:|:---:|:---:|
| **U-0** | **Pasar las funciones de Node.js 20 a 22** — Google retira Node 20 el **30/10/2026** | S | Medio | No | **1.5.13 (urgente)** |
| **C-6** | **Tocar una notificación abre el aviso o la respuesta que la originó** (corrección, DT-35) | M | Medio | No | **1.6, lo primero** |
| U-1 | Copiar el título o el mensaje | S | Bajo | No | 1.6 |
| U-2 | Enlaces (URL) que se abren al tocarlos | S | Bajo | No | 1.6 |
| U-3 | Descargar las imágenes de un aviso | S–M | Bajo | No | 1.6 |
| U-4 | El tabulador recorre el formulario de redactar en orden | S | Bajo | No | 1.6 |
| U-5 | El manual sigue el modo claro/oscuro | S | Bajo | No | 1.6 |
| U-6 | Enviar a personas concretas (1 a n) | M | Bajo | No | 1.6 |
| U-7 | Mejoras de Alcance | M | Bajo | Sí (retiros) | 1.6 |
| S-1..S-5 | Rendimiento, estabilidad y seguridad | varía | — | — | 1.5.13 y 1.6 |
| **SED** | **Varias sedes; una persona en más de una** | **L** | **Alto** | **Sí (migración)** | **2.0** |
| **REP** | **Repositorio de archivos por carpetas y grupos** | **L** | Medio | Sí (nuevo) | **2.1** (administración) · **2.2** (catedrático) |

S = pocas horas · M = uno o dos días · L = una semana o más, con pruebas en QA.

**Sobre la numeración.** El pedido era anotar todo en 1.5.12. Según el esquema del documento
08, el número del medio es la **iteración** y el último sube con cada cambio liberado, así que
se propone:

- **1.5.12** se queda como está: la corrección de Alcance, ya en desarrollo.
- **1.5.13** para lo urgente e invisible (Node 22, respaldos, presupuestos).
- **1.6** para las mejoras de uso.
- **2.0** para las sedes, porque cambia el sistema y no solo una pantalla. El esquema reserva
  el primer número para eso.
- **2.1 / 2.2** para el repositorio.

Si se prefiere otra numeración, solo cambian los números; el orden sigue siendo el mismo.

---

## 2. Cómo se trabaja para no romper nada

Son las mismas reglas con las que se llegó a producción, más cuatro que exigen las sedes y el
repositorio.

**Las que ya rigen**

1. Una rama por cambio, desde `develop`, y un PR con los cuatro controles de CI en verde.
2. **Primero la prueba que reproduce el problema, después el arreglo.** Si una prueba no
   falla antes del cambio, no demuestra nada.
3. Desarrollo → QA → producción. **La fusión a `main` y la aprobación del despliegue las hace
   el responsable.**
4. En el mismo PR van la documentación, las **notas de la versión** y el guion de pruebas
   (documento 09). Hay pruebas que fallan si la versión no tiene sus notas.
5. Si algo falla en producción, se corrige hacia adelante. Revertir a ciegas puede dejar
   aparatos sin canal, como se vio con Web Push.

**Las nuevas, para sedes y repositorio**

6. **Migraciones en dos tiempos (ampliar y después contraer).**
   - Primero se **añade** el campo nuevo y el código aprende a leerlo y a escribirlo, **sin
     exigirlo**.
   - Luego se rellenan los datos que ya existen con un guion **idempotente**, que se puede
     correr dos veces sin daño.
   - Solo cuando todo está relleno y verificado, las reglas empiezan a exigirlo.

   Así una aplicación vieja, que no manda el campo nuevo, sigue funcionando mientras la gente
   actualiza.
7. **Interruptores por ambiente.** Lo grande se despliega apagado. Un documento
   `config/funciones` en Firestore lo enciende; lo leen la aplicación y el servidor, y lo
   respetan las reglas. Así el código llega a producción antes de estar visible, y se puede
   apagar sin desplegar.
8. **Respaldo antes de migrar.** Se exporta Firestore de producción antes de cualquier
   migración de datos, y se prueba restaurarlo en desarrollo.
9. **Reglas con pruebas.** Cada regla nueva, de Firestore o de Storage, lleva su prueba en el
   emulador: quién puede y, sobre todo, **quién no**.

---

## 3. Urgente: Node.js 20 se retira el 30 de octubre (U-0 · DT-32)

**Qué pasa.** Las 25 funciones corren en `nodejs20` (en `firebase.json` y en los flujos de
CI). La tabla oficial de Google dice:

| Runtime | Obsoleto desde | Retirado desde |
|---|---|---|
| Node.js 20 | 30/04/2026 (ya) | **30/10/2026** |
| Node.js 22 | 30/04/2027 | 31/10/2027 |
| Node.js 24 | 30/04/2028 | 31/10/2028 |

Una vez retirado, **Google no deja crear ni actualizar funciones con ese runtime**. Cualquier
corrección posterior al 30/10, por urgente que fuera, quedaría bloqueada.

**Qué se hace**

- Cambiar a `nodejs22` en `firebase.json`, en los dos flujos de GitHub y en `@types/node`.
- Pasar las 367 pruebas y desplegar a desarrollo. Una semana de uso real ahí y en QA, luego a
  producción.
- Se elige 22 y no 24 porque es el que las dependencias actuales ya soportan con seguridad.
  Subir a 24 se deja para el año que viene.

**Riesgo:** medio. El código no usa nada propio de Node 20, pero `web-push` y
`firebase-admin` dependen de criptografía nativa; por eso lleva la semana de observación.

**Fecha límite práctica:** en producción **antes del 20 de octubre**, para tener margen.

---

## 4. Mejoras de uso (iteración 1.6)

Todas son **solo de la aplicación**: no cambian datos ni reglas, salvo lo indicado en U-6 y
U-7. Cada una va en su propio PR.

### C-6 · Tocar una notificación abre lo que la originó · RF-ENT-07 · DT-35

**Es una corrección, y por eso va primero en la 1.6.** Reportada el 24/09/2026 probando en
QA: **en iPhone**, la notificación de una **respuesta** abre la bandeja en «Sin leer», y no la
respuesta ni el aviso respondido. En Android funciona.

Probablemente Android solo **trae la app al frente donde estaba**: el intento de navegar del
worker falla sin decir nada, porque no controla la ventana. Si ya se estaba en el aviso,
parece correcto. Antes de corregir se confirma en Android con la app cerrada desde recientes
(DT-35).

**La causa son dos fallos** (detalle en DT-35):

1. La notificación de una respuesta **no lleva el identificador del aviso**, así que el
   worker no sabe a dónde ir.
2. **La aplicación nunca lee la dirección con la que se abre.** Afecta también a los avisos
   normales, aunque ahí no se nota porque el aviso nuevo sale arriba de «Sin leer».

**Qué hace cada notificación al tocarla, después de corregirla:**

| Notificación | A quién le llega | Se abre en |
|---|---|---|
| Aviso nuevo | Catedrático | El detalle de **ese aviso** |
| Respuesta de un catedrático | Quien envió el aviso | **Respuestas**, con ese aviso desplegado |
| Respuesta de quien envió el aviso | Catedrático | **La conversación** dentro de ese aviso |
| Recordatorio del aparato, prueba | Cualquiera | La bandeja, como hoy |

**Cómo, sin romper nada**

- **Servidor:** añade `mensajeId` y el destino a la notificación de respuesta. Una
  aplicación vieja lo ignora.
- **Worker:** una decisión pura con sus pruebas. Con la app abierta, **la trae al frente sin
  recargarla** y le dice qué abrir. Sin la app abierta, la abre con el destino como
  parámetro de la dirección.
- **Aplicación:** lee ese parámetro al arrancar y escucha el aviso del worker mientras está
  abierta.

**Riesgo:** medio. Toca el worker, que es lo que entrega las notificaciones. Por eso lleva
pruebas de la decisión, y el guion en iPhone y Android con la app cerrada, en segundo plano y
abierta.

### U-1 · Copiar el título o el mensaje · RF-MSG-15

**Hoy.** El cuerpo del aviso se muestra con `Text`, que no se puede seleccionar. Las
respuestas sí usan `SelectableText`.

**Propuesta**

- Título y cuerpo seleccionables en el detalle del aviso.
- Un botón **Copiar** que copia «título + mensaje» y lo confirma con un aviso breve.

El botón es lo que de verdad funciona en un iPhone: seleccionar texto dentro de una PWA
instalada es incómodo.

**Pruebas.** De widget: el botón pone en el portapapeles exactamente el título y el mensaje.

### U-2 · Enlaces que se abren al tocarlos · RF-MSG-16

**Propuesta**

- Detectar `http://`, `https://` y `www.` en el cuerpo, y en la vista previa del emisor.
  Mostrarlos subrayados; al tocarlos se abren en otra pestaña.
- **Seguridad:**
  - Solo se abren `http` y `https`, nunca `javascript:` ni `data:`.
  - Se abre sin darle acceso a SIAN a la página destino (`noopener`).
  - El enlace se ve completo: quien lo toca sabe a dónde va.
- Sin dependencia nueva: se usa el mismo patrón de `core/plataforma/*_web.dart` que ya tiene
  el proyecto.
- **Opcional**, a decidir: correos (`mailto:`) y teléfonos (`tel:`) tocables.

**Pruebas.** Unitarias del detector con casos límite:
- punto o paréntesis al final de la URL;
- URL dentro de un texto con tildes;
- «www.» sin protocolo;
- un `javascript:` que **no** debe hacerse enlace.

**Límite.** En la notificación del sistema los enlaces no se pueden tocar: eso lo decide el
teléfono.

### U-3 · Descargar las imágenes · RF-MSG-17

**Hoy.** La imagen se abre ampliada en un diálogo (`InteractiveViewer`), sin forma de
guardarla.

**Propuesta.** Un botón **Descargar** en ese diálogo. Hay dos caminos, porque los teléfonos se
comportan distinto:

- **Android y computadora:** se baja la imagen y se guarda como archivo. El bucket ya tiene
  CORS configurado (`scripts/aplicar-cors-storage.sh`); hay que verificar que permita la
  lectura desde los tres dominios.
- **iPhone con la app instalada:** iOS no respeta la descarga directa dentro de una PWA. Se
  usa el menú de compartir de iOS (Web Share con el archivo), que ofrece **«Guardar
  imagen»**. Es el comportamiento nativo del iPhone.

**Pruebas.** De widget para el botón. En aparatos reales: iPhone, Android y computadora, en
el guion del documento 09.

### U-4 · El tabulador recorre el formulario en orden · RNF-23

**Hoy.** El formulario de redactar tiene, en este orden:

título → mensaje → cuándo enviarlo → adjuntos → tipo de aviso → destinatarios → confirmación
de lectura → Enviar.

Ninguno declara un orden de foco. Flutter lo deduce de la posición en pantalla, y los
componentes compuestos (el programador, los adjuntos, las casillas de grupos) lo alteran.

**Propuesta**

- **Primero, una prueba que reproduzca el fallo:** simula pulsar Tab y comprueba en qué campo
  cae el foco en cada paso. Sin esa prueba, el arreglo no demuestra nada.
- Después, envolver el formulario con un orden explícito (`FocusTraversalGroup` con
  `OrderedTraversalPolicy`) y numerar cada bloque. Mayús+Tab recorre al revés.
- La misma prueba se aplica a los otros formularios (usuarios y grupos), porque probablemente
  tienen el mismo problema.

### U-5 · El manual sigue el modo claro u oscuro · RNF-24

**Hoy.** Los tres documentos (manual de coordinación, guía del catedrático y notas de la
versión) tienen colores fijos claros. Además, **copian el mismo bloque de estilos tres
veces**.

**Propuesta**

- Sacar los estilos a **un solo archivo** (`manuales/estilo.css`), y definir los colores como
  variables para claro y oscuro.
- **Respetar la elección hecha en la app, no solo la del teléfono.** El manual se sirve desde
  el mismo dominio que la app, así que puede leer la preferencia que la app ya guarda
  (`sian.apariencia`: sistema, claro u oscuro):
  - Si en SIAN se eligió oscuro, el manual se abre oscuro aunque el teléfono esté en claro.
  - Si es «sistema», sigue al teléfono (`prefers-color-scheme`).
- Un pequeño guion al principio del documento aplica el tema **antes de pintar**, para que no
  se vea un parpadeo blanco.
- Los colores oscuros se miden contra AA, igual que se hizo con la paleta de la app (DT-21).

**Pruebas.** Una prueba que exija que los dos temas definan las mismas variables. Revisión
visual en el navegador, con teléfono y computadora.

### U-6 · Enviar a personas concretas (1 a n) · RF-USR-06

**Hoy.** Esto **ya es un requisito aprobado** (RF-USR-06: «todos, uno o más grupos, o una
selección individual»), y **el servidor ya lo soporta completo**:
- el modo `INDIVIDUAL` existe en el modelo;
- `resolverDestinatarios` lo resuelve;
- `mensaje.ts` lo valida (exige al menos una persona);
- Entregas y Programación ya lo muestran.

**Lo único que falta es la pantalla**: redactar solo ofrece «todos» o «grupos».

**Propuesta**

- Un tercer modo, **Personas**, con un buscador por nombre o correo y la selección como
  fichas que se pueden quitar.
- Solo aparecen personas **activas que reciben avisos**.
- La confirmación antes de enviar dice **los nombres**, no solo «3 personas»: en un envío
  individual, equivocarse de persona es el error caro.
- **Fase siguiente, opcional:** combinar grupos y personas en un mismo envío («Grupo 5.º
  semestre + Luis Alvarado»). Exige un cambio pequeño en el servidor (unir las dos listas sin
  duplicados), así que va después.

**Riesgo:** bajo, porque el servidor y la bitácora ya lo cubren.

**Pruebas.** De widget para el selector y la confirmación. Del dominio ya existen.

### U-7 · Mejoras de Alcance

Salen de lo que se hizo **a mano** en producción el 16/09: borrar nueve registros viejos con
guiones propios. Eso debería poder hacerlo la coordinación, con registro en bitácora.

| Mejora | Qué resuelve |
|---|---|
| **a. Retirar un aparato desde Alcance.** Botón «Retirar este registro» con confirmación, anotado en la bitácora con quién y por qué | Lo que hoy exige pedírselo al desarrollador |
| **b. La sonda diaria retira sola los registros reemplazados** (misma plataforma y navegador que un aparato ya actualizado, sin actividad en 14 días) | Registros viejos que hoy tardan 60 días en irse |
| **c. «Enviar recordatorio a estas N personas»** desde la lista de atrasados: abre redactar en modo Personas con ellas ya elegidas | Depende de U-6. Es exactamente lo que se hizo con el recordatorio de 1.5.11 |
| **d. Guardar en memoria la validación de tokens** unos minutos | Hoy cada visita a Alcance valida todos los tokens contra FCM. Con varias sedes serán muchos más |

**Pruebas.** Del dominio para el criterio de reemplazo (ya existe la base en
`clasificarVersiones`), de reglas para que solo coordinación pueda retirar, y de la sonda.

---

## 5. Rendimiento, estabilidad y seguridad

Salen de revisar el código y los registros de producción, no de una lista genérica.

| # | Qué | Por qué | Cuándo |
|---|-----|---------|:---:|
| **S-1** | **Node.js 22** | Ver sección 3 | **1.5.13** |
| **S-2** | **Respaldos programados de Firestore en producción** | Hoy no hay. Es requisito previo a la migración de sedes | **1.5.13** |
| **S-3** | **Verificar presupuestos y alertas de facturación** en los tres proyectos | Los tres están en Blaze. Antes del repositorio, que añade Storage, tiene que haber un aviso si el gasto pasa de un umbral | **1.5.13** |
| **S-4** | **App Check** (DT-33) | Los registros de producción dicen `"app": "MISSING"` en cada llamada: cualquiera con la configuración pública del proyecto puede llamar a las funciones fuera de la app. Se enciende primero **en modo observación** (solo mide), y cuando todas las llamadas legítimas lo traigan, se exige | 1.6 |
| **S-5** | **Fallos del cliente que nadie ve** (DT-34) | El 12/09 el registro de dispositivos se colgó en todos los aparatos y **el servidor no registró ni un error**: se supo porque un aviso no llegó. Propuesta: un punto de reporte mínimo (qué falló, versión, plataforma; nada personal), con límite de frecuencia, y un contador visible en Alcance | 1.6 |
| S-6 | **Adjuntos legibles por cualquier usuario activo** (DT-04, ya registrada) | La regla de Storage deja a cualquier catedrático activo leer cualquier adjunto si conoce la ruta. El riesgo es bajo, porque las rutas son aleatorias, pero el repositorio **no puede heredar esto**. Se corrige con el mismo mecanismo que el repositorio (sección 7) | 2.1 |
| S-7 | **Carga inicial para catedráticos** | El paquete de la app incluye todo el panel de administración, que un catedrático nunca abre. Medir primero el tamaño y el tiempo de carga en un iPhone real; si vale la pena, cargar el panel solo cuando se abre (carga diferida) | 1.6, si la medición lo justifica |
| S-8 | **Actualización de dependencias mensual** | Hoy se actualizan cuando algo falla. Un PR mensual automático, con la CI decidiendo | 1.6 |
| S-9 | **Procedimiento para rotar las llaves VAPID** | Si una privada se filtrara, hoy no hay pasos escritos para cambiarla sin dejar a los aparatos sin canal. Solo documentación | 1.6 |

---

## 6. Varias sedes (iteración 2.0) · ADR-009

Resumen aquí; el análisis completo, con alternativas, está en
[ADR-009](adr/ADR-009-multisede.md).

**Qué pide.** SIAN nació para la sede Boca del Monte. Puede crecer a otras sedes, y una
persona puede pertenecer a más de una.

**Decisión propuesta:** **un solo proyecto con los datos separados por sede**, no un proyecto
por sede. Con proyectos separados, quien está en dos sedes tendría dos cuentas y dos
aplicaciones instaladas; y cada sede nueva exigiría montar otra vez todo lo que costó una
semana (llaves, secretos, alertas, CI).

**El modelo**

- **`sedes/{sedeId}`** — nombre y si está activa. La actual sería `bdm`.
- **La persona pertenece a sedes con un rol en cada una.** Por ejemplo, coordinadora en Boca
  del Monte y catedrática en otra. En el perfil: `membresias: { bdm: 'COORDINADOR', otra:
  'CATEDRATICO' }`.
- **Las membresías viajan en el token de sesión**, igual que hoy el rol. Así las reglas deciden
  sin leer Firestore: no cuesta lecturas y no hace más lenta cada consulta. El token admite
  unos 1000 bytes, y alcanza para bastantes sedes.
- **Mensajes, grupos, bitácora y (luego) carpetas llevan `sedeId`.** «Enviar a todos» pasa a
  significar «todos los de esta sede».
- **Un selector de sede** en la barra, que solo aparece si la persona tiene más de una. La
  bandeja del catedrático puede mostrar los avisos de todas sus sedes juntos, con una etiqueta
  de sede.
- **Un rol nuevo, administración general**, que crea sedes y asigna a sus coordinadores. Nadie
  más puede.

**Migración sin romper nada** (ampliar y después contraer, sección 2):

| Paso | Qué | La app vieja… |
|---|---|---|
| 1 | Respaldo de producción (S-2) | — |
| 2 | El servidor acepta `sedeId`; si no viene, usa la única sede de la persona | sigue funcionando |
| 3 | Guion idempotente: `sedeId = 'bdm'` en todo lo existente y `membresias` en cada perfil | sigue funcionando |
| 4 | App con selector de sede, que se oculta con una sola sede. **Nadie nota nada** | sigue funcionando |
| 5 | Verificar que no queda nada sin `sedeId` | — |
| 6 | Las reglas empiezan a exigir la sede | ya actualizó |
| 7 | Se da de alta la segunda sede | — |

**Pruebas.** Reglas: una persona de la sede A **no** ve nada de la B, ni avisos, ni grupos,
ni bitácora. Dominio: «todos» resuelve solo dentro de la sede. Migración: correr el guion dos
veces deja lo mismo.

**Por qué va antes que el repositorio.** Las carpetas y los grupos con acceso pertenecen a una
sede. Si el repositorio se hace primero, hay que migrarlo después. Si el repositorio fuera más
urgente, se puede adelantar **siempre que nazca con `sedeId`**, y la migración de sedes ya no
lo tocaría.

---

## 7. Repositorio de archivos (iteraciones 2.1 y 2.2) · ADR-010

Resumen aquí; el análisis completo en [ADR-010](adr/ADR-010-repositorio-archivos.md).

**¿Es posible con lo que tenemos, y sin disparar costos?** **Sí.** Se comprobó el 23/09:

- El bucket de producción está en **`us-central1`**, una de las tres regiones con cuota
  gratuita de Storage en el plan Blaze: **5 GB guardados, 100 GB de descarga al mes, 5 000
  subidas y 50 000 descargas al mes**.
- Hoy los adjuntos de producción ocupan **1.5 MB**.
- **Ejemplo:** 40 personas, 1 GB de archivos, y cada una descargando 100 MB al mes son unos
  4 GB de descarga mensual. Todo queda dentro de la cuota, a costo cero.

Para que nunca se salga de ahí:
- **límite por archivo: 25 MB**;
- **cupo por sede: 2 GB**, configurable;
- el cupo se controla en el servidor, que rechaza la subida que lo pasaría;
- **alerta de presupuesto** (S-3) como red de seguridad.

**El modelo**

- `sedes/{s}/carpetas/{c}` — nombre, carpeta madre (hasta dos niveles), **grupos con acceso**,
  bytes usados.
- `sedes/{s}/carpetas/{c}/archivos/{a}` — nombre, tamaño, tipo, quién lo subió y cuándo.
- El archivo en Storage: `repositorio/{sede}/{carpeta}/{archivo}`.

**Quién puede qué**

| | Coordinación / administración | Catedrático |
|---|---|---|
| Crear, renombrar o borrar carpetas | Sí | No |
| Dar o quitar acceso a grupos | Sí | No |
| Subir y borrar archivos | Sí | No |
| Ver y descargar | Todo lo de su sede | **Solo las carpetas de sus grupos** (2.2) |

**Tipos permitidos:** PDF, Word, Excel, PowerPoint, imágenes y texto. **No** ejecutables ni
comprimidos: nadie escanea virus, así que no se aceptan formatos que puedan esconderlos.

**Cómo se controla la descarga.** Es la decisión más importante del repositorio:

- **Recomendado: una función entrega un enlace temporal (10 minutos).** Comprueba en el
  servidor que la persona está en un grupo con acceso y le da un enlace firmado que caduca.
  - A favor: la lógica queda en código probado; cada descarga queda en la bitácora; quitar el
    acceso a un grupo surte efecto de inmediato.
  - En contra: hay que dar a la cuenta de funciones permiso para firmar.
- **Alternativa: reglas de Storage que consultan Firestore.** Cada descarga cuesta lecturas
  de Firestore, hay un máximo de dos documentos por evaluación, y la lógica de «¿está en
  alguno de estos grupos?» queda en reglas, que son más difíciles de probar.

El mismo mecanismo recomendado **cierra DT-04** para los adjuntos de los avisos.

**Por fases**

- **2.1 · Administración:** carpetas, subir, borrar, dar acceso a grupos, ver el cupo usado.
  Nadie más lo ve todavía.
- **2.2 · Catedrático:** una sección **Archivos** con solo sus carpetas, y descarga. Opcional:
  un aviso automático «nuevo archivo en tu carpeta X».

**Pruebas.** Reglas: un catedrático no puede subir, no puede listar carpetas ajenas y no puede
descargar sin enlace. Dominio: el cupo, los tipos y el acceso por grupo. De punta a punta en
QA: subir un PDF, verlo como catedrático del grupo, **no** verlo como catedrático de otro
grupo.

---

## 8. Otras propuestas

| Propuesta | Por qué |
|---|---|
| **Mensajes de hasta 1000 caracteres** (hoy 500) | El aviso de actualización de 1.5.11 no cupo a la primera. Se puede ampliar sin riesgo si la **notificación** lleva un resumen (primeros ~250 caracteres) y la **bandeja** el texto completo: así la carga del push sigue lejos del límite de 4 KB |
| **Plantillas de avisos** (RF-MSG-14, ya en la cartera) | Los recordatorios de actualizar y responder son siempre parecidos |
| **Recordatorio automático a quien no confirma** (RF-CNF-09, ya en la cartera) | Combina con U-7c |
| **Canal de respaldo por SMS o WhatsApp** | Aplazado por decisión del responsable. Sigue siendo lo único que cubre a quien no abre la app; se retoma cuando se decida |

---

## 9. Orden recomendado

```
1.5.13  ── urgente, antes del 20/10 ──  Node 22 · respaldos · presupuestos
   │
1.6.x   ── mejoras de uso ──  C-6 la notificación abre lo que la originó (primero: corrección)
   │                          U-1 copiar · U-2 enlaces · U-4 tabulador · U-5 manual oscuro
   │                          U-3 descargar · U-6 personas · U-7 Alcance
   │                          S-4 App Check (observación) · S-5 fallos del cliente · S-8 · S-9
   │
2.0.x   ── sedes ──  migración en dos tiempos, detrás de un interruptor
   │
2.1.x   ── repositorio: administración ──
   │
2.2.x   ── repositorio: catedrático ──  (cierra DT-04)
```

**Por qué este orden**

1. **Lo que tiene fecha va primero.** Sin Node 22 no se puede desplegar nada después del
   30/10.
2. **Lo pequeño y visible va antes que lo grande.** La 1.6 da mejoras que la gente nota en
   días, y no toca datos.
3. **Las sedes van antes que el repositorio,** para no migrar dos veces.
4. **Cada paso deja el sistema funcionando.** Nada de lo anterior depende de que lo siguiente
   se termine.

---

## 10. Decisiones (aprobadas el 23/09/2026)

El responsable aprobó todas las recomendaciones:

- **Numeración:** 1.5.13 → 1.6 → 2.0 → 2.1 / 2.2.
- **Un rol por sede:** una persona puede ser coordinadora en una sede y catedrática en otra.
- **Descargas del repositorio por enlace temporal** (10 minutos), con registro en la bitácora.
- **Límites del repositorio:** 25 MB por archivo y 2 GB por sede.
- **Mensajes de hasta 1000 caracteres**, con resumen en la notificación.
- **Correos y teléfonos tocables**, además de las direcciones web.

Lo que se preguntaba, para referencia:

1. **La numeración** (sección 1): 1.5.13 / 1.6 / 2.0 / 2.1, o dejarlo todo en 1.5.x.
2. **Roles por sede** (sección 6): ¿una persona puede ser coordinadora en una sede y
   catedrática en otra, o su rol es el mismo en todas?
3. **Descargas del repositorio** (sección 7): enlace temporal (recomendado) o reglas de
   Storage.
4. **Límites del repositorio:** 25 MB por archivo y 2 GB por sede, o los que se prefieran.
5. **Mensajes de 1000 caracteres:** sí o no.
6. **Correos y teléfonos tocables** en U-2: sí o no.

---

## Fuentes consultadas

- Calendario de runtimes de Cloud Run functions: <https://docs.cloud.google.com/functions/docs/runtime-support>
- Precios de Firebase (cuota gratuita de Storage por región): <https://firebase.google.com/pricing>
- Reglas de Storage que consultan Firestore (costo y límite de dos documentos): <https://firebase.google.com/docs/storage/security/rules-conditions>
