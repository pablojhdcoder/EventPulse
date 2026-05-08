defmodule EventPulse.Votes.VoteAggregator do
  use GenServer
  alias EventPulse.Repo
  alias EventPulse.Votes.Vote

  @registered_name EventPulse.Votes.VoteAggregator

  # --- API Pública ---

  def start_link(opts) do
    opts = Keyword.put_new(opts, :name, @registered_name)
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @doc "Registra o actualiza un voto en memoria"
  def cast_vote(event_id, user_id, choice) do
    :telemetry.execute([:event_pulse, :vote, :cast], %{count: 1}, %{event_id: event_id})
    GenServer.cast(@registered_name, {:cast_vote, event_id, user_id, choice})
  end

  @doc "Obtiene el recuento actual de un evento"
  def get_results(event_id) do
    GenServer.call(@registered_name, {:get_results, event_id})
  end

  # --- Servidor (Callbacks) ---

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_cast({:cast_vote, event_id, user_id, choice}, state) do
    # 1. Actualizar memoria (Consistencia eventual)
    event_votes = Map.get(state, event_id, %{})
    new_event_votes = Map.put(event_votes, user_id, choice)
    new_state = Map.put(state, event_id, new_event_votes)

    # 2. Persistencia a PostgreSQL (sync en test, async en dev/prod vía TaskSupervisor)
    persist_vote(event_id, user_id, choice)

    # 3. Difundir por PubSub
    broadcast_results(event_id, new_event_votes)

    {:noreply, new_state}
  end

  @impl true
  def handle_call({:get_results, event_id}, _from, state) do
    votes = Map.get(state, event_id, %{})
    results = Enum.frequencies(Map.values(votes))
    {:reply, results, state}
  end

  # --- Funciones Privadas Auxiliares ---

  defp persist_vote(event_id, user_id, choice) do
    :telemetry.execute([:event_pulse, :vote, :persist], %{count: 1}, %{event_id: event_id})

    if Application.get_env(:event_pulse, :sync_persist, false) do
      %Vote{}
      |> Vote.changeset(%{event_id: event_id, user_id: user_id, choice: choice})
      |> Repo.insert(
        on_conflict: [set: [choice: choice]],
        conflict_target: [:user_id, :event_id]
      )
    else
      Task.Supervisor.start_child(EventPulse.TaskSupervisor, fn ->
        %Vote{}
        |> Vote.changeset(%{event_id: event_id, user_id: user_id, choice: choice})
        |> Repo.insert(
          on_conflict: [set: [choice: choice]],
          conflict_target: [:user_id, :event_id]
        )
      end)
    end
  end

  defp broadcast_results(event_id, event_votes) do
    results = Enum.frequencies(Map.values(event_votes))

    Phoenix.PubSub.broadcast(EventPulse.PubSub, "event:#{event_id}", {:voted, results})
  end
end
