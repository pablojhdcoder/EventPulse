defmodule EventPulse.EventRoom do
  @moduledoc """
  Proceso asociado a una sala de evento.

  Se registra por `event_id` para que el cierre del evento pueda localizarlo
  y terminarlo desde `EventPulse.SocialFeeling.Worker`.
  """

  use GenServer

  @topic_prefix "event:"

  def start_link(event_id) when is_integer(event_id) do
    GenServer.start_link(__MODULE__, event_id, name: via_tuple(event_id))
  end

  def close(pid) when is_pid(pid) do
    GenServer.call(pid, :close)
  end

  def child_spec(event_id) do
    %{
      id: {__MODULE__, event_id},
      start: {__MODULE__, :start_link, [event_id]},
      restart: :temporary
    }
  end

  @impl true
  def init(event_id), do: {:ok, %{event_id: event_id}}

  @impl true
  def handle_call(:close, _from, %{event_id: event_id} = state) do
    Phoenix.PubSub.broadcast(EventPulse.PubSub, @topic_prefix <> to_string(event_id), {
      :event_room_closed,
      event_id
    })

    {:stop, :normal, :ok, state}
  end

  defp via_tuple(event_id), do: {:via, Registry, {EventPulse.EventRegistry, event_id}}
end
