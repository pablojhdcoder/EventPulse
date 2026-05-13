# EventPulse

Aplicación Phoenix con LiveView para eventos en directo. El sistema implementa listado de eventos, detalle por evento, chat en tiempo real (PubSub + buffer en Redis), votación en vivo y, al cerrar, encuestas cerradas y **recap de votos** en la interfaz; no hay Social Feeling persistido ni API REST pública de eventos.

Para contexto global y arquitectura, consultar `../doc/README.md`.

## Funcionalidades implementadas

- **Catálogo de eventos**: listado en `/` y detalle en `/events/:id`.
- **Estados de evento**: `programado`, `en_directo` y `finalizado`.
- **Chat en tiempo real**: envío y recepción de mensajes por evento con PubSub.
- **Buffer de chat**: recuperación de mensajes recientes al entrar en una sala, respaldado en Redis.
- **Votación en vivo**: voto por usuario en eventos en directo y recuento actualizado.
- **Cierre de evento**: al pasar a `finalizado`, se cierran las encuestas, se dejan de aceptar votos y mensajes de chat acordes al estado; se intenta limpiar el buffer Redis del evento. En la UI se muestra el **recap** de recuentos por pregunta (no un indicador SF agregado en base de datos).
- **Sesión demo**: identificación de usuario de demostración en sesión para pruebas locales.

## Requisitos

- Elixir/Erlang compatibles con el `mix.exs` del proyecto.
- PostgreSQL accesible localmente o por `DATABASE_URL`.

## Configuración

- En desarrollo, los valores por defecto están en `config/dev.exs`.
- En runtime, producción usa `DATABASE_URL`, `SECRET_KEY_BASE` y variables relacionadas definidas en `config/runtime.exs`.

## Ejecución local

Desde `event_pulse/`:

```bash
mix setup
mix phx.server
```

Accesos principales:

- `http://localhost:4000/` listado de eventos.
- `http://localhost:4000/events/:id` detalle con chat y votación.
- `http://localhost:4000/dev/dashboard` LiveDashboard (si `dev_routes` está activo).

## Ejecución distribuida de demo (Docker Compose)

Desde la raíz del repositorio:

```bash
docker compose up -d --build
```

Esto levanta PostgreSQL, tres réplicas de la aplicación y un Director NGINX como entrada única (`http://localhost:8080`).
En este modo también se levanta Redis para el estado efímero compartido del chat.

Para seed en entorno release, usar por ejemplo:

```bash
docker compose exec web1 bin/event_pulse rpc "EventPulse.Release.seed"
```

