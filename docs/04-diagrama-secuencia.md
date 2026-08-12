# 04 — Diagramas de secuencia

**Versión:** 1.0 · 2 de agosto de 2026

Cinco secuencias cubren la totalidad del comportamiento del sistema:

1. Autenticación y registro de dispositivo
2. Envío inmediato de alerta urgente con voz e imagen
3. Programación de mensaje para fecha y hora específicas
4. Despacho automático y generación de la siguiente ocurrencia recurrente
5. Confirmación de lectura y trazabilidad

---

## 1. Autenticación y registro de dispositivo

```mermaid
sequenceDiagram
    autonumber
    actor U as Catedrático
    participant APP as App (Flutter PWA)
    participant SW as Service Worker
    participant AUTH as Firebase Auth
    participant FN as Cloud Functions
    participant FS as Firestore
    participant FCM as Firebase Cloud Messaging

    U->>APP: Abre la aplicación
    APP->>AUTH: Consulta si hay sesión vigente
    AUTH-->>APP: Sin sesión

    APP->>U: Muestra opciones de acceso
    U->>APP: Elige "Continuar con Google"
    APP->>AUTH: signInWithPopup(GoogleProvider)
    AUTH->>AUTH: Flujo OAuth 2.0 con Google
    AUTH-->>APP: Credencial + idToken

    APP->>FN: registrarAcceso(idToken)
    activate FN
    FN->>AUTH: Verifica el idToken
    AUTH-->>FN: uid + correo verificados
    FN->>FS: Lee invitaciones/{correo}

    alt Correo NO está en la lista blanca
        FS-->>FN: No existe
        FN->>FS: Escribe bitacora: SESION_RECHAZADA
        FN->>AUTH: Elimina la cuenta recién creada
        FN-->>APP: Error 403 — correo no autorizado
        APP->>U: "Su correo no está autorizado.<br/>Contacte a coordinación."
    else Correo autorizado
        FS-->>FN: {rolAsignado, nombre}
        FN->>FS: Crea o actualiza usuarios/{uid}
        FN->>AUTH: setCustomUserClaims({rol, activo})
        FN->>FS: Marca la invitación como consumida
        FN->>FS: Escribe bitacora: SESION_INICIADA
        FN-->>APP: 200 — {rol, perfil}
    end
    deactivate FN

    APP->>AUTH: getIdToken(forceRefresh: true)
    Note over APP,AUTH: Refresco obligatorio:<br/>sin él el token no lleva el rol

    APP->>APP: Detecta si corre instalada como PWA

    alt Es iOS y NO está instalada
        APP->>U: Instructivo obligatorio<br/>Compartir → Agregar a inicio
        Note over U,APP: Sin instalación,<br/>iOS no entrega notificaciones (RES-05)
    else Puede continuar
        APP->>U: Solicita permiso de notificaciones
        U->>APP: Concede el permiso
        APP->>SW: Registra firebase-messaging-sw.js
        SW-->>APP: Service worker activo
        APP->>FCM: getToken(vapidKey, serviceWorkerRegistration)
        FCM-->>APP: tokenFCM
        APP->>FN: registrarDispositivo(tokenFCM, plataforma, esPWAInstalada)
        FN->>FS: Escribe usuarios/{uid}/dispositivos/{tokenId}
        FN->>FCM: Envía notificación de prueba
        FCM-->>SW: Notificación de prueba
        SW->>U: Muestra "Notificaciones activadas"
        Note over FN,U: La prueba automática detecta<br/>de inmediato el riesgo R-01
    end

    APP->>U: Muestra la pantalla principal según el rol
```

---

## 2. Envío inmediato de alerta urgente con voz e imagen

```mermaid
sequenceDiagram
    autonumber
    actor CO as Coordinador
    participant PA as Panel Web
    participant ST as Cloud Storage
    participant FN as Cloud Functions
    participant FS as Firestore
    participant FCM as Firebase Cloud Messaging
    participant SW as Service Worker (docente)
    actor CA as Catedrático

    CO->>PA: Nuevo mensaje → tipo URGENTE
    CO->>PA: Título y cuerpo
    CO->>PA: Adjunta el plano de evacuación
    PA->>PA: Valida tipo y tamaño ANTES de subir
    CO->>PA: Graba nota de voz (42 s)
    PA->>PA: Valida duración ≤ 60 s y peso ≤ 2 MB
    Note over PA: Nada se ha subido todavía.<br/>El orden en que se adjuntan es<br/>el que verá quien reciba.

    CO->>PA: Destinatarios = todos los catedráticos
    CO->>PA: Marca "exigir confirmación de lectura"
    CO->>PA: Envío inmediato → pulsa Enviar ahora

    PA->>FN: contarDestinatarios()
    FN-->>PA: 58 · con los excluidos y su motivo

    PA->>CO: 1.ª confirmación: a cuántos va,<br/>quién queda fuera y QUÉ ADJUNTOS lleva
    CO->>PA: Confirma
    PA->>CO: 2.ª confirmación: es una ALERTA URGENTE
    Note over PA,CO: RF-MSG-13 · RN-06 — el botón de<br/>enviar NO cuenta como confirmación
    CO->>PA: Confirma explícitamente

    Note over PA,ST: Recién ahora se sube. Si alguien cancelaba,<br/>no se gastaron los datos de nadie.
    PA->>PA: Reserva el identificador del mensaje
    PA->>ST: Sube 1-imagen.png a mensajes/{mensajeId}/
    ST-->>PA: Ruta
    PA->>ST: Sube 2-voz.webm a mensajes/{mensajeId}/
    ST-->>PA: Ruta
    Note over PA,ST: EN SERIE, no en paralelo: el orden de<br/>llegada lo decidiría la red, y con él<br/>el orden en que se ven.

    PA->>FN: enviarInmediato(payload + adjuntos.lista)
    activate FN
    FN->>FN: Cadena de validación:<br/>permisos → contenido → adjuntos<br/>→ destinatarios → programación
    FN->>FS: Lee el nombre del emisor para guardarlo con el mensaje
    FN->>FS: create() de mensajes/{mensajeId} en EN_ENVIO
    Note over FN,FS: create y no set: falla si ya existe,<br/>y eso impide pisar un mensaje ajeno<br/>pasando su identificador.
    FN->>FS: Crea ocurrencia número 1
    FN->>FS: Escribe bitacora: MENSAJE_CREADO
    FN->>FS: Inserta ítem en cola_despacho con ejecutarEn = ahora
    FN-->>PA: {mensajeId, estado, total, entregados, fallidos}
    deactivate FN

    PA->>FS: Se suscribe en tiempo real a la ocurrencia
    PA->>CO: Muestra "Enviando…" con barra de avance

    Note over FN: El despachador toma el ítem<br/>en menos de 60 segundos

    FN->>FS: Transacción PENDIENTE → TOMADO
    FN->>FS: Resuelve destinatarios y descarta inactivos
    FS-->>FN: 58 uid con 71 tokens activos
    FN->>FS: Crea 58 documentos de entrega en estado PENDIENTE
    FN->>FS: Escribe bitacora: ENVIO_INICIADO

    loop Por cada lote de hasta 500 tokens
        FN->>FCM: sendEachForMulticast(lote, prioridad alta)
        FCM-->>FN: Resultado individual por token
        FN->>FS: Actualiza cada entrega a ENTREGADO o FALLIDO
    end

    alt Hay tokens rechazados
        FN->>FS: Marca esos dispositivos como inactivos
        FN->>FS: Escribe bitacora: ENTREGA_FALLIDA
    end

    FN->>FS: Actualiza contadores del mensaje y la ocurrencia
    FN->>FS: Marca mensaje ENVIADO
    FN->>FS: Escribe bitacora: ENVIO_COMPLETADO
    FS-->>PA: Actualización en tiempo real
    PA->>CO: "Entregado a 56 de 58 · 2 fallos"

    FCM-->>SW: Push con prioridad alta
    SW->>CA: Notificación con sonido, vibración y alerta visual
    Note over SW,CA: En Android, canal de importancia HIGH.<br/>En iOS-PWA, solo alerta visual (DT-02)
```

---

## 3. Programación de un mensaje para fecha y hora específicas

```mermaid
sequenceDiagram
    autonumber
    actor AD as Administradora
    participant PA as Panel Web
    participant FN as Cloud Functions
    participant FS as Firestore

    AD->>PA: Compone aviso informativo
    AD->>PA: Programación → fecha 15/08/2026, hora 07:00
    PA->>FS: Lee configuracion/institucional
    FS-->>PA: {zonaHoraria: "America/Guatemala"}
    PA->>PA: Convierte 15/08/2026 07:00 local → UTC
    PA->>PA: Valida que la fecha sea futura (RF-PRG-04)

    alt La fecha ya pasó
        PA->>AD: Error "La fecha y hora deben ser futuras"
    else Fecha válida
        AD->>PA: Confirma la programación
        PA->>FN: programarMensaje(payload, programacion)
        activate FN
        FN->>FN: Revalida la fecha en el servidor
        Note over FN: Nunca se confía en la validación<br/>del cliente (RN-01)
        FN->>FN: Verifica permiso de programación del emisor
        FN->>FS: Crea mensajes/{id} en estado PROGRAMADO
        FN->>FS: Crea ocurrencia 1 con previstaPara = fecha UTC
        FN->>FS: Inserta ítem en cola_despacho<br/>{ejecutarEn: fecha UTC, estado: PENDIENTE}
        FN->>FS: Escribe bitacora: MENSAJE_PROGRAMADO
        FN-->>PA: 201 — {mensajeId, proximaEjecucion}
        deactivate FN
        PA->>AD: "Programado para el 15/08/2026 a las 07:00"
    end

    Note over AD,FS: Mientras tanto, la administradora<br/>puede suspender o cancelar

    opt La administradora cancela antes del disparo
        AD->>PA: Cancelar programación
        PA->>FN: cancelarProgramacion(mensajeId)
        FN->>FS: Verifica que el mensaje siga en estado PROGRAMADO
        FN->>FS: Marca el ítem de cola como CANCELADO
        FN->>FS: Marca el mensaje como CANCELADO
        FN->>FS: Escribe bitacora: MENSAJE_CANCELADO
        FN-->>PA: 200
        PA->>AD: "Programación cancelada"
    end
```

---

## 4. Despacho automático y generación de la siguiente ocurrencia recurrente

Es la secuencia crítica del sistema. Muestra cómo se garantiza que no haya envíos duplicados
(RF-PRG-12) usando un solo job de Cloud Scheduler (RES-04).

```mermaid
sequenceDiagram
    autonumber
    participant CS as Cloud Scheduler
    participant D1 as Despachador · instancia A
    participant D2 as Despachador · instancia B
    participant FS as Firestore
    participant FCM as Firebase Cloud Messaging
    participant BIT as Bitácora

    Note over CS: Un único job por ambiente,<br/>cada 60 segundos (RES-04)

    CS->>D1: HTTP POST /despachador
    activate D1
    D1->>FS: query cola_despacho<br/>estado = PENDIENTE<br/>ejecutarEn ≤ ahora<br/>orden por prioridad, límite 50
    FS-->>D1: [item_47]

    par Escenario de concurrencia: reintento simultáneo del planificador
        CS->>D2: HTTP POST /despachador (reejecución)
        activate D2
        D2->>FS: misma consulta
        FS-->>D2: [item_47]
    end

    D1->>FS: TRANSACCIÓN sobre item_47<br/>si estado = PENDIENTE<br/>entonces estado = TOMADO,<br/>bloqueoHasta = ahora + 5 min
    FS-->>D1: Transacción confirmada · bloqueo obtenido

    D2->>FS: TRANSACCIÓN sobre item_47<br/>misma precondición
    FS-->>D2: Transacción abortada · ya no está en PENDIENTE
    D2->>D2: No hace nada
    deactivate D2
    Note over D1,D2: RF-PRG-12 garantizado por transacción,<br/>no por convención

    D1->>FS: Lee el mensaje y su patrón de recurrencia
    FS-->>D1: {tipo: INFORMATIVO, recurrencia: cada 1 día,<br/>días [1,3,5], fin 30/11/2026}

    D1->>D1: retraso = ahora − previstaPara

    alt retraso > toleranciaRetrasoMin
        D1->>FS: Marca la ocurrencia OMITIDA
        D1->>BIT: OCURRENCIA_OMITIDA {motivo, retraso}
        Note over D1: RF-PRG-13
    else retraso aceptable
        D1->>FS: Resuelve destinatarios<br/>(expande grupos, descarta inactivos)
        FS-->>D1: 58 uid
        D1->>FS: Lee tokens activos de cada uno
        FS-->>D1: 71 tokens
        D1->>FS: Crea 58 documentos de entrega
        D1->>BIT: ENVIO_INICIADO

        loop Lotes de 500
            D1->>FCM: sendEachForMulticast(lote)
            FCM-->>D1: Resultados individuales
            D1->>FS: Actualiza estado de cada entrega
        end

        D1->>FS: Actualiza contadores de la ocurrencia
        D1->>BIT: ENVIO_COMPLETADO {entregados, fallidos}
    end

    D1->>D1: Ejecuta EstrategiaRecurrencia.siguiente()
    Note over D1: Subflujo detallado en<br/>documento 03, sección 2

    alt Quedan ocurrencias por venir
        D1->>FS: Crea ocurrencia número n+1
        D1->>FS: Inserta nuevo ítem en cola_despacho<br/>{ejecutarEn: siguienteFecha}
        D1->>FS: Incrementa ocurrenciasGeneradas
        D1->>FS: Mensaje pasa a RECURRENTE_PENDIENTE
    else Se alcanzó fechaFin o maxOcurrencias
        D1->>FS: Mensaje pasa a AGOTADO
        D1->>FCM: Avisa al creador del mensaje
        Note over D1: RF-PRG-14
    end

    D1->>FS: Marca item_47 como COMPLETADO
    D1->>FS: Depura ítems completados con más de 7 días
    D1-->>CS: 200 OK
    deactivate D1
```

---

## 5. Confirmación de lectura y trazabilidad

```mermaid
sequenceDiagram
    autonumber
    actor CA as Catedrático
    participant SW as Service Worker
    participant APP as App del Catedrático
    participant FN as Cloud Functions
    participant FS as Firestore
    participant BIT as Bitácora
    participant PA as Panel Web
    actor CO as Coordinador

    SW->>CA: Notificación "SIMULACRO 10:00 h"
    CA->>SW: Pulsa la notificación
    SW->>APP: Abre la aplicación en el detalle del mensaje

    APP->>FS: Lee mensajes/{id} y su entrega propia
    FS-->>APP: Contenido y adjuntos
    APP->>FN: marcarAbierto(mensajeId, ocurrenciaId)
    activate FN
    FN->>FS: Verifica que exista la entrega para este uid
    FN->>FS: entregas/{uid}.estado = ABIERTO, abiertoEn = ahora
    FN->>BIT: MENSAJE_ABIERTO
    FN-->>APP: 200
    deactivate FN

    APP->>CA: Muestra texto, imagen y reproductor de voz
    CA->>APP: Reproduce la nota de voz

    Note over APP,CA: Abrir NO equivale a confirmar (RF-CNF-02)

    APP->>CA: Muestra el control "Confirmar lectura"
    CA->>APP: Pulsa Confirmar

    APP->>FN: confirmarLectura(mensajeId, ocurrenciaId, dispositivoId)
    activate FN
    FN->>FS: Lee entregas/{uid}

    alt Ya estaba confirmada
        FS-->>FN: {estado: CONFIRMADO}
        FN-->>APP: 200 — idempotente, sin cambios
        Note over FN: RF-CNF-05: sin duplicados
    else Aún no confirmada
        FS-->>FN: {estado: ABIERTO}
        FN->>FS: TRANSACCIÓN<br/>entrega.estado = CONFIRMADO<br/>confirmadoEn = ahora<br/>dispositivoConfirmacion = id<br/>ocurrencia.totalConfirmados += 1
        FS-->>FN: Confirmada
        FN->>BIT: LECTURA_CONFIRMADA<br/>{uid, correo, rol, mensajeId, timestamp, dispositivo}
        FN-->>APP: 200 — confirmado
        Note over FN,FS: Solo el servidor escribe la confirmación.<br/>El cliente no puede falsificarla (RF-CNF-04)
    end
    deactivate FN

    APP->>CA: "Lectura confirmada" · el control desaparece

    FS-->>PA: Actualización en tiempo real de la ocurrencia
    PA->>CO: Contador sube a 47 de 58 confirmados (81%)

    CO->>PA: Abre la vista de trazabilidad
    PA->>FS: Consulta el grupo de colección entregas del mensaje
    FS-->>PA: Estado y marcas de tiempo por destinatario
    PA->>CO: Tabla: entregado, abierto, confirmado y fecha de cada uno

    opt Reenviar solo a los pendientes
        CO->>PA: "Reenviar a los 11 no confirmados"
        PA->>FN: reenviarAPendientes(mensajeId, ocurrenciaId)
        FN->>FS: Filtra entregas con estado distinto de CONFIRMADO
        FN->>FS: Crea nueva ocurrencia de reenvío
        FN->>FS: Inserta ítem en cola_despacho
        FN->>BIT: MENSAJE_PROGRAMADO {motivo: reenvio}
        FN-->>PA: 202
        Note over FN: RF-CNF-08
    end

    opt Auditoría
        CO->>PA: Consulta la bitácora del mensaje
        PA->>FS: query bitacora<br/>entidadId = mensajeId, orden por ocurridoEn
        FS-->>PA: Cronología completa del ciclo de vida
        PA->>FN: registrarConsultaBitacora()
        FN->>BIT: BITACORA_CONSULTADA
        Note over FN: Se audita incluso quién audita
    end
```

---

## 6. Correspondencia entre secuencias y requisitos

| Secuencia | Requisitos que demuestra |
|-----------|--------------------------|
| 1 · Autenticación | RF-AUT-01, 02, 03, 04 · RF-USR-09 · RES-05 · R-01 |
| 2 · Envío inmediato urgente | RF-MSG-01..13 · RF-PRG-01 · RF-ENT-01..06, 10, 11, 14 |
| 3 · Programación | RF-PRG-02, 03, 04, 11 · RN-01, RN-05 |
| 4 · Despacho y recurrencia | RF-PRG-05..14 · RF-ENT-14 · RNF-04, RNF-06 · RES-04 |
| 5 · Confirmación y trazabilidad | RF-CNF-01..08 · RF-BIT-01, 02, 07, 08 · RNF-17 |
