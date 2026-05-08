defmodule EventPulseWeb.Plugs.RequireAuth do

  @behaviour Plug
  import Plug.Conn
  import Phoenix.Controller
  use Phoenix.VerifiedRoutes,
    endpoint: EventPulseWeb.Endpoint,
    router: EventPulseWeb.Router

  alias EventPulse.Accounts.Auth

  def init(opts), do: Keyword.put_new(opts, :redirect_to, "/login")

  @impl Plug
  def call(conn, opts) do
    conn
    |> get_session(:user_id)
    |> ensure_user(conn, opts)
  end

  defp ensure_user(nil, conn, opts) do
    conn
    |> put_flash(:error, "Debes iniciar sesión para acceder.")
    |> redirect(to: opts[:redirect_to])
    |> halt()
  end

  defp ensure_user(user_id, conn, opts) do
    case Auth.get_user(user_id) do
      nil ->
        conn
        |> clear_session()
        |> put_flash(:error, "Sesión inválida. Por favor inicia sesión de nuevo.")
        |> redirect(to: opts[:redirect_to])
        |> halt()

      user ->
        assign(conn, :current_user, user)
    end
  end
end
