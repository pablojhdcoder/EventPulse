import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.

database_url =
  System.get_env("DATABASE_URL") ||
    "ecto://postgres:postgres@localhost:5433/event_pulse_test#{System.get_env("MIX_TEST_PARTITION")}"

config :event_pulse, EventPulse.Repo,
  url: database_url,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Also provide individual keys for ecto.create to work
if !System.get_env("DATABASE_URL") do
  config :event_pulse, EventPulse.Repo,
    username: "postgres",
    password: "postgres",
    hostname: "localhost",
    port: 5433,
    database: "event_pulse_test#{System.get_env("MIX_TEST_PARTITION")}"
end
config :event_pulse, EventPulseWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "oFWvECaj0n2ZA2nidHYDVlfoYZcWl5qbbf0GLoT9Pox320X2b6VCezpgNpwvmAmG",
  server: false

# In test we don't send emails
config :event_pulse, EventPulse.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Sync persistence in tests to work with SQL sandbox
config :event_pulse, sync_persist: true

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
