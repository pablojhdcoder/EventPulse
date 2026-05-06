defmodule EventPulseWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :event_pulse

  @session_options [
    store: :cookie,
    key: "_event_pulse_key",
    signing_salt: "kfO36dip",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]


  plug Plug.Static,
    at: "/assets",
    from: {:phoenix, "priv/static"},
    gzip: false

  plug Plug.Static,
    at: "/assets",
    from: {:phoenix_live_view, "priv/static"},
    gzip: false

  plug Plug.Static,
    at: "/",
    from: :event_pulse,
    gzip: not code_reloading?,
    only: EventPulseWeb.static_paths(),
    raise_on_missing_only: false

  if code_reloading? do
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :event_pulse
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug EventPulseWeb.Router
end
