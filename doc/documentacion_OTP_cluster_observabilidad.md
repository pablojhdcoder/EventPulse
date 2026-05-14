Este documento describe la infraestructura de `EventPulse` alineada con el **código actual**: OTP, formación de clúster en la demo Docker, agregación global de votos, chat con Redis y qué observamos en explotación.

## 1. ¿Qué es OTP y por qué importa?

OTP es la base del sistema. En `EventPulse` los procesos críticos arrancan bajo un **supervisor** raíz (`EventPulse.Supervisor`, estrategia `:one_for_one`).

- Si un hijo supervisionable falla, el supervisor puede reiniciarlo según su `:restart`.
- Esto favorece la tolerancia a fallos sin dispersar `try/rescue` por todo el dominio.

### Árbol de arranque relevante (resumen)

En `EventPulse.Application` conviven, entre otros:

- **Telemetry** y **Task.Supervisor** (tareas auxiliares).
- **Repositorio Ecto** (`EventPulse.Repo`).
- **Registry** (`EventPulse.EventRegistry`) y **DynamicSupervisor** (`EventPulse.EventSupervisor`) reservados para procesos OTP por evento; en el código vigente no se arrancan hijos bajo ese supervisor desde los contextos de dominio (el árbol OTP ya incluye el coordinador de chat global, abajo).
- **DNSCluster** (`DNSCluster`) con consulta configurable (`:dns_cluster_query` / `DNS_CLUSTER_QUERY`) para descubrimiento vía DNS cuando aplica.
- **libcluster** (`Cluster.Supervisor`) cuando está definido `CLUSTER_PEER_HOSTS`: estrategia **EPMD** entre los hostnames listados (demo Docker: `web1.local`, `web2.local`, `web3.local`).
- **VoteAggregator** (opcional por réplica): si `START_VOTE_AGGREGATOR` es distinto de `"false"`, el supervisor arranca el hijo `VoteAggregator`; `start_link/1` usa **`{:global, EventPulse.Votes.VoteAggregator}`**, de modo que solo existe **un** proceso con estado en el clúster. Si varias réplicas intentan arrancar el hijo a la vez, las que no ganan el registro global enlazan al PID del líder remoto. En `docker-compose.yml`, `web2` y `web3` llevan `START_VOTE_AGGREGATOR="false"`: **no** se añade el hijo al supervisor local (menos contienda al arranque); `cast_vote/3`, `cast_vote_for_poll/3` y `get_results/1` siguen resolviendo el nombre `:global` contra el proceso que vive en el nodo que sí arrancó el agregador (`web1` en la demo).
- **Redix** (cliente Redis) para el buffer de chat.
- **Phoenix.PubSub** (adaptador PG2) para difusión en tiempo real entre nodos del clúster.
- **`EventPulse.Chat.EventRoom`**: un **GenServer** nombrado que serializa envío de mensajes y lectura del histórico reciente (no mantiene estado de negocio en memoria; delega en Redis + PubSub).
- **Endpoint** Phoenix / Bandit.

No hay en la versión actual un `SocialFeeling.Worker` ni tabla `social_feeling_results`; el cierre de evento vive en el contexto `EventPulse.Events` (transacción BD + efectos Redis best-effort).

## 2. Clúster: cómo se comunican varios nodos

Hay **dos mecanismos complementarios** según despliegue:

1. **`libcluster` (EPMD)**  
   - Variable **`CLUSTER_PEER_HOSTS`**: lista separada por comas de hostnames de réplicas (p. ej. `web1.local,web2.local,web3.local`).
   - Todos los nodos deben compartir la misma **cookie Erlang** (`RELEASE_COOKIE` en la demo Docker).

2. **`DNSCluster`**  
   - Opcional: `DNS_CLUSTER_QUERY` en `runtime.exs`; útil cuando Phoenix resuelve vecinos por DNS en otros entornos.

Dentro del clúster:

- **PubSub** replica los broadcasts entre nodos para tópicos como `event:<id>` o `poll:<id>`.
- **`VoteAggregator`** con registro **`:global`** garantiza **un solo** proceso de agregación en todo el clúster; las réplicas que no ganan enlazan al líder remoto en lugar de duplicar estado (véase `VoteAggregator.start_link/1`).

### Demo Docker (réplicas + Director)

**Cómo levantar o parar el stack**, URLs y seed en release: únicamente en [`event_pulse/README.md`](../event_pulse/README.md) (sección *Demo distribuida*).

En cuanto a esta documentación OTP/clúster: la demo incluye **PostgreSQL**, **Redis**, tareas **migrate** y **seed**, réplicas **`web1`–`web3`** y **Director** (nginx). En `docker-compose.yml`, **`START_VOTE_AGGREGATOR`** está en `"true"` solo en **web1**; en web2 y web3 es `"false"` para evitar contiendas innecesarias al registrar el proceso global.

## 3. Qué observamos y por qué

Observabilidad: **métricas Telemetry**, **logs** y, en desarrollo, **LiveDashboard**.

### Métricas

`EventPulseWeb.Telemetry` define medidas estándar de Phoenix/Ecto (duración de endpoints, consultas BD, etc.) y eventos propios (p. ej. `[:event_pulse, :vote, :cast]` al emitir un voto hacia el agregador).

### Logs

Útiles para trazar errores de Redis al cerrar eventos (`Events.run_close_side_effects/1`), fallos de persistencia en el agregador de votos (cola `pending`), y tráfico HTTP/WebSocket en producción.

### LiveDashboard (solo desarrollo)

- Ruta típica: `/dev/dashboard` cuando `dev_routes` está activo.
- Muestra métricas y supervisores en tiempo real mientras se desarrolla.

## 4. Votos

Flujo actual:

1. El LiveView (u otro cliente) invoca el contexto de votos; los votos en vivo pasan por **`VoteAggregator`** (memoria + micro-lotes hacia BD).
2. El registro **global** asegura recuentos coherentes entre nodos.
3. Si falla un `Repo.insert`, los votos afectados quedan en **`pending`** y se reintentan en el siguiente ciclo del GenServer.

## 5. Chat

- **Histórico reciente**: `EventPulse.ChatBuffer` sobre **Redis** (streams / lectura de últimos N mensajes).
- **Tiempo real**: `Phoenix.PubSub.broadcast/3` al tópico `event:<event_id>`.
- **Coordinación**: `EventPulse.Chat.EventRoom` (GenServer) valida y ordena las operaciones de envío y consulta de mensajes recientes.

Al **finalizar** el evento, se llama a `ChatBuffer.delete_buffer/1` para esa sala de forma **best-effort**; un fallo de Redis no revierte el cierre en PostgreSQL.

## 6. Operación y diagnóstico

Comprobar de forma habitual:

- PostgreSQL y Redis accesibles desde las réplicas.
- En multi-nodo: que `CLUSTER_PEER_HOSTS` y `RELEASE_COOKIE` coincidan y que los tres servicios web estén sanos antes de exponer el Director.
- Si los votos parecen inconsistentes entre nodos: comprobar conectividad del clúster (`CLUSTER_PEER_HOSTS`, `RELEASE_COOKIE`) y que el registro **`:global`** resuelva (en la demo Docker solo `web1` arranca el hijo del agregador para evitar contiendas al arranque; si **todas** las réplicas arrancan el hijo, OTP sigue eligiendo un único líder, pero puede haber más ruido en logs al competir por el nombre global).

## 7. Por qué esta base encaja con la asignatura

- **OTP** centraliza tolerancia a fallos y supervisión.
- **Clúster + `:global`** muestran distribución real de procesos, no solo balanceo HTTP.
- **Redis + PubSub** separan estado efímero del chat del modelo relacional de votos y eventos.
- La observabilidad (**Telemetry**, logs, dashboard en dev) apoya la defensa de tácticas de monitorización y depuración.
