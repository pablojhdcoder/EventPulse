# EventPulse
Plataforma de eventos en vivo con votaciones y chat entre espectadores.

## Requisitos funcionales

### Gestión de usuarios
- RF-01: El sistema permite registrar nuevos usuarios con email y contraseña
- RF-02: El sistema permite hacer login y logout
- RF-03: El sistema restringe acciones sensibles a usuarios autenticados

### Gestión de eventos
- RF-04: El sistema permite crear, editar y eliminar eventos (admin)
- RF-05: El sistema permite listar y filtrar eventos por categoría
- RF-06: El sistema gestiona el estado de los eventos (`programado → en_directo → finalizado`)
- RF-07: El sistema notifica en tiempo real a los usuarios cuando un evento cambia de estado

### Votaciones
- RF-08: El sistema permite crear votaciones dentro de un evento con 2 a 4 opciones
- RF-09: El sistema permite a un usuario votar una sola vez por votación
- RF-10: El sistema permite actualizar el voto (cambia la opción, no añade un segundo voto)
- RF-11: El sistema muestra el recuento de votos en tiempo real
- RF-12: El sistema cierra las votaciones cuando el evento pasa a `finalizado`

### Chat
- RF-13: El sistema permite enviar mensajes en una sala de chat por evento
- RF-14: El sistema muestra el historial reciente al conectarse
- RF-15: El sistema deshabilita el chat cuando el evento finaliza

### Social Feeling
- RF-16: El sistema calcula el sentimiento social al cerrar un evento
- RF-17: El sistema muestra el resultado del Social Feeling en la vista del evento
