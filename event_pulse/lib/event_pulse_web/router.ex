defmodule EventPulseWeb.Router do
  use EventPulseWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug EventPulseWeb.Plugs.EnsureDemoUserId
    plug :fetch_live_flash
    plug :put_root_layout, html: {EventPulseWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", EventPulseWeb do
    pipe_through :browser

    live "/", EventLive.Index, :index
    live "/events/:id", EventLive.Show, :show
  end

  if Application.compile_env(:event_pulse, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: EventPulseWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
