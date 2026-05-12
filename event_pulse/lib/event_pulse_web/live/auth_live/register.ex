defmodule EventPulseWeb.AuthLive.Register do
  use EventPulseWeb, :live_view

  # ---------------------------------------------------------------------------
  # Mount — inicializa el formulario de registro
  # ---------------------------------------------------------------------------
  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:csrf_token, Phoenix.Controller.get_csrf_token())}
  end

  # ---------------------------------------------------------------------------
  # Render — HTML del formulario de registro
  # ---------------------------------------------------------------------------
  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-sm mx-auto my-16 p-8 bg-white rounded-lg shadow-sm">
      <h1 class="text-2xl font-bold text-center mb-6">Crear cuenta</h1>

      <%!-- Mensaje de error --%>
      <div :if={Phoenix.Flash.get(@flash, :error)} class="bg-red-100 text-red-800 px-3 py-2 rounded text-sm mb-4">
        {Phoenix.Flash.get(@flash, :error)}
      </div>

      <form method="post" action={~p"/register"} class="flex flex-col gap-4">
        <input type="hidden" name="_csrf_token" value={@csrf_token} />

        <%!-- Username --%>
        <div>
          <label class="block text-sm font-semibold mb-1">Usuario</label>
          <input
            type="text"
            name="username"
            placeholder="Tu nombre de usuario"
            required
            minlength="3"
            class="w-full px-3 py-2 border border-slate-300 rounded text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
        </div>

        <%!-- Email --%>
        <div>
          <label class="block text-sm font-semibold mb-1">Email</label>
          <input
            type="email"
            name="email"
            placeholder="tu@email.com"
            required
            class="w-full px-3 py-2 border border-slate-300 rounded text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
        </div>

        <%!-- Contraseña --%>
        <div>
          <label class="block text-sm font-semibold mb-1">Contraseña</label>
          <input
            type="password"
            name="password"
            placeholder="Mínimo 6 caracteres"
            required
            minlength="6"
            class="w-full px-3 py-2 border border-slate-300 rounded text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
        </div>

        <%!-- Confirmar contraseña --%>
        <div>
          <label class="block text-sm font-semibold mb-1">Confirmar contraseña</label>
          <input
            type="password"
            name="password_confirmation"
            placeholder="Repite tu contraseña"
            required
            minlength="6"
            class="w-full px-3 py-2 border border-slate-300 rounded text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
        </div>

        <%!-- Botón de registro --%>
        <button
          type="submit"
          class="bg-indigo-600 hover:bg-indigo-700 text-white border-none rounded py-2 text-sm font-semibold cursor-pointer transition"
        >
          Registrarse
        </button>
      </form>

      <%!-- Enlace al login --%>
      <p class="text-center mt-4 text-sm text-slate-600">
        ¿Ya tienes cuenta?
        <a href={~p"/login"} class="text-indigo-600 font-semibold hover:underline">Inicia sesión</a>
      </p>
    </div>
    """
  end
end
