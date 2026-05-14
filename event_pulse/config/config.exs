# Configuración de la aplicación y sus dependencias mediante el módulo `Config`.
#
# Este archivo se carga antes que cualquier dependencia y solo afecta a este proyecto.

# Configuración general de la aplicación
import Config

config :event_pulse,
  ecto_repos: [EventPulse.Repo],
  generators: [timestamp_type: :utc_datetime],
  chat_buffer_max: 15,
  chat_max_body_length: 500,
  auth_token_max_age: 7 * 24 * 60 * 60,
  redis_url: "redis://localhost:6379/0"

# Endpoint Phoenix
config :event_pulse, EventPulseWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: EventPulseWeb.ErrorHTML, json: EventPulseWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: EventPulse.PubSub,
  live_view: [signing_salt: "Ujre5k7p"]

# Correo (Swoosh)
#
# Por defecto usa el adaptador "Local" y guarda los correos en local.
# Puedes verlos en el navegador en `/dev/mailbox`.
#
# En producción conviene configurar otro adaptador en `config/runtime.exs`.
config :event_pulse, EventPulse.Mailer, adapter: Swoosh.Adapters.Local

# Logger de Elixir
config :logger,
  backends: [:console],
  level: :debug

config :logger, :console,
  format:
    "{\"timestamp\":\"$time\",\"level\":\"$level\",\"message\":\"$message\",\"metadata\":\"$metadata\"}\n",
  metadata: [:request_id, :module, :function]

# JSON en Phoenix (Jason)
config :phoenix, :json_library, Jason

# Configuración por entorno (debe permanecer al final para poder sobrescribir lo anterior)
import_config "#{config_env()}.exs"
