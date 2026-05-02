defmodule EventPulseWeb.EventChannel do
  @moduledoc """
  Canal Phoenix para el chat de un evento en tiempo real.

  Topic: `event:<id>` — un canal por evento.

  Recibe mensajes entrantes del cliente (`new_msg`, `leave`) y mensajes
  internos del PubSub (`{:new_message, ...}` del EventRoom,
  `{:voted, ...}` del VoteAggregator).
  """

  use EventPulseWeb, :channel

  alias EventPulse.Chat.EventRoom

  @max_body_length Application.compile_env(:event_pulse, :chat_max_body_length, 500)

  # ---------------------------------------------------------------------------
  # Join / Leave
  # ---------------------------------------------------------------------------

  @impl true
  def join("event:" <> event_id, _params, socket) when event_id != "" do
    Phoenix.PubSub.subscribe(EventPulse.PubSub, "event:#{event_id}")

    history = EventRoom.recent_messages(event_id)

    socket = assign(socket, :event_id, event_id)

    {:ok, %{history: serialize_messages(history)}, socket}
  end

  def join(_topic, _params, _socket) do
    {:error, %{reason: "invalid_event"}}
  end

  @impl true
  def terminate(_reason, socket) do
    if event_id = socket.assigns[:event_id] do
      Phoenix.PubSub.unsubscribe(EventPulse.PubSub, "event:#{event_id}")
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Mensajes entrantes del cliente
  # ---------------------------------------------------------------------------

  @impl true
  def handle_in("new_msg", %{"body" => body}, socket) when is_binary(body) do
    cond do
      String.trim(body) == "" ->
        {:reply, {:error, %{reason: "empty_body"}}, socket}

      String.length(body) > @max_body_length ->
        {:reply, {:error, %{reason: "body_too_long"}}, socket}

      true ->
        author = socket.assigns[:user_id] || "anonymous"
        event_id = socket.assigns.event_id

        case EventRoom.send_message(event_id, %{author: author, body: body}) do
          :ok ->
            {:reply, :ok, socket}

          {:error, reason} ->
            {:reply, {:error, %{reason: format_room_error(reason)}}, socket}
        end
    end
  end

  def handle_in("new_msg", _payload, socket) do
    {:reply, {:error, %{reason: "invalid_payload"}}, socket}
  end

  def handle_in("leave", _payload, socket) do
    {:stop, :normal, {:ok, %{}}, socket}
  end

  # ---------------------------------------------------------------------------
  # Mensajes internos de PubSub
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({:new_message, message}, socket) do
    push(socket, "new_message", serialize_message(message))
    {:noreply, socket}
  end

  def handle_info({:voted, results}, socket) do
    push(socket, "votes_updated", %{results: results})
    {:noreply, socket}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Helpers de serialización
  # ---------------------------------------------------------------------------

  defp serialize_messages(messages), do: Enum.map(messages, &serialize_message/1)

  defp serialize_message(%{author: author, body: body, inserted_at: inserted_at}) do
    %{
      author: author,
      body: body,
      inserted_at: DateTime.to_iso8601(inserted_at)
    }
  end

  defp serialize_message(message), do: message

  defp format_room_error(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_room_error(reason), do: to_string(reason)
end
