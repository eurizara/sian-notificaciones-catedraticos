# SIAN — Sistema Institucional de Avisos y Notificaciones

Aplicación de avisos y alertas para catedráticos universitarios. Permite al coordinador
académico y a personal administrativo autorizado emitir notificaciones informativas o
urgentes (texto, voz e imagen), programarlas, repetirlas con un patrón definido y llevar
trazabilidad completa con confirmación de lectura.

> **Estado:** Fase 1 **en producción** desde el 26 de agosto de 2026. Iteraciones 1.1
> a 1.4 construidas, rondas de prueba 1 a 5 superadas y ambiente de calidad certificado
> ([plan](docs/08-plan-iteraciones.md)).
>
> | Ambiente | Aplicación | Manuales |
> |---|---|---|
> | Desarrollo | [sian-umg-bdm-dev.web.app](https://sian-umg-bdm-dev.web.app) | [/manuales](https://sian-umg-bdm-dev.web.app/manuales/) |
> | **Calidad** | [sian-umg-bdm-qa.web.app](https://sian-umg-bdm-qa.web.app) | [/manuales](https://sian-umg-bdm-qa.web.app/manuales/) |
> | **Producción** | [sian-umg-bdm.web.app](https://sian-umg-bdm.web.app) | [/manuales](https://sian-umg-bdm.web.app/manuales/) |
>
> Detalle de cada ambiente en el [documento 11](docs/11-ambientes.md).

---

## Con qué está hecho

Sin servidor propio, sin contenedores, sin nada que administrar entre el navegador de
un catedrático y los servicios de Google.

| Pieza | Qué se usó | Para qué |
|---|---|---|
| **Interfaz** | Flutter 3.44 · Dart 3.12, compilado a web | Una sola base de código para celular y computadora, instalable sin pasar por App Store ni Play Store |
| **Estado** | Riverpod 3 | Inyección de dependencias: es lo que permite probar cada pantalla sin levantar Firebase |
| **Servidor** | Cloud Functions v2 · Node 20 · TypeScript 5.9 | Todo lo que no puede confiarse al navegador. **19 funciones desplegadas** |
| **Base de datos** | Cloud Firestore, modo Native — **NoSQL documental** | Lectura directa desde el navegador con reglas por documento, y bandeja que se actualiza sola |
| **Identidad** | Firebase Authentication + *custom claims* | El rol viaja firmado dentro del token, no se consulta a la base al decidir permisos |
| **Notificaciones** | Firebase Cloud Messaging | El aviso que suena con la aplicación cerrada |
| **Archivos** | Cloud Storage | Notas de voz e imágenes |
| **Planificador** | Cloud Scheduler, cada minuto | Mensajes programados y recurrentes |

El navegador **lee** de Firestore directamente, pero **nunca escribe**: toda escritura
pasa por una Cloud Function, y las reglas lo hacen literal con `allow write: if false`.

### Por qué aparecen Python y Shell

GitHub lista **Python** (1.8 %) y **Shell** (0.9 %) entre los lenguajes del repositorio.
No son parte de la aplicación: **nada de eso se envía al navegador ni corre en producción**.
Son herramientas para operar el proyecto, y están en otro lenguaje por una razón concreta —
cada una resuelve algo en un momento donde el lenguaje principal todavía no existe:

| | Para qué | Por qué no en Dart o TypeScript |
|---|---|---|
| **Shell** | Preparar el entorno, buscar secretos antes de un push, generar `firebase_options.dart`, aplicar el CORS | Corren **antes** de que haya dependencias instaladas o de que el proyecto compile. `generar-firebase-options.sh` genera justamente el archivo sin el cual Dart no compila |
| **Python** | Crear las alertas de operación, comparar los tres ambientes, generar el juego de iconos | Llamadas REST a Google Cloud y tratamiento de imágenes. `urllib` y `json` son de la biblioteca estándar, así que corren sin instalar nada; la alternativa era exigir el SDK completo de `gcloud` |

Un catedrático no necesita ninguna: abre una dirección web. Detalle de cada script, con la
alternativa que se descartó, en [Arquitectura §2.9](docs/02-arquitectura-y-diseno.md).

Detalle completo, con versiones y con lo que se decidió **no** usar, en
[Arquitectura §2](docs/02-arquitectura-y-diseno.md). Dónde ver el código que Firebase
ejecuta ahora mismo y cómo comprobar que coincide con esta rama, en
[Arquitectura §6](docs/02-arquitectura-y-diseno.md).

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
| 1.1 | Estructura, integración continua y emuladores locales | Hecho |
| 1.1 | Dominio en TypeScript y reglas de seguridad, con sus pruebas | Hecho |
| 1.2 | Registro, lista blanca, usuarios, roles y bitácora | Hecho |
| 1.2 | Google, registro de dispositivo e instructivo de iOS | Hecho |
| 1.2 | Grupos de destinatarios | Hecho |
| 1.3 | Composición y entrega inmediata, con voz e imágenes | Hecho |
| 1.4 | Programación, recurrencia y confirmación de lectura | Hecho |
| 1.4 | Reporte de entregas y bitácora consultable | Hecho |
| — | **Desplegado en https://sian-umg-bdm-dev.web.app** | En línea |
| — | **Manuales de usuario publicados** | En línea |
| 2.x | Ambiente de QA y pruebas con catedráticos voluntarios | Siguiente |

**Pruebas hoy:** 275 de widget · 257 de dominio y Cloud Functions · reglas de
seguridad verificadas contra el emulador. Los cuatro trabajos de integración
continua corren en cada solicitud de incorporación.

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
| 10 | [Especificación de casos de uso](docs/10-casos-de-uso.md) | Los doce casos de uso en formato extendido ISO/IEC/IEEE 29148: actores, precondiciones, garantías, flujos principales, alternativos y de excepción, y trazabilidad a requisitos |
| 11 | [Ambientes](docs/11-ambientes.md) | Los tres ambientes: proyectos, URL, quién tiene acceso, configuración por ambiente, costo real medido y cómo se promueve un cambio |

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
