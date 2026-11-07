# ADR-009 · Varias sedes en un solo proyecto, con los datos separados por sede

**Estado:** Aceptada el 23 de septiembre de 2026 (implementación pendiente)
**Fecha:** 23 de septiembre de 2026
**Decide:** responsable del proyecto

## Contexto

SIAN nació para una sola sede, Boca del Monte, y nada en los datos lo dice: se da por hecho.
Se pide que pueda crecer a otras sedes, y que **una misma persona pueda pertenecer a más de
una**.

Fuerzas en juego:

- **Nada de lo que funciona puede romperse.** Hay 26 personas en producción, con aparatos
  registrados y la aplicación instalada. Algunos aparatos tardan días en actualizar.
- **Costo:** el proyecto vive dentro de las cuotas gratuitas, y así debe seguir.
- **Operación:** montar un ambiente costó días. Hubo que hacer llaves VAPID, secretos, CI,
  alertas, reglas y la lista blanca.
- **Hoy el rol va en el token de sesión** (`rol`, `activo`), y las reglas deciden con él sin
  leer Firestore.

## Opciones consideradas

| Opción | A favor | En contra |
|--------|---------|-----------|
| **A. Un proyecto de Firebase por sede** | Aislamiento total; cada sede se cae sola | Quien está en dos sedes tiene **dos cuentas y dos aplicaciones instaladas**. Cada sede nueva repite todo el montaje. Tres ambientes por sede. Los reportes entre sedes son imposibles |
| **B. Un proyecto, datos separados por `sedeId`, membresías en el token** | Una cuenta y una app para todo. Las reglas siguen sin leer Firestore. Una sede nueva es un documento | Las reglas y las consultas deben filtrar por sede **siempre**: un olvido mezcla datos. Exige una migración |
| **C. Un proyecto, sede como grupo especial** | Casi sin cambios | Mezcla dos conceptos. «Todos» dejaría de significar algo claro. No separa bitácora ni administración |

## Decisión

**Opción B.**

- **`sedes/{sedeId}`**: nombre y si está activa. La actual es `bdm`.
- **Membresías con rol por sede** en el perfil (`membresias: { bdm: 'COORDINADOR', otra:
  'CATEDRATICO' }`), copiadas al token de sesión por la función que ya fija el rol. El token
  admite unos 1000 bytes, suficientes para muchas sedes.
- **`sedeId` obligatorio** en mensajes, grupos, bitácora y carpetas. «Todos» significa todos
  los de la sede elegida.
- **Rol nuevo, administración general:** crea sedes y asigna a sus coordinadores.
- **El riesgo de «un olvido mezcla datos»** se ataca con tres defensas:
  1. **Reglas:** exigen que el `sedeId` del documento esté entre las sedes del token.
  2. **Dominio:** cada consulta del servidor recibe la sede como parámetro obligatorio, no
     opcional.
  3. **Pruebas de reglas:** una persona de la sede A intenta leer, escribir y listar cada
     colección de la B, y **debe fallar**.

**Migración en dos tiempos** (documento 12, sección 6): primero se amplía sin exigir, luego
se rellenan los datos con un guion idempotente, y al final se exige. Antes, un respaldo de
producción.

## Consecuencias

- **Buenas:**
  - Una sede nueva no cuesta infraestructura.
  - Una persona en dos sedes usa una sola app.
  - Los reportes por sede y globales son posibles.
- **Malas:**
  - Cada consulta y cada regla nuevas deben incluir la sede. Es una disciplina permanente, y
    por eso se prueba.
  - El cambio de membresía de una persona tarda en surtir efecto hasta que se renueva su
    token. Se fuerza la renovación, como ya se hace al cambiar el rol.
  - Mientras dure la migración conviven datos con y sin sede. Por eso el servidor asume la
    sede única de la persona cuando falta.
- **Deuda que genera:** ninguna prevista, si la migración se cierra (paso «contraer»).

## Plan de implementación (2.0, aprobado el 06/11/2026)

La 2.0 suma **facultades** dentro de la sede y el **mantenimiento de catálogos** (documento
14), en la misma migración. Se hace en seis pasos, cada uno en su propio PR y todos en
desarrollo; ninguno rompe lo anterior:

| Paso | Qué | Estado |
|---|---|---|
| 2.0-a | Membresías con rol por sede; `sedes` y `adminGeneral` en el token; todos los claims desde `claimsDe` | En dev (PR #231) |
| 2.0-b | Avisos, grupos y bitácora nuevos con `sedeId`; «todos» dentro de la sede; envío a una facultad; Alcance, grupos y usuarios por sede | En dev (PR #232) |
| 2.0-c | Guion de migración idempotente (`scripts/migrar-sedes.py`), con pruebas en la CI: `bdm` e Ingeniería en Sistemas en lo existente | En dev (PR #233); corrido en desarrollo el 07/11 |
| 2.0-d | Catálogos: mantenimiento de sedes (administración general) y facultades (coordinación), con un componente común y reglas de lectura por sede | En dev (PR #234) |
| 2.0-e | Aplicación. **e1:** la sede de trabajo va en cada llamada; selector de sede (solo con más de una); grupos, programados y usuarios filtrados por sede. **e2:** envío y grupos por facultad, facultades de cada persona en Usuarios (`cambiarFacultades`) | e1 en dev (PR #235); e2 en desarrollo |
| 2.0-f | Contraer: las reglas exigen la sede; pruebas cruzadas sede A / sede B. Las consultas de la aplicación pasan a filtrar por `sedeId` en Firestore (hoy filtran en el aparato, porque las reglas aún no lo exigen) | **Espera decisión** (ver abajo) |

**2.0-f: lo que falta decidir antes de contraer (07/11/2026).** Que las reglas exijan la sede
obliga a que las consultas de la aplicación la pidan (`where('sedeId', '==', sede)`):
Firestore no evalúa reglas fila por fila en una consulta, y la consulta tiene que demostrar
por sí misma que solo trae lo permitido. Eso choca con tres cosas:

1. **La bitácora vieja no tiene `sedeId`**, y una consulta por sede no devuelve documentos
   sin el campo: los asientos de antes de la 2.0 dejarían de verse. Opciones:
   (a) que la migración les ponga `sedeId: 'bdm'` —solo clasifica, no cambia qué pasó, pero
   toca una colección que hoy tratamos como inmutable—; o (b) que la bitácora anterior a la
   2.0 la vea solo la administración general. **Se recomienda (a)**, dejando constancia en un
   asiento de la propia migración.
2. **Las entregas no llevan sede**, y el historial y los reportes las leen con consultas de
   grupo de colecciones. Hay que escribir `sedeId` en cada entrega nueva y migrar las viejas.
3. **La lista de usuarios:** las reglas no pueden recorrer las membresías de una persona.
   Hace falta un campo `sedesIds` (lista) en cada perfil y en el token la lista de sedes donde
   se coordina, para comprobar `sedesIds.hasAny(...)`.

Con una sola sede ninguno de los tres cambia lo que se ve hoy; por eso el 2.0-f espera la
decisión del responsable y no bloquea probar lo demás en desarrollo.

**Compatibilidad durante la migración.** Un perfil sin `membresias` y un token sin `sedes`
equivalen a la sede inicial (`bdm`) con su rol de siempre (`membresiasDe`, `sedesDelToken`).
El campo `rol` sigue diciendo el rol en la sede principal, porque las versiones de la
aplicación anteriores a la 2.0 solo leen ese campo. Un documento sin `sedeId` es de `bdm`
(`sedeDelDocumento`). Con una sola sede nadie elige nada (`elegirSede`).

## Requisitos relacionados

RF-SED-01 a RF-SED-06 (documento 01, sección 3.9) · RF-USR-06 · DT-04 · documento 12,
sección 6.
