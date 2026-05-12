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

  pipeline :browser_auth do
    plug EventPulseWeb.Plugs.RequireAuth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", EventPulseWeb do
    pipe_through :browser

    live "/login", AuthLive.Login, :index
    post "/login", AuthController, :login
    live "/register", AuthLive.Register, :index
    post "/register", AuthController, :register
    delete "/logout", AuthController, :logout
  end

  scope "/api", EventPulseWeb do
    pipe_through :api

    resources "/events", EventController, except: [:new, :edit]
    put "/events/:id/status", EventController, :update_status
  end

  scope "/", EventPulseWeb do
    pipe_through [:browser, :browser_auth]

    live "/", EventLive.Index, :index
    live "/events", EventLive.Index, :index
    live "/events/new", EventLive.Form, :new
    live "/events/:id/edit", EventLive.Form, :edit
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
