# Indice de documentacion - EventPulse

Esteíindice centraliza la documentación vigente del proyecto. 

## Documentos disponibles

- `propuesta.md`: propuesta inicial del proyecto (alcance, actores, RF/RNF y vistas C4).
- `arquitectura-distribuida-eventpulse.md`: arquitectura técnica vigente para despliegue distribuído, Redis, Director y límites de consistencia.
- `../event_pulse/README.md`: guia tecnica de ejecución, configuración y uso de la aplicación.
- `../proyecto.md`: integrantes del equipo.

## Estado funcional actual (resumen)

En `event_pulse/` se dispone de:

- interfaz LiveView para listado y detalle de eventos;
- chat en tiempo real por evento;
- buffer reciente de chat respaldado en Redis;
- votación en vivo con recuento actualizado;
- gestión de estado de evento (`programado`, `en_directo`, `finalizado`);
- cálculo y consulta de Social Feeling al cierre;
- ejecución local con `mix` y demo distribuída con Docker Compose (Director + replicas).


