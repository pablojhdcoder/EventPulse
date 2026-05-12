# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :event_pulse,
  ecto_repos: [EventPulse.Repo],
  generators: [timestamp_type: :utc_datetime],
  chat_buffer_max: 15,
  chat_max_body_length: 500,
  auth_token_max_age: 7 * 24 * 60 * 60,
  redis_url: "redis://localhost:6379/0"

# Configure the endpoint
config :event_pulse, EventPulseWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: EventPulseWeb.ErrorHTML, json: EventPulseWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: EventPulse.PubSub,
  live_view: [signing_salt: "Ujre5k7p"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :event_pulse, EventPulse.Mailer, adapter: Swoosh.Adapters.Local

# Configure Elixir's Logger
config :logger,
  backends: [:console],
  level: :debug

config :logger, :console,
  format:
    "{\"timestamp\":\"$time\",\"level\":\"$level\",\"message\":\"$message\",\"metadata\":\"$metadata\"}\n",
  metadata: [:request_id, :module, :function]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
