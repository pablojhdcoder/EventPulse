# EventPulse

Aplicación Phoenix con LiveView para eventos en directo: listado y detalle, chat en tiempo real (PubSub y buffer en Redis), votación en vivo y, al cerrar, encuestas cerradas y **resumen de votos** en la interfaz. No hay “social feeling” persistido ni API REST pública de eventos.

Documentación de arquitectura, ADR e índice: [`../doc/README.md`](../doc/README.md).

---

## Arranque y operación (referencia única)

Aquí se concentran **todas** las instrucciones para compilar, ejecutar en local, levantar la demo en Docker y lanzar tests. El resto de documentos del repositorio solo enlaza a esta sección.

### Requisitos

- **Elixir / Erlang** compatibles con [`mix.exs`](mix.exs).
- **PostgreSQL** accesible según el entorno (`config/dev.exs` en desarrollo; `DATABASE_URL` en producción / release, véase `config/runtime.exs`).
- **Redis** en la URL configurada (por defecto `redis://localhost:6379/0` vía aplicación); el buffer de chat usa **Redix** y debe poder conectar.

### 1. Desarrollo local (una instancia)

**Directorio de trabajo:** este directorio (`event_pulse/`).

```bash
mix setup
mix phx.server
```

**URLs habituales:**

- `http://localhost:4000/` — listado de eventos
- `http://localhost:4000/events/:id` — detalle con chat y votación
- `http://localhost:4000/dev/dashboard` — LiveDashboard si `dev_routes` está activo en `config/dev.exs`

Asegúrate de que PostgreSQL y Redis coinciden con la configuración que uses (por defecto, usuario/clave/host en `config/dev.exs`).

### 2. Demo distribuida (Docker Compose)

**Directorio de trabajo:** la **raíz del repositorio** (donde está `docker-compose.yml`, un nivel por encima de `event_pulse/`).

```bash
docker compose up -d --build
```

Queda levantado PostgreSQL, Redis, tareas one-shot `migrate` y `seed`, tres réplicas de la app (`web1`–`web3`) y el **Director** (NGINX) como entrada única. La demo publica la aplicación en **`http://localhost:8080`** (HTTP y WebSocket balanceados entre réplicas).

### 3. Tests

**Directorio de trabajo:** `event_pulse/`.

- `mix test` usa `config/test.exs`: por defecto PostgreSQL en **`localhost:5432`** o lo que definas en **`DATABASE_URL`**.
- Para PostgreSQL en Docker (mapeo típico al puerto **5433** del host con `docker-compose.test.yml`), existe el alias:

```bash
mix test.docker
```

Antes de `mix test.docker`, define por ejemplo:

`DATABASE_URL=ecto://postgres:postgres@localhost:5433/event_pulse_test`

(ajusta usuario, contraseña o nombre de BD si los cambiaste en `docker-compose.test.yml`).

### Configuración

- Desarrollo: valores por defecto en `config/dev.exs`.
- Producción / release: `DATABASE_URL`, `SECRET_KEY_BASE`, Redis, clúster, etc. en `config/runtime.exs` y variables documentadas allí.

---

## Funcionalidades implementadas

- **Catálogo de eventos**: listado en `/` y detalle en `/events/:id`.
- **Estados de evento**: `programado`, `en_directo` y `finalizado`.
- **Chat en tiempo real**: envío y recepción por evento con PubSub.
- **Buffer de chat**: mensajes recientes al entrar en sala, respaldado en Redis.
- **Votación en vivo**: voto por usuario en directo y recuento actualizado.
- **Cierre de evento**: encuestas cerradas, sin votos posteriores; limpieza best-effort del buffer Redis; **resumen** por encuesta en la UI (sin indicador SF en base de datos).
- **Sesión demo**: usuario de demostración en sesión para pruebas locales.
