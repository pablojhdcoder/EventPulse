defmodule EventPulseWeb.AuthLive.Login do
  use EventPulseWeb, :live_view

  @moduledoc """
  Componente LiveView encargado de mostrar el formulario de login y manejar la interacción del usuario con dicho formulario.
  Se encarga de generar el token CSRF para proteger el formulario, mostrar mensajes de error (ej. "email o contraseña incorrectos") y enviar los datos al controlador AuthController para que procese el login.
  """

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:email, "")
     |> assign(:csrf_token, Phoenix.Controller.get_csrf_token())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="ep-auth-shell">
      <.card class="ep-card--elevated ep-auth-card">
        <h1 class="ep-auth-title">Iniciar sesión</h1>
        <p class="ep-auth-subtitle">
          Entra en EventPulse para gestionar eventos, votar y seguir el chat en directo.
        </p>

        <.alert :if={Phoenix.Flash.get(@flash, :error)} kind={:error} style="margin-bottom:1rem;">
          {Phoenix.Flash.get(@flash, :error)}
        </.alert>

        <form method="post" action={~p"/login"} class="ep-stack">
          <input type="hidden" name="_csrf_token" value={@csrf_token} />

          <.input
            id="login-email"
            type="email"
            name="email"
            label="Email"
            value={@email}
            placeholder="tu@email.com"
            autocomplete="email"
            required
          />

          <.input
            id="login-password"
            type="password"
            name="password"
            label="Contraseña"
            placeholder="Tu contraseña"
            autocomplete="current-password"
            required
            minlength="8"
          />

          <.button type="submit" variant="primary" class="ep-button--full">
            Entrar
          </.button>
        </form>

        <p class="ep-auth-footer">
          ¿No tienes cuenta?
          <a href={~p"/register"}>Crea una cuenta</a>
        </p>
      </.card>
    </main>
    """
  end
end
