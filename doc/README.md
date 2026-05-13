# Índice de documentación - EventPulse

Este índice centraliza la documentación vigente del proyecto. 

## Documentos disponibles

- `propuesta.md`: propuesta inicial del proyecto (alcance, actores, RF/RNF y vistas C4).
- `arquitectura-distribuida-eventpulse.md`: arquitectura técnica vigente para despliegue distribuido, Redis, Director y límites de consistencia.
- `../event_pulse/README.md`: guía técnica de ejecución, configuración y uso de la aplicación.
- `../proyecto.md`: integrantes del equipo.

## Estado funcional actual (resumen)

En `event_pulse/` se dispone de:

- interfaz LiveView para listado y detalle de eventos;
- chat en tiempo real por evento;
- buffer reciente de chat respaldado en Redis;
- votación en vivo con recuento actualizado;
- gestión de estado de evento (`programado`, `en_directo`, `finalizado`);
- **cierre de evento**: encuestas pasan a cerradas, sin votos posteriores; vaciado best-effort del buffer de chat en Redis;
- **resumen de votaciones** en el detalle del evento finalizado (LiveView), sin indicador agregado tipo Social Feeling persistido;
- ejecución local con `mix` y demo distribuida con Docker Compose (Director + réplicas).


