# 14 · Análisis: facultades, catálogos, caja chica y encuestas

**Estado:** **aprobado** por el responsable el 6 de noviembre de 2026, con las diez decisiones
de la sección 7 resueltas y el orden de la sección 6, que fija las versiones 2.0 a 2.5

**Qué es este documento.** Recoge lo que pidió el responsable el 06/11/2026 y lo analiza
**antes** de escribir código: qué se pidió, cómo encaja con lo que ya existe, qué modelo de
datos y qué permisos tendría, qué riesgos trae, qué decisiones faltan y en qué orden
conviene hacerlo. Nada de esto está implementado. El estado de cada requisito se lleva en la
[cartera (documento 13)](13-cartera-de-incrementos.md) y los requisitos propuestos están en el
documento 01, sección 3.10.

---

## 1. Lo que se pidió

1. **Facultades**, dentro del manejo de sedes.
2. **Mantenimiento de todos los catálogos** de la aplicación: altas, cambios y bajas.
3. **Caja chica**:
   - una carga inicial con el monto con que se abre;
   - un kárdex de entradas y salidas;
   - catálogos de tipos de entrada y de tipos de salida, con un motivo u observación en
     cada movimiento;
   - entradas por donaciones y por aportes de catedráticos (quien registra el ingreso elige al
     catedrático, el movimiento entra al kárdex y queda el aporte acumulado de cada uno);
   - salidas categorizadas: publicidad, pastel, almuerzos, convivios y las que se agreguen;
   - permiso para registrar movimientos a uno o varios catedráticos;
   - que todos los catedráticos puedan ver los fondos de la caja.
4. **Encuestas.**
5. **Ordenar todo** lo pendiente con prioridades, en un documento de control, para que nada
   se pierda aunque pase mucho tiempo antes de desarrollarlo.

---

## 2. Facultades (va con la 2.0)

**Cómo encaja.** La 2.0 ya separa los datos por sede (documento 12, sección 6; ADR-009). Una
facultad es una subdivisión de la sede. Si se agrega **en la misma migración** que la sede, los
datos se migran una sola vez; si se deja para después, habría que volver a migrar avisos,
grupos y, más tarde, carpetas y cajas.

**Modelo propuesto**

- `sedes/{sedeId}/facultades/{facultadId}` — nombre, siglas, activa.
- En el perfil de la persona, dentro de su membresía de sede: las facultades a las que
  pertenece (`membresias.bdm.facultades: ['ing', 'cce']`).
- Los grupos pueden pertenecer a una facultad. Los avisos pueden dirigirse a **toda una
  facultad**, además de a toda la sede, a grupos o a personas.
- La facultad es **opcional**: con una sola facultad o ninguna, la aplicación no la muestra
  (mismo criterio que el selector de sede).

**Requisitos propuestos**

| ID | Requisito |
|---|---|
| RF-FAC-01 | Cada sede puede tener facultades; una persona pertenece a una o varias facultades de su sede |
| RF-FAC-02 | Un aviso puede dirigirse a toda una facultad |
| RF-FAC-03 | Los grupos pueden pertenecer a una facultad, y se filtran por ella |
| RF-FAC-04 | Con una sola facultad o ninguna, la aplicación no pregunta ni muestra la facultad |
| RF-FAC-05 | Los reportes (Alcance, Respuestas, caja chica) se pueden filtrar por facultad |

**Decisiones**

1. ¿Una persona puede estar en más de una facultad? — **resuelta: sí.**
2. ¿La facultad tiene coordinación propia, o la coordina la sede? — *sin preguntar todavía*;
   se diseña con la coordinación de la sede y se revisa al hacer la 2.0
3. ¿Qué facultades hay hoy en Boca del Monte? — **resuelta el 06/11/2026: por ahora solo
   Ingeniería en Sistemas.** Habrá más; el catálogo de facultades permite agregarlas sin código.

---

## 3. Mantenimiento de catálogos

**Qué es un catálogo aquí.** Una lista que la coordinación define y que el resto de la
aplicación usa para elegir. Hoy existen grupos y plantillas; con lo pedido se suman:

| Catálogo | Lo mantiene | Se usa en |
|---|---|---|
| Sedes | Administración general | Todo (2.0) |
| Facultades | Coordinación de la sede | Avisos, grupos, reportes |
| Grupos (ya existe) | Coordinación y administración | Avisos, repositorio |
| Plantillas (ya existe) | Quien emite avisos | Redactar |
| Tipos de entrada de caja | Coordinación | Caja chica |
| Tipos de salida de caja | Coordinación | Caja chica |
| Cajas chicas | Coordinación | Caja chica |

**Reglas comunes para todos los catálogos**

- Una pantalla de mantenimiento con el mismo patrón para todos: lista con buscador, crear,
  editar, activar y desactivar. Un solo componente reutilizable, para que todos se comporten
  igual (consistencia, heurística de Nielsen).
- **No se borra lo que está en uso.** Un tipo de salida con movimientos se **desactiva**: deja
  de ofrecerse, pero los movimientos viejos siguen mostrando su nombre. Borrar solo se permite
  si nadie lo usó.
- Cada cambio queda en la bitácora.
- Los nombres no se repiten dentro del mismo catálogo y la misma sede.

**Requisitos propuestos**

| ID | Requisito |
|---|---|
| RF-CAT-01 | Cada catálogo tiene una pantalla de mantenimiento con buscador, alta, edición y activar/desactivar |
| RF-CAT-02 | Un elemento en uso no se borra: se desactiva y se conserva su nombre en lo ya registrado |
| RF-CAT-03 | No se aceptan nombres repetidos dentro del mismo catálogo y sede |
| RF-CAT-04 | Cada alta, cambio o baja de un catálogo queda en la bitácora |
| RF-CAT-05 | Solo el rol indicado en la tabla de arriba mantiene cada catálogo; los demás solo lo usan |

---

## 4. Caja chica

### 4.1 Cómo funcionaría

- La coordinación **abre una caja** (por ejemplo, «Caja chica de catedráticos BDM»), elige a
  sus **operadores** (uno o varios catedráticos) y registra la **carga inicial**.
- Los operadores registran **entradas** y **salidas**. Cada movimiento lleva: fecha, tipo
  (del catálogo), monto, motivo u observación y, si el tipo es «Aporte de catedrático», **el
  catedrático que aportó**.
- El **kárdex** es la lista de movimientos en orden, cada uno con el **saldo después del
  movimiento**, como una libreta.
- **Hay una caja por sede y facultad** (decisión del 06/11/2026). Con Ingeniería en Sistemas
  como única facultad, Boca del Monte empieza con una sola caja.
- Todos los catedráticos de esa sede y facultad ven **solo el saldo**. El kárdex completo y los
  aportes de todos los ven **solo los encargados** de la caja (sus operadores). Cada
  catedrático ve **sus propios aportes**.

### 4.2 Catálogos de tipos (valores iniciales sugeridos)

| Entradas | Salidas |
|---|---|
| Carga inicial | Publicidad |
| Donación | Compra de pastel |
| Aporte de catedrático (pide elegir al catedrático y si es cuota periódica, eventual o libre) | Compra de almuerzos |
| Otro ingreso | Convivios |
| | Otro egreso |

Cada tipo indica si **exige catedrático** (los aportes) y si **exige observación** (los
«Otro»). La coordinación agrega más con el mantenimiento de catálogos.

### 4.3 Modelo propuesto

- `sedes/{s}/cajas/{facultadId}` — una por facultad; nombre, facultad, moneda (`GTQ`), **operadores**
  (UIDs), saldo en centavos, número del último movimiento, activa.
- `sedes/{s}/cajas/{c}/movimientos/{m}` — número correlativo, fecha, clase (`ENTRADA` o
  `SALIDA`), tipo, **monto en centavos** (entero, para no arrastrar errores de redondeo),
  catedrático (en aportes), observación, quién lo registró y cuándo, **saldo después**, y si
  anula a otro movimiento, cuál.
- `sedes/{s}/catalogos/tiposCaja/{t}` — nombre, clase, exige catedrático, exige observación,
  activo.

### 4.4 Lo que protege el dinero

Es lo más delicado de todo lo pedido, porque un error aquí no se nota en una pantalla: se
nota en un saldo que no cuadra.

- **El saldo lo calcula el servidor**, nunca la aplicación: una función registra el
  movimiento y actualiza el saldo **en la misma transacción**. Dos operadores registrando a la
  vez no pueden dejar un saldo equivocado.
- **Ninguna salida deja el saldo en negativo**; el servidor la rechaza con un mensaje claro.
- **Los movimientos no se editan ni se borran.** Un error se corrige con una **anulación**: un
  movimiento nuevo, de sentido contrario, que dice a cuál anula y por qué. El kárdex muestra
  los dos. Así cualquiera puede reconstruir el saldo desde la carga inicial.
- Las reglas de Firestore **no dejan escribir** movimientos desde el cliente; solo la función,
  que comprueba que quien registra sea operador de esa caja.
- Cada movimiento y cada cambio de operadores queda en la bitácora.
- Pruebas: dominio (saldo, anulación, saldo negativo, tipos que exigen catedrático), reglas
  contra el emulador (nadie escribe movimientos, un catedrático de otra sede no ve la caja) y
  una prueba de concurrencia (dos movimientos simultáneos).

### 4.5 Requisitos propuestos

| ID | Requisito |
|---|---|
| RF-CCH-01 | La coordinación crea la caja chica de cada sede y facultad y registra su carga inicial |
| RF-CCH-02 | La coordinación asigna uno o varios catedráticos como operadores de una caja |
| RF-CCH-03 | Solo los operadores registran entradas y salidas |
| RF-CCH-04 | Cada movimiento lleva fecha, tipo, monto, observación y quién lo registró |
| RF-CCH-05 | Los tipos de entrada y de salida son catálogos que mantiene la coordinación |
| RF-CCH-06 | Un aporte de catedrático exige elegir al catedrático y entra al kárdex |
| RF-CCH-07 | El kárdex muestra los movimientos en orden con el saldo después de cada uno |
| RF-CCH-08 | El saldo lo calcula el servidor, en la misma transacción que el movimiento |
| RF-CCH-09 | Ninguna salida puede dejar el saldo en negativo |
| RF-CCH-10 | Los movimientos no se editan ni se borran; un error se corrige con una anulación que indica el motivo |
| RF-CCH-11 | Todos los catedráticos de la sede y facultad ven **solo el saldo** de la caja; el kárdex lo ven solo los encargados |
| RF-CCH-12 | Reporte de aportes acumulados por catedrático (solo los encargados) |
| RF-CCH-13 | Reporte por rango de fechas y totales por tipo de entrada y de salida |
| RF-CCH-14 | Exportar el kárdex a CSV (solo los encargados) |
| RF-CCH-15 | Cada catedrático ve sus propios aportes; solo los encargados ven los de todos |
| RF-CCH-16 | Un aporte puede ser periódico (cuota con monto y frecuencia que definen los encargados), eventual o de monto libre |
| RF-CCH-17 | Para las cuotas periódicas, cada catedrático ve si está al día y los encargados ven quién tiene cuotas pendientes |

### 4.6 Decisiones

1. ¿Cuántas cajas? — **resuelta: una por sede y facultad.**
2. ¿Qué ven los catedráticos? — **resuelta: solo el saldo.**
3. ¿De quién ven los aportes? — **resuelta: cada uno los suyos; solo los encargados de la
   caja ven los de todos.**
4. ¿Cómo son los aportes? — **resuelta: los tres tipos.** Periódicos (una cuota con
   frecuencia, y se ve quién está al día), eventuales (una sola vez) y de monto variable o
   libre. Requisitos RF-CCH-16 y RF-CCH-17.
5. ¿Las salidas llevan **foto del comprobante**? — **resuelta: no.**
6. ¿Una salida grande necesita **aprobación** de una segunda persona? — **resuelta: no.**
7. ¿Solo quetzales? — *pendiente* (se propone que sí)

---

## 5. Encuestas

**Cómo encaja.** Una encuesta se parece a un aviso: tiene destinatarios (toda la sede,
facultad, grupos o personas), llega por notificación y se sabe quién la respondió, igual que
hoy se sabe quién confirmó. Por eso **reutiliza el envío, la entrega y el Alcance** que ya
funcionan, y no hace falta construir un canal nuevo.

**Modelo propuesto**

- `encuestas/{e}` — título, instrucciones, preguntas, destinatarios, fecha de cierre,
  **anónima o con nombre**, quién la creó.
- Preguntas de tipo opción única, opción múltiple, escala de 1 a 5 y texto corto.
- `encuestas/{e}/respuestas/{r}` — las respuestas. En una encuesta **anónima** la respuesta
  no lleva el UID: una colección aparte, `participaciones/{uid}`, solo dice que esa persona
  ya respondió (para que no responda dos veces y para el recordatorio) sin unir quién dijo qué.
- Los resultados se ven sumados (cuántos eligieron cada opción, promedio de la escala) y se
  pueden exportar a CSV.

**Requisitos propuestos**

| ID | Requisito |
|---|---|
| RF-ENC-01 | Quienes pueden emitir avisos (coordinación y administración) crean encuestas con preguntas de opción única, opción múltiple, escala y texto corto |
| RF-ENC-02 | Una encuesta se envía con los mismos destinatarios que un aviso, y llega por notificación |
| RF-ENC-03 | Cada persona responde una sola vez, hasta la fecha de cierre |
| RF-ENC-04 | Una encuesta puede ser anónima: nadie, ni la coordinación, puede saber quién dio qué respuesta |
| RF-ENC-05 | Los resultados se muestran sumados por pregunta, solo a quienes pueden emitir avisos |
| RF-ENC-06 | Se ve quién respondió y quién no (en las anónimas, solo si participó, no qué respondió) |
| RF-ENC-07 | Recordatorio a quien no respondió, con el mismo mecanismo propuesto en RF-CNF-09 |
| RF-ENC-08 | Los resultados se exportan a CSV |

**Decisiones**

1. ¿Quién crea encuestas? — **resuelta: los mismos que pueden emitir avisos.**
2. ¿Quién ve los resultados? — **resuelta: los mismos que pueden emitir avisos.**
3. ¿Se necesitan otros tipos de pregunta (fecha, número)? — *pendiente*

---

## 6. Orden recomendado y por qué

Criterios, en este orden: (1) las correcciones antes que lo nuevo; (2) lo que es base de otras
cosas va primero, para no migrar dos veces; (3) lo que maneja dinero se hace con la mayor
prueba y sin prisa; (4) a igual base, primero lo que más se usa y menos alternativas tiene hoy.

| Paso | Versión | Qué | Por qué en este lugar |
|:---:|:---:|---|---|
| 1 | 1.6.20 | **DT-35** · abrir la respuesta en iPhone | Es una corrección y es pequeña |
| — | — | **OPS-1 y OPS-2** · personas sin canal, aparatos viejos | No es código; se hace en paralelo y desbloquea App Check |
| 2 | **2.0** | **Sedes + facultades + mantenimiento de catálogos de sedes y facultades** | Todo lo demás cuelga de la sede y la facultad. Juntas son **una sola migración** |
| 3 | **2.1** | **Caja chica, base** · caja por sede y facultad, encargados, catálogos de tipos, carga inicial, aportes (periódicos, eventuales, libres), kárdex, saldo visible (RF-CCH-01 a 11, 15 y 16) | Maneja dinero real y hoy no tiene trazabilidad dentro de SIAN; no depende del repositorio |
| 4 | **2.2** | **Caja chica, reportes** · aportes por catedrático, cuotas al día, rangos, totales, CSV (RF-CCH-12 a 14 y 17) | Se apoya en los movimientos ya registrados; separarla deja la base en uso antes |
| 5 | **2.3** | **Encuestas** (RF-ENC-01 a 08) | Reutiliza envío y Alcance; hoy se puede suplir con un formulario externo, por eso no va antes |
| 6 | **2.4** | **Repositorio: administración** (RF-REP-01 a 04 y 07) | Aprobado el 23/09; hoy se puede suplir con una carpeta compartida |
| 7 | **2.5** | **Repositorio: catedrático** (RF-REP-05 y 06; cierra DT-04) | Depende del paso 6 |
| — | — | **S-4** · exigir App Check | En cuanto OPS-2 llegue a cero, en cualquier punto |

**Lo que cambia respecto de lo aprobado el 23/09.** Allí el orden era 2.0 sedes → 2.1 y 2.2
repositorio. Esta recomendación **adelanta la caja chica y las encuestas** antes del
repositorio, porque el repositorio tiene hoy una alternativa sencilla (una carpeta
compartida) y la caja chica no. Si el responsable prefiere mantener el repositorio primero,
la caja chica y las encuestas van después sin ningún problema técnico: no dependen de él.
**El responsable aprobó este orden el 06/11/2026**: el repositorio pasa de 2.1 y 2.2 a 2.4 y 2.5.

**Costo.** Ninguna de estas funcionalidades sale de la cuota gratuita con el uso esperado:
son documentos pequeños (un movimiento de caja o una respuesta de encuesta pesan menos de
1 KB). La foto de comprobantes, si se aprueba, usaría la cuota de Storage ya analizada para el
repositorio.

---

## 7. Decisiones del responsable

Las diez se respondieron el 06/11/2026.

| # | Pregunta | Estado | Decisión |
|---|---|---|---|
| 1 | ¿Se aprueba el orden de la sección 6, o se mantiene el repositorio antes? | **Resuelta** | **Se aprueba el orden de la sección 6** |
| 2 | ¿Una persona puede estar en varias facultades? | **Resuelta** | **Sí** |
| 3 | ¿Qué facultades hay hoy en Boca del Monte? | **Resuelta** | Por ahora solo **Ingeniería en Sistemas**; habrá más |
| 4 | ¿Una caja por sede, por facultad o varias libres? | **Resuelta** | **Una por sede y facultad** |
| 5 | ¿Los catedráticos ven solo el saldo o también el kárdex? | **Resuelta** | **Solo el saldo** |
| 6 | ¿Cada catedrático ve los aportes de todos o solo los suyos? | **Resuelta** | **Los suyos**; solo los encargados de la caja ven todos |
| 7 | ¿Aportes con cuota fija o periódica? | **Resuelta** | **Periódicos, eventuales y de monto variable o libre** (RF-CCH-16 y 17) |
| 8 | ¿Foto del comprobante en las salidas? | **Resuelta** | **No** |
| 9 | ¿Aprobación de una segunda persona para salidas grandes? | **Resuelta** | **No** |
| 10 | ¿Quién crea encuestas y quién ve los resultados? | **Resuelta** | **Los mismos que pueden emitir avisos** (coordinación y administración) |
