defmodule EventPulse.Chat.EventRoom do
  use GenServer

  @moduledoc """
  GenServer que gestiona el buffer de mensajes de chat para cada evento.

  Mantiene en memoria un buffer FIFO acotado a `@buffer_max` mensajes por sala
  (`event_id`). No persiste mensajes en base de datos; el chat es efímero por
  diseño (ver `doc/contexto-arquitectura-distribuida.md`).

  ## Nota multi-nodo
  En un despliegue con varios nodos BEAM cada nodo tiene su propio `EventRoom`.
  La sincronización entre nodos del historial de chat queda fuera del alcance
  de esta tarea y se abordará en la fase de arquitectura distribuida del equipo.

  ## API pública

      EventRoom.send_message("42", %{author: "alice", body: "hola"})
      EventRoom.recent_messages("42")
  """

  @buffer_max Application.compile_env(:event_pulse, :chat_buffer_max, 50)
  @max_body_length Application.compile_env(:event_pulse, :chat_max_body_length, 500)

  # ---------------------------------------------------------------------------
  # API pública
  # ---------------------------------------------------------------------------

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @doc """
  Registra un mensaje en el buffer del evento y lo difunde por PubSub.

  `event_id` debe ser un string.
  `message` debe incluir al menos `:author` y `:body`.
  Retorna `:ok` o `{:error, reason}` sin pasar por el GenServer si la
  validación falla, para no bloquear el proceso con mensajes inválidos.

  El argumento opcional `server` permite apuntar a una instancia específica
  (útil en tests con `start_supervised!`). Por defecto usa el proceso registrado
  globalmente.
  """
  def send_message(event_id, message, server \\ __MODULE__)

  def send_message(event_id, %{body: body} = message, server) when is_binary(event_id) do
    cond do
      body == nil or String.trim(body) == "" ->
        {:error, :empty_body}

      String.length(body) > @max_body_length ->
        {:error, :body_too_long}

      true ->
        GenServer.cast(server, {:send_message, event_id, enrich(message)})
    end
  end

  @doc """
  Variante de `send_message/2` con servidor explícito. Alias de `send_message/3`
  pensado para tests donde se arranca una instancia aislada con `start_supervised!`.
  """
  def send_message_via(server, event_id, message), do: send_message(event_id, message, server)

  @doc "Devuelve la lista de los últimos N mensajes del evento, en orden cronológico."
  def recent_messages(event_id, server \\ __MODULE__) when is_binary(event_id) do
    GenServer.call(server, {:recent_messages, event_id})
  end

  # ---------------------------------------------------------------------------
  # Callbacks del servidor
  # ---------------------------------------------------------------------------

  @impl true
  def init(_), do: {:ok, %{}}

  @impl true
  def handle_cast({:send_message, event_id, message}, state) do
    buffer =
      state
      |> Map.get(event_id, [])
      |> append_and_trim(message)

    Phoenix.PubSub.broadcast(
      EventPulse.PubSub,
      "event:#{event_id}",
      {:new_message, message}
    )

    {:noreply, Map.put(state, event_id, buffer)}
  end

  @impl true
  def handle_call({:recent_messages, event_id}, _from, state) do
    {:reply, Map.get(state, event_id, []), state}
  end

  # ---------------------------------------------------------------------------
  # Funciones privadas
  # ---------------------------------------------------------------------------

  defp enrich(%{author: _, body: _} = message) do
    Map.put_new(message, :inserted_at, DateTime.utc_now())
  end

  defp append_and_trim(buffer, message) do
    buffer
    |> Kernel.++([message])
    |> Enum.take(-@buffer_max)
  end
end
