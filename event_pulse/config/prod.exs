import Config

config :event_pulse, EventPulseWeb.Endpoint, force_ssl: false

# Cliente HTTP de Swoosh
config :swoosh, api_client: Swoosh.ApiClient.Req

# Sin almacenamiento local de Swoosh en memoria
config :swoosh, local: false

# Nivel de log en producción
config :logger, level: :info

# La configuración en runtime (variables de entorno, secretos) está en `config/runtime.exs`.
