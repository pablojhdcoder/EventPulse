# Infraestructura OTP, Clúster y Observabilidad

## 1. Estrategia de clúster

EventPulse forma clúster OTP usando el paquete `dns_cluster` para descubrimiento de nodos.

- Se habilita mediante la variable de entorno `DNS_CLUSTER_QUERY`.
- En Docker Compose con múltiples réplicas, el servicio se puede escalar con `docker compose up --scale app=2`.
- Cada nodo arranca con un nombre Erlang único bajo el mismo cookie: `event_pulse_*`.
- Si el despliegue no define `DNS_CLUSTER_QUERY`, la aplicación arranca en modo local sin intentar formar clúster.

### Distribución final aplicada

La aplicación aprovecha:

- `Phoenix.PubSub` para difusión de eventos y votaciones.
- `:global` para registrar el agregador de votos como singleton global (`EventPulse.Votes.VoteAggregator`).
- `DNSCluster` para detectar otros nodos en el mismo dominio de servicio.

> Nota: `Horde` no se usa en este alcance porque la lógica actual de la aplicación gestiona procesos críticos con supervisión local y una única instancia global de aggregador. Si se requiere reparto de cargas y replicación de procesos, `Horde` es la siguiente capa natural.

## 2. Supervisión de procesos críticos

La aplicación ahora arranca con estos elementos clave:

- `EventPulseWeb.Telemetry` (telemetría y métricas)
- `Task.Supervisor` para persistencia asíncrona de votos
- `EventPulse.Chat.Supervisor` con:
  - `EventPulse.Chat.RoomRegistry`
  - `EventPulse.Chat.RoomSupervisor`
- `EventPulse.Votes.VoteAggregator` como proceso global singleton
- `DNSCluster` para descubrimiento de nodos
- `Phoenix.PubSub` para distribución de mensajes entre nodos

## 3. Observabilidad mínima operativa

### Métricas clave

Se instrumentaron métricas de Telemetry para:

- Peticiones Phoenix (`endpoint`, `router_dispatch`, `channel_handled_in`)
- Latencias de consulta a la base de datos
- Estado de la VM (`memory`, `run_queue_lengths`)
- Conteo de votos emitidos (`event_pulse.vote.cast.count`)
- Persistencia de votos (`event_pulse.vote.persist.count`)
- Mensajes almacenados en sala de chat (`event_pulse.chat.message.stored`)

### Logging estructurado

El logger está configurado para emitir registros con metadatos JSON-like, incluyendo:

- `timestamp`
- `level`
- `message`
- `metadata` con `request_id`, `module` y `function`

### Diagnóstico

- LiveDashboard queda disponible en desarrollo en `/dev/dashboard`.
- Telemetry Console Reporter imprime métricas periódicas en la salida estándar.

## 4. Despliegue con Docker

### Construir la imagen

Desde la raíz del repositorio:

```bash
cd event_pulse
docker build -t event_pulse_app .
```

### Arrancar en modo demo con 2 réplicas

Desde la raíz del repositorio:

```bash
docker compose up --build --scale app=2
```

El servicio `app` expone el puerto `4000` y usa `DATABASE_URL` para la conexión a PostgreSQL.

### Ejecutar tests con Docker

Los tests están configurados para usar automáticamente PostgreSQL en Docker:

```bash
cd event_pulse
mix test
```

Esto levanta automáticamente la base de datos de test en el puerto 5433 del host, ejecuta los tests y la detiene al finalizar.

### Variables importantes

- `PHX_SERVER=true`
- `DATABASE_URL=ecto://postgres:postgres@db/event_pulse_dev`
- `SECRET_KEY_BASE` debe ser único y seguro en producción
- `DNS_CLUSTER_QUERY=app`
- `CLUSTER_PEER_HOSTS` (demo Docker en la raíz del repo): lista `web1.local,web2.local,...`; si está definida, el release usa **`RELEASE_DISTRIBUTION=name`** para que `libcluster` (Epmd) y **PubSub PG2** funcionen entre réplicas.
- `RELEASE_COOKIE` / `ERL_COOKIE` alineados con el `cookie` del release

## 5. Procedimiento de operación

1. Asegurar que PostgreSQL está disponible y sano.
2. Arrancar los nodos con `PHX_SERVER=true` y `DNS_CLUSTER_QUERY` configurado.
3. Verificar que los nodos se ven entre sí a través de DNS y que `DNSCluster` forma el clúster.
4. Usar logs JSON y métricas de consola para analizar la salud y el comportamiento.
5. Monitorizar `EventPulse.Votes.VoteAggregator` y `EventPulse.Chat.Supervisor` como procesos críticos.

## 6. Notas de arquitectura

- El componente de votos mantiene consistencia eventual en memoria y escritura asíncrona en PostgreSQL.
- Las salas de chat se modelan como procesos con buffer de mensajes recientes y reinicio supervisado.
- La arquitectura está lista para extenderse hacia un enfoque distribuido más avanzado si se incorpora `Horde` o `libcluster`.
