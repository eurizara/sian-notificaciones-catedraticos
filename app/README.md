# app/ — Aplicación Flutter

Aquí viven el **panel web de administración** y la **aplicación del catedrático**, una sola
base de código Flutter compilada a web y servida como PWA instalable (ADR-002, ADR-003).

> **Todavía no existe.** El proyecto Flutter se genera en la **iteración 1.2** del
> [plan de iteraciones](../docs/08-plan-iteraciones.md), que es cuando entra la
> autenticación. La iteración 1.1 entrega los cimientos que no se ven: dominio, reglas de
> seguridad e integración continua.

## Cómo se generará

```bash
flutter create --platforms=web --org gt.edu.umg --project-name sian app
```

Después, la estructura interna debe seguir el documento 02, sección 6:

```
app/
├── pubspec.yaml
├── web/
│   ├── index.html
│   ├── manifest.json                Manifiesto PWA
│   └── firebase-messaging-sw.js     Service worker de notificaciones, SEPARADO
└── lib/
    ├── main.dart
    ├── core/                        Errores, constantes, utilidades, inyección
    ├── domain/                      Entidades, objetos de valor, interfaces, reglas
    ├── application/                 Casos de uso
    ├── infrastructure/              Implementaciones Firebase
    └── presentation/
        ├── shared/                  Componentes comunes, tema, branding
        ├── admin/                   Panel de administración
        └── docente/                 Aplicación del catedrático
```

## Dos advertencias que cuestan días si se ignoran

1. **`firebase-messaging-sw.js` nunca se fusiona con el service worker que genera Flutter.**
   Mantenerlos separados es la mitigación del riesgo R-03 (documento 02, sección 10) y la
   causa más frecuente de que las notificaciones dejen de llegar tras una actualización.

2. **La lógica crítica no se duplica aquí.** El cálculo de recurrencia, las transiciones de
   estado y la autorización viven únicamente en TypeScript, del lado del servidor
   (`functions/src/domain/`). Lo que se escriba en `lib/domain/` es validación de
   conveniencia para dar retroalimentación rápida, y nunca es la fuente de verdad — así lo
   fija la deuda DT-06.
