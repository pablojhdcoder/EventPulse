defmodule EventPulse.Chat.EventRoom do
  use GenServer

  alias EventPulse.ChatBuffer

  @moduledoc """
  Coordinador de chat por evento.

  - Buffer distribuido: `EventPulse.ChatBuffer` (Redis Streams, últimos N mensajes).
  - Entrega en tiempo real: `Phoenix.PubSub` en el tópico `event:<id>`.

  El GenServer no mantiene estado de negocio; solo serializa el flujo de envío/lectura
  del chat para exponer una API estable al LiveView.
  """

  @max_body_length Application.compile_env(:event_pulse, :chat_max_body_length, 500)

  # ---------------------------------------------------------------------------
  # API pública
  # ---------------------------------------------------------------------------

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Envía un mensaje: lo añade al buffer Redis y lo difunde por PubSub.

  Retorna `:ok` o `{:error, reason}` si la validación falla antes del GenServer.
  """
  def send_message(event_id, message, server \\ __MODULE__)

  def send_message(event_id, %{body: body} = message, server) when is_binary(event_id) do
    cond do
      body == nil or String.trim(body) == "" ->
        {:error, :empty_body}

      String.length(body) > @max_body_length ->
        {:error, :body_too_long}

      match?({_, ""}, Integer.parse(event_id)) ->
        GenServer.cast(server, {:send_message, event_id, enrich(message)})
        :ok

      true ->
        {:error, :invalid_event_id}
    end
  end

  @doc "Devuelve los últimos N mensajes del evento desde Redis (orden cronológico)."
  def recent_messages(event_id, server \\ __MODULE__) when is_binary(event_id) do
    GenServer.call(server, {:recent_messages, event_id})
  end

  # ---------------------------------------------------------------------------
  # Callbacks del servidor
  # ---------------------------------------------------------------------------

  @impl true
  def init(:ok), do: {:ok, nil}

  @impl true
  def handle_cast({:send_message, event_id, message}, state) do
    pub = to_public_message(message)
    _ = ChatBuffer.append_message(event_id, to_buffer_message(pub))

    Phoenix.PubSub.broadcast(
      EventPulse.PubSub,
      "event:#{event_id}",
      {:new_message, pub}
    )

    {:noreply, state}
  end

  @impl true
  def handle_call({:recent_messages, event_id}, _from, state) do
    {:reply, ChatBuffer.get_last_messages(event_id), state}
  end

  # ---------------------------------------------------------------------------
  # Privado
  # ---------------------------------------------------------------------------

  defp enrich(%{author: _, body: _} = message) do
    Map.put_new(message, :inserted_at, DateTime.utc_now())
  end

  defp to_public_message(message) do
    %{
      author: message.author,
      body: message.body,
      inserted_at: message.inserted_at
    }
  end

  defp to_buffer_message(pub) do
    %{
      user_id: pub.author,
      username: pub.author,
      content: pub.body,
      timestamp: pub.inserted_at
    }
  end
end
