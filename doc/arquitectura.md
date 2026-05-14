# Diseño de arquitectura — EventPulse

## Descripción del sistema

EventPulse es una plataforma de eventos en vivo que permite a los usuarios seguir eventos en tiempo real, participar en votaciones y chatear con otros espectadores. El sistema está construido sobre Elixir/Phoenix con un enfoque reactivo y distribuido: en lugar del modelo petición-respuesta clásico, la UI se actualiza automáticamente mediante LiveView y PubSub cuando ocurre cualquier cambio en el servidor.

El sistema está diseñado para ejecutarse en un clúster de varios nodos OTP, todos conectados mediante Erlang Distribution y coordinados vía DNS discovery. Esto permite escalar horizontalmente y mantener alta disponibilidad.

## Descripción de los módulos principales y cómo se comunican

**Auth** gestiona el registro, login y sesiones de usuario. Expone las rutas de autenticación y protege las acciones sensibles (votar, crear eventos, cerrar eventos). Se integra con LiveView mediante cookies de sesión.

**Eventos** implementa el CRUD de eventos y gestiona sus estados (`programado → en_directo → finalizado`). Cuando un evento cambia de estado, emite un mensaje por PubSub que notifica a todos los LiveViews activos en tiempo real.

**Votaciones** es el módulo más complejo. Está organizado en torno al `VoteAggregator`, un GenServer que mantiene el recuento de votos en memoria para minimizar la latencia. Los votos se acumulan en una cola interna y se persisten en PostgreSQL en micro-lotes cada 500ms. Cada vez que llega un voto, se emite el recuento actualizado por PubSub en el canal `poll:#{poll_id}`, de forma que la UI refleja los resultados en tiempo real sin consultar la base de datos.

**Chat** implementa una sala de chat por evento usando Phoenix Channels y PubSub. Los mensajes recientes se almacenan en un buffer en Redis con TTL, lo que permite a los usuarios que se conectan tarde recuperar el historial reciente. El chat se deshabilita automáticamente cuando el evento pasa a `finalizado`.

**Social Feeling** es un worker que se activa cuando un evento cierra. Calcula el sentimiento social agregando los resultados de votaciones y actividad del chat, persiste el resultado final y lo muestra en la vista de detalle del evento.

**Infraestructura OTP** — la aplicación arranca un árbol de supervisión que incluye el `VoteAggregator`, el supervisor de chat y el endpoint Phoenix. El clúster se forma automáticamente mediante `dns_cluster` usando la variable de entorno `DNS_CLUSTER_QUERY`. Todos los nodos comparten la misma `ERL_COOKIE` y se comunican mediante Erlang Distribution para distribuir mensajes PubSub entre réplicas.

## Flujo de comunicación entre módulos

El navegador se conecta al endpoint Phoenix vía HTTP y WebSocket. LiveView gestiona la conexión persistente y suscribe cada vista a los canales PubSub relevantes (`poll:#{id}`, `event:#{id}`, `chat:#{id}`). Cuando ocurre un evento (un voto, un mensaje de chat, un cambio de estado), el módulo correspondiente emite por PubSub y todos los LiveViews suscritos actualizan la UI de forma automática sin que el cliente tenga que hacer ninguna petición.
