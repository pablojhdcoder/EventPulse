defmodule EventPulseWeb.Router do
  use EventPulseWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug EventPulseWeb.Plugs.EnsureDemoUserId # Asegura que cada visitante tenga un user_id único en la sesión, incluso si no se ha registrado
    plug :fetch_live_flash
    plug :put_root_layout, html: {EventPulseWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # El pipeline :browser_auth incluye el plug RequireAuth que verifica si el usuario está autenticado antes de permitir el acceso a ciertas rutas.
  pipeline :browser_auth do
    plug EventPulseWeb.Plugs.RequireAuth
  end

  scope "/", EventPulseWeb do
    pipe_through :browser

    # Rutas de autenticación
    live "/login", AuthLive.Login, :index #Muestra el formulario de Login
    post "/login", AuthController, :login #Procesa el login
    live "/register", AuthLive.Register, :index #Muestra el formulario de Registro
    post "/register", AuthController, :register #Procesa el Registro
    delete "/logout", AuthController, :logout #Cierra sesión
  end

  scope "/", EventPulseWeb do
    pipe_through [:browser, :browser_auth]

    # Rutas protegidas
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
