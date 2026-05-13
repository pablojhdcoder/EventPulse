# Arquitectura distribuida de EventPulse

Este documento describe la arquitectura distribuida vigente de EventPulse.

## Objetivo arquitectonico

EventPulse sigue un esquema cliente-servidor distribuido:

- clientes ligeros (participantes y administradores);
- un componente de entrada unica (Director) para enrutar trafico;
- varias replicas de la aplicacion Phoenix;
- una base de datos compartida para la persistencia.

## Topologia actual de ejecucion

En local se admiten dos modos:

1. **Modo desarrollo**: `mix phx.server` sobre una instancia de aplicacion.
2. **Modo demo distribuida**: `docker compose up -d --build` con servicios `web1`, `web2`, `web3`, `postgres`, `redis` y `director`.

En la demo distribuida, el Director (NGINX) publica `http://localhost:8080` y reparte HTTP y WebSocket entre replicas.

## Componentes funcionales vigentes

En `event_pulse/` conviven estas capacidades:

- **Eventos**: listado y detalle de eventos, gestion de estados.
- **Chat en vivo**: sala por evento con difusion en tiempo real.
- **Votacion en vivo**: voto por usuario y recuento actualizado.
- **Cierre**: transición a `finalizado`, cierre de encuestas en base de datos, notificación por PubSub y limpieza best-effort del buffer de chat en Redis.
- **Historial en interfaz**: en evento finalizado, la LiveView muestra el recap de votos por encuesta (sin tabla ni indicador agregado tipo Social Feeling en PostgreSQL).

## Persistencia y estado efimero

Persistido en base de datos:

- usuarios;
- eventos;
- encuestas (`polls`) y votos asociados (recuentos consultables en la aplicación; no hay fila de “resultado SF” persistido).

Efimero (no persistencia historica en PostgreSQL):

- buffer reciente del chat almacenado en Redis;
- estado transitorio de suscripciones y sockets en procesos BEAM;
- caches de recuento en vivo en memoria de proceso.

### Buffer de chat y Redis

- El chat mantiene un buffer reciente para mejorar la experiencia al entrar en una sala activa.
- Ese buffer se almacena en Redis (no en memoria local del proceso), con expiracion y acceso compartido entre replicas.
- En ejecucion distribuida, Redis se usa como soporte compartido para coordinar el estado efimero del chat entre replicas.
- Redis no sustituye la persistencia de negocio: los datos autoritativos (usuarios, eventos, encuestas y votos) siguen en PostgreSQL.

## Consistencia en multi-nodo

- La fuente autoritativa para cierre de evento, encuestas y votos es PostgreSQL.
- En despliegue multi-nodo puede haber desfases breves en vistas en vivo.
- Redis reduce las divergencias de estado efimero entre nodos, pero no convierte ese estado en historico permanente.

## PubSub y tiempo real

- Los eventos de negocio se publican por topicos de evento (`event:<id>`).
- Las actualizaciones de chat, estado y votos se propagan mediante PubSub y los procesos LiveView/Canal suscritos.

## Riesgos y limites actuales

- El Director es infraestructura de enrutamiento, no logica de dominio.
- Redis mejora la coordinación del estado efímero del chat, pero no sustituye persistencia historica de mensajes.

