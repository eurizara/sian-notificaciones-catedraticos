# lib/domain — Capa de dominio del cliente

Entidades, objetos de valor y reglas puras que la interfaz necesita para dar
retroalimentación inmediata al usuario.

> **No es la fuente de verdad.** Las reglas críticas —cálculo de recurrencia,
> transiciones de estado y autorización— viven **únicamente** en TypeScript, del
> lado del servidor (`functions/src/domain/`). Lo que se escriba aquí es
> validación de conveniencia: sirve para no dejar pulsar «Enviar» con el título
> vacío, nunca para decidir si un envío procede.
>
> Así lo fija la deuda **DT-06**, y es lo que evita que cliente y servidor
> diverjan sin que nadie se entere.

Se puebla en la iteración 1.2.
