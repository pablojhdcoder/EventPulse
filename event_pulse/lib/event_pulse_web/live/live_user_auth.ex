defmodule EventPulseWeb.LiveUserAuth do
  @moduledoc """
  `on_mount` para LiveViews detrás de `RequireAuth`: asigna `current_user` y corta
  con redirección a login si la sesión no es válida (alineado con el plug).
  """

  import Phoenix.Component
  import Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: EventPulseWeb.Endpoint,
    router: EventPulseWeb.Router,
    statics: EventPulseWeb.static_paths()

  def on_mount(:ensure_authenticated, _params, session, socket) do
    case EventPulseWeb.EventHelpers.current_user_from_session(session) do
      nil ->
        {:halt,
         socket
         |> put_flash(:error, "Debes iniciar sesión para acceder.")
         |> push_navigate(to: ~p"/login")}

      user ->
        {:cont, assign(socket, :current_user, user)}
    end
  end
end
