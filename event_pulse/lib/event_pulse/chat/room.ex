defmodule EventPulse.Chat.Room do
  use GenServer
  require Logger

  @max_history 50

  def start_link(event_id) do
    GenServer.start_link(__MODULE__, event_id, name: via_tuple(event_id))
  end

  @doc "Solicita la sala y la crea si es necesario"
  def join(event_id) do
    EventPulse.Chat.Supervisor.ensure_room(event_id)
  end

  @doc "Añade un mensaje al buffer de la sala"
  def push_message(event_id, user_id, message) do
    GenServer.call(via_tuple(event_id), {:push_message, user_id, message})
  end

  @doc "Lee el historial de mensajes recientes"
  def get_history(event_id) do
    GenServer.call(via_tuple(event_id), :get_history)
  end

  @impl true
  def init(event_id) do
    Logger.info("Chat room started", event_id: event_id)
    {:ok, %{event_id: event_id, history: []}}
  end

  @impl true
  def handle_call({:push_message, user_id, message}, _from, state) do
    entry = %{user_id: user_id, message: message, inserted_at: DateTime.utc_now()}
    history = [entry | state.history] |> Enum.take(@max_history)

    :telemetry.execute(
      [:event_pulse, :chat, :message, :store],
      %{count: 1},
      %{event_id: state.event_id}
    )

    {:reply, {:ok, entry}, %{state | history: history}}
  end

  @impl true
  def handle_call(:get_history, _from, state) do
    {:reply, Enum.reverse(state.history), state}
  end

  defp via_tuple(event_id), do: {:via, Registry, {EventPulse.Chat.RoomRegistry, event_id}}
end
