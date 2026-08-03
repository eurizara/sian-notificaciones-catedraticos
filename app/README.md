# app/ — Aplicación Flutter

Aquí viven el **panel web de administración** y la **aplicación del catedrático**: una sola
base de código Flutter compilada a web y servida como PWA instalable (ADR-002, ADR-003).

**Estado:** esqueleto de la iteración 1.1. Compila, pasa el analizador sin advertencias y
muestra una pantalla de estado honesta. El inicio de sesión llega en la iteración 1.2.

## Ejecutar en local

```bash
cd app && flutter run -d chrome --web-port=5000 --dart-define=USE_EMULATOR=true
```

## Estructura (documento 02, sección 6)

```
lib/
├── main.dart
├── core/                Configuración de entorno, errores, utilidades
├── domain/              Entidades y reglas — validación de conveniencia (DT-06)
├── application/         Casos de uso
├── infrastructure/      Única carpeta autorizada a importar Firebase (RNF-19)
└── presentation/
    ├── shared/          Tema, textos y componentes comunes
    ├── admin/           Panel de administración
    └── docente/         Aplicación del catedrático
```

Cada carpeta lleva su propio README explicando qué entra y qué no.

## Tres cosas que cuestan días si se ignoran

**1. `web/firebase-messaging-sw.js` nunca se fusiona con `flutter_service_worker.js`.**
Son dos archivos y se quedan como dos archivos. Mezclarlos es el riesgo R-03 del documento
02, sección 10, y la causa más frecuente de que las notificaciones dejen de llegar tras una
actualización, sin ningún error visible. `firebase.json` sirve el primero con
`Cache-Control: no-cache` por la misma razón.

**2. La lógica crítica no se duplica aquí.** Recurrencia, transiciones de estado y
autorización viven únicamente en TypeScript, del lado del servidor
(`functions/src/domain/`). Lo que hay en `lib/domain/` sirve para no dejar pulsar «Enviar»
con el título vacío, nunca para decidir si un envío procede. Deuda **DT-06**.

**3. El peso inicial importa.** RNF-03 exige menos de 5 segundos en la primera visita.
La compilación actual pesa **2.0 MB** de `main.dart.js` más **37 MB** de CanvasKit, que se
descarga por separado y se cachea. Es el riesgo **R-06** del documento 02, sección 10, y hay
que medirlo con Lighthouse contra una conexión de 4 Mbps antes de la fase de QA, no después.

## Configuración

Nada de configuración se escribe a mano en el código. Los valores por ambiente entran por
`--dart-define` y se leen en [`lib/core/entorno.dart`](lib/core/entorno.dart).

`lib/firebase_options.dart` lo genera `flutterfire configure` y está en `.gitignore`: cada
persona que replique el proyecto genera el suyo (RNF-20, RES-10).
