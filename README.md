# SIAN — Sistema Institucional de Avisos y Notificaciones

Aplicación de avisos y alertas para catedráticos universitarios. Permite al coordinador
académico y a personal administrativo autorizado emitir notificaciones informativas o
urgentes (texto, voz e imagen), programarlas, repetirlas con un patrón definido y llevar
trazabilidad completa con confirmación de lectura.

> **Estado del proyecto:** Fase 1 · Iteración 1.1 — Cimientos.
> La documentación de ingeniería (fase 0) está completa. Ya existen la capa de dominio en
> TypeScript con sus pruebas, las reglas de seguridad con las suyas, la integración continua
> el entorno local con emuladores y el esqueleto de la aplicación Flutter. Todavía **no** hay
> autenticación ni Cloud Functions desplegadas: llegan en las iteraciones 1.2 a 1.4 del
> [plan](docs/08-plan-iteraciones.md).

---

## Empezar en cinco minutos

Requiere Git, Node.js 20 y Java 17 (documento 06, etapa A).

```bash
bash scripts/bootstrap.sh   # comprueba herramientas e instala dependencias
npm run verificar           # analizador, compilación, cobertura y reglas de seguridad
npm run emu                 # emuladores en http://localhost:4000
npm run seed:dev            # datos de prueba, en otra terminal
```

Los emuladores **no envían notificaciones push reales**: Firebase Cloud Messaging no tiene
emulador. En local se prueba todo lo demás; la llegada de la notificación al dispositivo
solo se verifica desplegando a `dev` (documento 06, etapa D.5).

### Estado por iteración

| Iteración | Entregable | Estado |
|---|---|---|
| 1.1 | Estructura del repositorio e integración continua | Hecho |
| 1.1 | Capa de dominio en TypeScript con pruebas unitarias | Hecho — 119 pruebas, cobertura 95% |
| 1.1 | Reglas de seguridad con pruebas automatizadas | Hecho — 22 pruebas contra el emulador |
| 1.1 | Emuladores locales con datos sembrados | Hecho |
| 1.1 | Esqueleto Flutter: compila, PWA, analizador limpio | Hecho — 3 pruebas de widget |
| 1.1 | Proyecto `sian-umg-bdm-dev` con Blaze y alerta de presupuesto | Pendiente — requiere cuenta de facturación |
| 1.2 | Autenticación, lista blanca y administración de usuarios | Pendiente |
| 1.3 | Composición de mensajes y entrega inmediata | Pendiente |
| 1.4 | Programación, recurrencia y confirmación de lectura | Pendiente |

---

## Índice de la documentación

| # | Documento | Contenido |
|---|-----------|-----------|
| 01 | [Levantamiento de requerimientos](docs/01-levantamiento-requerimientos.md) | Alcance, actores, roles, RF, RNF, reglas de negocio, restricciones, supuestos, criterios de aceptación y matriz de trazabilidad |
| 02 | [Arquitectura y diseño](docs/02-arquitectura-y-diseno.md) | Estilo arquitectónico, patrones de diseño aplicados, estructura del repositorio, ambientes, estrategia de ramas |
| 03 | [Diagrama de flujo](docs/03-diagrama-flujo.md) | Flujo completo del sistema, de extremo a extremo |
| 04 | [Diagramas de secuencia](docs/04-diagrama-secuencia.md) | Envío inmediato, programado, recurrente, confirmación de lectura y autenticación |
| 05 | [Modelo de datos](docs/05-modelo-datos.md) | Colecciones de Firestore, índices, reglas de seguridad y bitácora |
| 06 | [Guía de despliegue](docs/06-guia-despliegue.md) | Copia local, GitHub, Firebase por ambiente y checklist de demo |
| 07 | [Deuda técnica](docs/07-deuda-tecnica.md) | Registro formal de deuda técnica con causa, impacto y plan de pago |
| 08 | [Plan de iteraciones](docs/08-plan-iteraciones.md) | Prototipo → QA → producción, con criterios de salida por fase |
| 09 | [Guion de pruebas](docs/09-guion-de-pruebas.md) | Qué probar en cada ronda, paso a paso, con su alcance y lo que queda fuera |

---

## Decisiones de arquitectura ya tomadas

| Decisión | Elección | Motivo |
|----------|----------|--------|
| Backend / servicios en la nube | **Firebase** (Auth, Firestore, Storage, Cloud Functions, FCM, Hosting) | Cubre autenticación, datos, archivos y push sin servidor propio |
| Framework de aplicación | **Flutter** (un solo código fuente) | Web hoy, Android/iOS nativo mañana sin reescribir la lógica |
| Canal de distribución | **PWA vía Firebase Hosting**, sin tiendas de aplicaciones | Requisito explícito: cero publicación en Google Play / App Store |
| Plan de Firebase | **Blaze** (pago por uso) | Obligatorio para Cloud Functions, Cloud Storage y Cloud Scheduler. A esta escala el consumo real proyectado se mantiene dentro de las cuotas gratuitas incluidas |
| Mensaje de voz | **Grabación del emisor** subida a Cloud Storage | Sin dependencia de costo variable de Text-to-Speech |
| Programación de envíos | **1 job de Cloud Scheduler por ambiente** que consume una cola en Firestore | Cloud Scheduler regala 3 jobs por cuenta de facturación: dev + qa + prod = 3 = exactamente la cuota gratuita |

Ver el detalle y las alternativas descartadas en
[docs/02-arquitectura-y-diseno.md](docs/02-arquitectura-y-diseno.md).

---

## Propósito académico

Este proyecto es además material de referencia para estudiantes de Ingeniería en Sistemas.
Por eso se exige, sin excepción:

- Documentación previa al código (este repositorio empieza por los requerimientos).
- Arquitectura por capas con dependencias dirigidas hacia el dominio.
- Patrones de diseño aplicados con justificación escrita, no por decoración.
- Tres ambientes separados: desarrollo, pruebas de calidad y producción.
- Toda decisión que sacrifique calidad por costo o alcance queda registrada como deuda
  técnica formal, con impacto y plan de pago.

---

## Licencia y branding

Repositorio público. El branding institucional (logotipos, nombre y colores de la
universidad) lo proporciona el propietario del proyecto y se integra en la fase de
prototipo. Mientras tanto se usan marcadores de posición neutros.
