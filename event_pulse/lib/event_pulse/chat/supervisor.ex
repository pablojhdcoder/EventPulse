defmodule EventPulse.Chat.Supervisor do
  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {Registry, keys: :unique, name: EventPulse.Chat.RoomRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: EventPulse.Chat.RoomSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc "Asegura que exista un proceso de sala para el evento"
  def ensure_room(event_id) do
    case Registry.lookup(EventPulse.Chat.RoomRegistry, event_id) do
      [{pid, _meta}] -> {:ok, pid}
      [] ->
        DynamicSupervisor.start_child(
          EventPulse.Chat.RoomSupervisor,
          {EventPulse.Chat.Room, event_id}
        )
    end
  end
end
