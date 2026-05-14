# Diseño de arquitectura — EventPulse

## Descripción del sistema

EventPulse es una plataforma de eventos en vivo que permite a los usuarios seguir eventos en tiempo real, participar en votaciones y chatear con otros espectadores. El sistema está construido sobre Elixir/Phoenix con un enfoque reactivo y distribuido: en lugar del modelo petición-respuesta clásico, la UI se actualiza automáticamente mediante LiveView y PubSub cuando ocurre cualquier cambio en el servidor.

El sistema está diseñado para ejecutarse en varios nodos OTP en paralelo (réplicas Phoenix), conectados mediante Erlang Distribution cuando se configura el clúster (p. ej. **`CLUSTER_PEER_HOSTS`** y **`libcluster`** en la demo Docker, o **`DNSCluster`** según `DNS_CLUSTER_QUERY`). Eso permite escalar horizontalmente y repartir carga detrás del proxy **Director (NGINX)**.

## Objetivo y topología de ejecución

EventPulse sigue un esquema cliente-servidor distribuido:

- clientes ligeros (participantes y administradores);
- un componente de entrada única (Director) para enrutar tráfico;
- varias réplicas de la aplicación Phoenix;
- una base de datos compartida para la persistencia.

Hay dos modos: **desarrollo** (una instancia con Mix) y **demo distribuida** (varias réplicas Phoenix, PostgreSQL, Redis y Director NGINX vía Docker Compose). Los comandos, directorios de trabajo, URLs y tests están descritos **solo** en [`event_pulse/README.md`](../event_pulse/README.md).

A nivel de contenedores/servicios, la demo agrupa `web1`, `web2`, `web3`, `postgres`, `redis` y `director`; el Director actúa como entrada única (puerto publicado en `docker-compose.yml`, habitualmente **8080** en el host). En [`doc/c4-contexto-contenedores.md`](c4-contexto-contenedores.md), las vistas de contenedor resumen **web2** y **web3** en una sola caja **webN**; en ejecución siguen siendo servicios distintos.

## Alcance funcional en la implementación actual

En `event_pulse/` conviven estas capacidades:

- **Eventos**: listado y detalle de eventos, gestión de estados.
- **Chat en vivo**: sala por evento con difusión en tiempo real.
- **Votación en vivo**: voto por usuario y recuento actualizado.
- **Cierre**: transición a `finalizado`, cierre de encuestas en base de datos, notificación por PubSub y limpieza best-effort del buffer de chat en Redis.
- **Historial en interfaz**: en evento finalizado, la LiveView muestra el recap de votos por encuesta (sin tabla ni indicador agregado tipo Social Feeling en PostgreSQL).

## Módulos principales y cómo se comunican

**Auth** gestiona el registro, login y sesiones de usuario. Expone las rutas de autenticación y protege las acciones sensibles (votar, crear eventos, cerrar eventos). Se integra con LiveView mediante cookies de sesión.

**Eventos** implementa el CRUD de eventos y gestiona sus estados (`programado → en_directo → finalizado`). Cuando un evento cambia de estado, emite un mensaje por PubSub que notifica a todos los LiveViews activos en tiempo real.

**Votaciones** es el módulo más complejo. Está organizado en torno al `VoteAggregator`, un GenServer que mantiene el recuento de votos en memoria para minimizar la latencia. Los votos se acumulan en una cola interna y se persisten en PostgreSQL en micro-lotes cada 500ms. Cada vez que llega un voto, se emite el recuento actualizado por PubSub en el canal `poll:#{poll_id}`, de forma que la UI refleja los resultados en tiempo real sin consultar la base de datos.

**Chat** implementa una sala de chat por evento con **LiveView** y **`Phoenix.PubSub`** (tópico `event:<id>`): el `GenServer` `EventPulse.Chat.EventRoom` serializa envío, escribe el buffer en **Redis** (Streams / últimos *N* mensajes) y hace *broadcast* del mensaje. Los mensajes recientes permiten historial al conectar; el chat queda desactivado cuando el evento pasa a `finalizado`.

**Phoenix.PubSub** (adaptador **PG2** en la demo distribuida) actúa como bus de mensajes entre procesos OTP y procesos **LiveView** (p. ej. `poll:<id>`, `event:<id>`, `events:updates`).

**Infraestructura OTP** — la aplicación arranca un árbol de supervisión que incluye **Redix**, `Phoenix.PubSub`, `EventRoom`, `VoteAggregator` (según `START_VOTE_AGGREGATOR`) y el endpoint Phoenix. El clúster entre réplicas usa **`libcluster`** con **`Cluster.Strategy.Epmd`** y la variable **`CLUSTER_PEER_HOSTS`** en Compose; además puede usarse **`DNSCluster`** según `DNS_CLUSTER_QUERY` en configuración. Los nodos comparten cookie y distribución Erlang para que los mensajes PubSub lleguen entre réplicas.

## Flujo de comunicación entre módulos

El navegador se conecta al endpoint Phoenix vía HTTP y WebSocket. LiveView gestiona la conexión persistente y suscribe cada vista a los tópicos PubSub relevantes (`poll:<id>`, `event:<id>` para sala de evento, `events:updates` para el catálogo). Cuando ocurre un voto, un mensaje de chat o un cambio de estado, el módulo correspondiente emite por PubSub y los LiveViews suscritos actualizan la UI sin polling explícito.

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

Los eventos de negocio se publican por tópicos de evento (`event:<id>`, `events:updates`, `poll:<id>`, etc.). Las actualizaciones de chat, estado y votos se propagan mediante PubSub y los procesos **LiveView** suscritos. No hay módulos Phoenix **Channel** propios en la capa web: el tiempo real va por LiveView + `Phoenix.LiveView.Socket`.

## Riesgos y límites actuales

- El Director es infraestructura de enrutamiento, no lógica de dominio.
- Redis mejora la coordinación del estado efímero del chat, pero no sustituye persistencia histórica de mensajes.
