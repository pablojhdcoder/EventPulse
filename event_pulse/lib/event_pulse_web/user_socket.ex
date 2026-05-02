defmodule EventPulseWeb.UserSocket do
  @moduledoc """
  Socket de WebSocket para Phoenix Channels.

  ## Identificación de usuario

  Actualmente acepta cualquier conexión. El param `user_id` que llegue
  en la query string o en el payload de connect queda asignado en el socket.

  Contrato futuro (RF-06): cuando el módulo de autenticación esté disponible,
  `connect/3` deberá verificar un token firmado y rechazar conexiones sin
  identidad válida con `{:error, :unauthenticated}`.
  """

  use Phoenix.Socket

  channel "event:*", EventPulseWeb.EventChannel

  @impl true
  def connect(params, socket, _connect_info) do
    user_id = Map.get(params, "user_id", "anonymous")
    {:ok, assign(socket, :user_id, user_id)}
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
