# Registros de decisión de arquitectura (ADR)

Toda decisión relevante se documenta aquí con el formato: contexto, opciones consideradas,
decisión, consecuencias y estado (documento 02, sección 14).

## Índice

Las ocho decisiones fundacionales están tomadas y justificadas en
[docs/02-arquitectura-y-diseno.md](../02-arquitectura-y-diseno.md); su desarrollo individual
como archivo ADR está pendiente.

| ADR | Decisión | Estado | Archivo |
|-----|----------|--------|---------|
| ADR-001 | Firebase como plataforma de servicios en la nube | Aceptada | pendiente |
| ADR-002 | Flutter como framework único para panel y aplicación | Aceptada | pendiente |
| ADR-003 | Distribución exclusiva como PWA, sin tiendas de aplicaciones | Aceptada | pendiente |
| ADR-004 | Patrón Outbox con un solo job de Cloud Scheduler por ambiente | Aceptada | pendiente |
| ADR-005 | Clean Architecture con cuatro capas | Aceptada | pendiente |
| ADR-006 | Nota de voz por grabación del emisor, sin texto a voz | Aceptada | pendiente |
| ADR-007 | Tres proyectos de Firebase separados por ambiente | Aceptada | pendiente |
| ADR-008 | Lista blanca de correos en lugar de funciones de bloqueo de Identity Platform | Aceptada | pendiente |

## Plantilla

```markdown
# ADR-XXX · Título de la decisión

**Estado:** Propuesta | Aceptada | Sustituida por ADR-YYY | Obsoleta
**Fecha:** dd de mes de aaaa
**Decide:** rol o persona

## Contexto

Qué problema hay que resolver y qué fuerzas actúan sobre él: requisitos que lo empujan,
restricciones que lo limitan, plazos, costo.

## Opciones consideradas

| Opción | A favor | En contra |
|--------|---------|-----------|

## Decisión

Qué se eligió y por qué esa y no otra.

## Consecuencias

Lo bueno y lo malo que trae, incluida la deuda técnica que genera. Si genera deuda, se
registra además en `docs/07-deuda-tecnica.md` con su ID.

## Requisitos relacionados

RF-…, RNF-…, RES-…, DT-…
```

## Cuándo escribir un ADR

Cuando la decisión sea costosa de revertir, afecte a más de un módulo, o alguien vaya a
preguntar «¿por qué está hecho así?» dentro de seis meses. Si la respuesta cabe en un
comentario del código, no hace falta un ADR.
