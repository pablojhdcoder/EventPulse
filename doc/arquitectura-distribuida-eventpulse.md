# Arquitectura distribuida de EventPulse

Este documento describe la arquitectura distribuida vigente de EventPulse.

## Objetivo arquitectónico

EventPulse sigue un esquema cliente-servidor distribuido:

- clientes ligeros (participantes y administradores);
- un componente de entrada única (Director) para enrutar tráfico;
- varias réplicas de la aplicación Phoenix;
- una base de datos compartida para la persistencia.

## Topología actual de ejecución

Hay dos modos: **desarrollo** (una instancia con Mix) y **demo distribuida** (varias réplicas Phoenix, PostgreSQL, Redis y Director NGINX vía Docker Compose). Los comandos, directorios de trabajo, URLs y tests están descritos **solo** en [`event_pulse/README.md`](../event_pulse/README.md).

A nivel de contenedores/servicios, la demo agrupa `web1`, `web2`, `web3`, `postgres`, `redis` y `director`; el Director actúa como entrada única (puerto publicado en `docker-compose.yml`, habitualmente **8080** en el host). En [`doc/c4-contexto-contenedores.md`](c4-contexto-contenedores.md), las vistas de contenedor resumen **web2** y **web3** en una sola caja **webN**; en ejecución siguen siendo servicios distintos.

## Componentes funcionales vigentes

En `event_pulse/` conviven estas capacidades:

- **Eventos**: listado y detalle de eventos, gestión de estados.
- **Chat en vivo**: sala por evento con difusión en tiempo real.
- **Votación en vivo**: voto por usuario y recuento actualizado.
- **Cierre**: transición a `finalizado`, cierre de encuestas en base de datos, notificación por PubSub y limpieza best-effort del buffer de chat en Redis.
- **Historial en interfaz**: en evento finalizado, la LiveView muestra el recap de votos por encuesta (sin tabla ni indicador agregado tipo Social Feeling en PostgreSQL).

## Persistencia y estado efímero

Persistido en base de datos:

- usuarios;
- eventos;
- encuestas (`polls`) y votos asociados (recuentos consultables en la aplicación; no hay fila de “resultado SF” persistido).

Efímero (no persistencia histórica en PostgreSQL):

- buffer reciente del chat almacenado en Redis;
- estado transitorio de suscripciones y sockets en procesos BEAM;
- caches de recuento en vivo en memoria de proceso.

### Buffer de chat y Redis

- El chat mantiene un buffer reciente para mejorar la experiencia al entrar en una sala activa.
- Ese buffer se almacena en Redis (no en memoria local del proceso), con **recorte por longitud** (streams con `MAXLEN`, véase `EventPulse.ChatBuffer`) y acceso compartido entre réplicas.
- En ejecución distribuida, Redis se usa como soporte compartido para coordinar el estado efímero del chat entre réplicas.
- Redis no sustituye la persistencia de negocio: los datos autoritativos (usuarios, eventos, encuestas y votos) siguen en PostgreSQL.

## Consistencia en multi-nodo

- La fuente autoritativa para cierre de evento, encuestas y votos es PostgreSQL.
- En despliegue multi-nodo puede haber desfases breves en vistas en vivo.
- Redis reduce las divergencias de estado efímero entre nodos, pero no convierte ese estado en histórico permanente.

## PubSub y tiempo real

- Los eventos de negocio se publican por tópicos de evento (`event:<id>`, `events:<id>`, `events:updates`, `poll:<id>`, etc.).
- Las actualizaciones de chat, estado y votos se propagan mediante PubSub y los procesos **LiveView** suscritos (no hay módulos Phoenix **Channel** propios en la capa web: el tiempo real va por LiveView + `Phoenix.LiveView.Socket`).

## Riesgos y límites actuales

- El Director es infraestructura de enrutamiento, no lógica de dominio.
- Redis mejora la coordinación del estado efímero del chat, pero no sustituye persistencia histórica de mensajes.

