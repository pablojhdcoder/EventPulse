defmodule EventPulseWeb.AuthLive.Register do
  use EventPulseWeb, :live_view

  @moduledoc """
  Componente LiveView encargado de mostrar el formulario de registro y manejar la interacción del usuario con
  dicho formulario. Se encarga de generar el token CSRF para proteger el formulario, mostrar mensajes de error (ej. "email ya registrado") y enviar los datos al controlador AuthController para que procese el registro.
  """

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:csrf_token, Phoenix.Controller.get_csrf_token())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="ep-auth-shell">
      <.card class="ep-card--elevated ep-auth-card">
        <h1 class="ep-auth-title">Crear cuenta</h1>
        <p class="ep-auth-subtitle">
          Regístrate para participar en eventos, votar y escribir en salas en directo.
        </p>

        <.alert :if={Phoenix.Flash.get(@flash, :error)} kind={:error} style="margin-bottom:1rem;">
          {Phoenix.Flash.get(@flash, :error)}
        </.alert>

        <form method="post" action={~p"/register"} class="ep-stack">
          <input type="hidden" name="_csrf_token" value={@csrf_token} />

          <.input
            id="register-username"
            type="text"
            name="username"
            label="Usuario"
            placeholder="Tu nombre de usuario"
            autocomplete="username"
            required
            minlength="3"
            maxlength="20"
          />

          <.input
            id="register-email"
            type="email"
            name="email"
            label="Email"
            placeholder="tu@email.com"
            autocomplete="email"
            required
          />

          <.input
            id="register-password"
            type="password"
            name="password"
            label="Contraseña"
            placeholder="Mayúsculas, minúsculas, número y símbolo"
            autocomplete="new-password"
            required
            minlength="8"
          />

          <.input
            id="register-password-confirmation"
            type="password"
            name="password_confirmation"
            label="Confirmar contraseña"
            placeholder="Repite tu contraseña"
            autocomplete="new-password"
            required
            minlength="8"
          />

          <.button type="submit" variant="primary" class="ep-button--full">
            Crear cuenta
          </.button>
        </form>

        <p class="ep-auth-footer">
          ¿Ya tienes cuenta?
          <a href={~p"/login"}>Inicia sesión</a>
        </p>
      </.card>
    </main>
    """
  end
end
