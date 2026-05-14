import Config

# Base de datos de tests
#
# La variable `MIX_TEST_PARTITION` permite particionar tests en CI.
# Consulta `mix help test` para más información.

database_url =
  System.get_env("DATABASE_URL") ||
    "ecto://postgres:postgres@localhost:5432/event_pulse_test#{System.get_env("MIX_TEST_PARTITION")}"

config :event_pulse, EventPulse.Repo,
  url: database_url,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Claves sueltas para que `ecto.create` funcione sin `DATABASE_URL`
if !System.get_env("DATABASE_URL") do
  config :event_pulse, EventPulse.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    port: 5432,
    database: "event_pulse_test#{System.get_env("MIX_TEST_PARTITION")}"
end

config :event_pulse, EventPulseWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "oFWvECaj0n2ZA2nidHYDVlfoYZcWl5qbbf0GLoT9Pox320X2b6VCezpgNpwvmAmG",
  server: false

# En tests no se envían correos reales
config :event_pulse, EventPulse.Mailer, adapter: Swoosh.Adapters.Test

# Swoosh: sin cliente HTTP en tests
config :swoosh, :api_client, false

# Solo advertencias y errores en consola durante los tests
config :logger, level: :warning

# Persistencia síncrona de votos en tests (compatible con SQL Sandbox)
config :event_pulse, sync_persist: true

# Plugs inicializados en runtime para compilar tests más rápido
config :phoenix, :plug_init_mode, :runtime

# Orden estable de query params en rutas verificadas (asserts de URL)
config :phoenix,
  sort_verified_routes_query_params: true
