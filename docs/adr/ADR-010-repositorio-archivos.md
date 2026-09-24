# ADR-010 · Repositorio de archivos con acceso por grupos y descarga por enlace temporal

**Estado:** Propuesta
**Fecha:** 23 de septiembre de 2026
**Decide:** responsable del proyecto

## Contexto

Se pide un repositorio de archivos:

- **Coordinación y administración** crean carpetas, suben archivos con límite de tamaño, y
  dan acceso a grupos carpeta por carpeta.
- **Después**, el catedrático descarga lo de las carpetas a las que tiene acceso.

Hay dos condiciones: que sea posible con lo que hay, y que no dispare costos.

**Lo que se comprobó el 23/09/2026**

- El bucket de producción (`sian-umg-bdm.firebasestorage.app`) está en **`us-central1`**, una
  de las tres regiones con cuota gratuita en Blaze: **5 GB guardados, 100 GB de descarga al
  mes, 5 000 subidas y 50 000 descargas al mes**.
- Hoy los adjuntos de producción ocupan **1.5 MB**.
- La regla de Storage de los adjuntos deja leer **a cualquier usuario activo** (DT-04). El
  repositorio no puede copiar ese criterio: las carpetas son justamente para que **no** todos
  vean todo.

## Opciones consideradas

**Cómo se autoriza la descarga**

| Opción | A favor | En contra |
|--------|---------|-----------|
| **A. Enlace firmado temporal, entregado por una función** | La comprobación de acceso («¿está en algún grupo de la carpeta?») queda en código de dominio probado. Cada descarga queda en la bitácora. Quitar el acceso surte efecto al instante. Storage queda cerrado a lecturas directas | Exige dar a la cuenta de funciones el permiso de firmar (`iam.serviceAccountTokenCreator` sobre sí misma). Cada descarga es una llamada a una función, dentro de la cuota gratuita |
| **B. Reglas de Storage que consultan Firestore** | Sin función intermedia | **Cada descarga cuesta lecturas de Firestore**, y como mucho **dos documentos por evaluación**. Comprobar «alguno de mis grupos está entre los de la carpeta» obliga a llevar los grupos en el token (y renovarlo en cada cambio) o a mantener una lista de personas por carpeta. La lógica queda en reglas, más difíciles de probar |
| **C. Grupos de la persona en el token + `hasAny` en las reglas** | Sin lecturas extra | El token se desactualiza al cambiar grupos. Hay un límite de ~1000 bytes que una persona con muchos grupos puede superar |

**Dónde se guardan los metadatos:** en Firestore, bajo la sede
(`sedes/{s}/carpetas/{c}/archivos/{a}`). La alternativa era leer los metadatos de Storage,
pero listar objetos no permite filtrar por acceso ni paginar bien.

## Decisión

- **Descarga: opción A.** Una función `enlaceDeArchivo` comprueba el acceso y devuelve un
  enlace firmado que caduca en 10 minutos.
- **Subida: directa a Storage.** La regla solo admite coordinación y administración de esa
  sede, tipos permitidos (PDF, Word, Excel, PowerPoint, imágenes y texto) y **25 MB** como
  máximo.
- **Un disparador de Storage** (al terminar la subida) hace tres cosas:
  1. registra los metadatos en Firestore;
  2. suma el tamaño al **cupo de la sede (2 GB)**;
  3. **borra el archivo** si con él se pasaría del cupo, y lo deja escrito en la bitácora.
- **No se aceptan ejecutables ni comprimidos.** No hay escaneo de virus en la plataforma sin
  costo, así que no se admiten formatos que puedan esconder uno.
- **El mismo mecanismo de descarga se aplica después a los adjuntos de los avisos**, y cierra
  DT-04.
- Todo nace con **`sedeId`** (ADR-009), aunque las sedes se implementen después.

## Consecuencias

- **Buenas:**
  - Costo previsto **cero**. Con 40 personas descargando 100 MB al mes cada una son ~4 GB,
    frente a una cuota de 100 GB.
  - El acceso por grupo se prueba en el dominio, igual que el resto.
  - Queda registro de quién descargó qué.
- **Malas:**
  - Hay un permiso de IAM nuevo que dar en cada ambiente. Es un paso manual del responsable,
    como las llaves VAPID.
  - Un enlace ya entregado sigue sirviendo hasta que caduca, 10 minutos como mucho, aunque se
    quite el acceso en ese momento.
- **Protección de costo:** el cupo por sede, el límite por archivo y la **alerta de
  presupuesto** del proyecto (documento 12, S-3), que tiene que existir antes de liberar.

## Requisitos relacionados

RF-REP-01 a RF-REP-07 (documento 01, sección 3.9) · DT-04 · ADR-009 · documento 12, sección 7.
