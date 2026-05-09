defmodule EventPulseWeb.Router do
  use EventPulseWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {EventPulseWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", EventPulseWeb do
    pipe_through :browser

    live "/events", EventLive.Index, :index
    live "/events/new", EventLive.Form, :new
    live "/events/:id", EventLive.Show, :show
    live "/events/:id/edit", EventLive.Form, :edit
  end

  scope "/api", EventPulseWeb do
    pipe_through :api
    resources "/events", EventController, except: [:new, :edit]
    put "/events/:id/status", EventController, :update_status
  end

  if Application.compile_env(:event_pulse, :dev_routes) do
    import Phoenix.LiveDashboard.Router
    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]
      live_dashboard "/dashboard", metrics: EventPulseWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end