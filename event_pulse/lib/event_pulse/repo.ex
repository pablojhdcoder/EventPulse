defmodule EventPulse.Repo do
  use Ecto.Repo,
    otp_app: :event_pulse,
    adapter: Ecto.Adapters.Postgres
end
