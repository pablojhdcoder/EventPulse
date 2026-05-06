defmodule EventPulseWeb.Plugs.EnsureDemoUserId do
  @moduledoc """
  Asigna un entero `demo_user_id` en la sesión HTTP (identidad anónima para votos y chat)
  la primera vez que visita el usuario. Sustituible por autenticación real en el router.
  """

  import Plug.Conn

  @session_key "demo_user_id"

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, @session_key) do
      nil ->
        id = :rand.uniform(999_999)
        put_session(conn, @session_key, id)

      _ ->
        conn
    end
  end
end
