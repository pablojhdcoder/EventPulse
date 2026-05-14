# Diseño de arquitectura — EventPulse

## Descripción del sistema

EventPulse es una plataforma de eventos en vivo que permite a los usuarios seguir eventos en tiempo real, participar en votaciones y chatear con otros espectadores. El sistema está construido sobre Elixir/Phoenix con un enfoque reactivo y distribuido: en lugar del modelo petición-respuesta clásico, la UI se actualiza automáticamente mediante LiveView y PubSub cuando ocurre cualquier cambio en el servidor.

El sistema está diseñado para ejecutarse en varios nodos OTP en paralelo (réplicas Phoenix), conectados mediante Erlang Distribution cuando se configura el clúster (p. ej. **`CLUSTER_PEER_HOSTS`** y **`libcluster`** en la demo Docker, o **`DNSCluster`** según `DNS_CLUSTER_QUERY`). Eso permite escalar horizontalmente y repartir carga detrás del proxy **Director (NGINX)**.

## Descripción de los módulos principales y cómo se comunican

**Auth** gestiona el registro, login y sesiones de usuario. Expone las rutas de autenticación y protege las acciones sensibles (votar, crear eventos, cerrar eventos). Se integra con LiveView mediante cookies de sesión.

**Eventos** implementa el CRUD de eventos y gestiona sus estados (`programado → en_directo → finalizado`). Cuando un evento cambia de estado, emite un mensaje por PubSub que notifica a todos los LiveViews activos en tiempo real.

**Votaciones** es el módulo más complejo. Está organizado en torno al `VoteAggregator`, un GenServer que mantiene el recuento de votos en memoria para minimizar la latencia. Los votos se acumulan en una cola interna y se persisten en PostgreSQL en micro-lotes cada 500ms. Cada vez que llega un voto, se emite el recuento actualizado por PubSub en el canal `poll:#{poll_id}`, de forma que la UI refleja los resultados en tiempo real sin consultar la base de datos.

**Chat** implementa una sala de chat por evento con **LiveView** y **`Phoenix.PubSub`** (tópico `event:<id>`): el `GenServer` `EventPulse.Chat.EventRoom` serializa envío, escribe el buffer en **Redis** (Streams / últimos *N* mensajes) y hace *broadcast* del mensaje. Los mensajes recientes permiten historial al conectar; el chat queda desactivado cuando el evento pasa a `finalizado`.

**Phoenix.PubSub** (adaptador **PG2** en la demo distribuida) actúa como bus de mensajes entre procesos OTP y procesos **LiveView** (p. ej. `poll:<id>`, `event:<id>`, `events:updates`).

**Infraestructura OTP** — la aplicación arranca un árbol de supervisión que incluye **Redix**, `Phoenix.PubSub`, `EventRoom`, `VoteAggregator` (según `START_VOTE_AGGREGATOR`) y el endpoint Phoenix. El clúster entre réplicas usa **`libcluster`** con **`Cluster.Strategy.Epmd`** y la variable **`CLUSTER_PEER_HOSTS`** en Compose; además puede usarse **`DNSCluster`** según `DNS_CLUSTER_QUERY` en configuración. Los nodos comparten cookie y distribución Erlang para que los mensajes PubSub lleguen entre réplicas.

## Flujo de comunicación entre módulos

El navegador se conecta al endpoint Phoenix vía HTTP y WebSocket. LiveView gestiona la conexión persistente y suscribe cada vista a los tópicos PubSub relevantes (`poll:<id>`, `event:<id>` para sala de evento, `events:updates` para el catálogo). Cuando ocurre un voto, un mensaje de chat o un cambio de estado, el módulo correspondiente emite por PubSub y los LiveViews suscritos actualizan la UI sin polling explícito.
