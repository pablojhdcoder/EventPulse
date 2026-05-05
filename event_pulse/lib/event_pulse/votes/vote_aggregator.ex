defmodule EventPulse.Votes.VoteAggregator do
  use GenServer
  import Ecto.Query
  alias EventPulse.Repo
  alias EventPulse.Votes.Vote

  # --- API Pública ---

  def start_link(opts) do
    # Iniciamos el proceso con un mapa vacío: %{event_id => %{user_id => choice}}
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @doc "Registra o actualiza un voto"
  def cast_vote(event_id, user_id, choice) do
    GenServer.cast(__MODULE__, {:cast_vote, event_id, user_id, choice})
  end

  @doc "Obtiene el recuento actual de un evento"
  def get_results(event_id) do
    GenServer.call(__MODULE__, {:get_results, event_id})
  end

  # --- Servidor (Callbacks) ---

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_cast({:cast_vote, event_id, user_id, choice}, state) do
    persist_vote(event_id, user_id, choice)
    event_votes = votes_map_from_db(event_id)
    broadcast_results(event_id, event_votes)
    new_state = Map.put(state, event_id, event_votes)
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:get_results, event_id}, _from, state) do
    event_votes = votes_map_from_db(event_id)
    results = Enum.frequencies(Map.values(event_votes))
    {:reply, results, Map.put(state, event_id, event_votes)}
  end

  # --- Funciones Privadas Auxiliares ---

  defp votes_map_from_db(event_id) do
    Vote
    |> where([v], v.event_id == ^event_id)
    |> select([v], {v.user_id, v.choice})
    |> Repo.all()
    |> Map.new()
  end

  defp persist_vote(event_id, user_id, choice) do
    %Vote{}
    |> Vote.changeset(%{event_id: event_id, user_id: user_id, choice: choice})
    |> Repo.insert(
      # Si hay conflicto (ya votó), actualiza la opción [cite: 80, 101]
      on_conflict: [set: [choice: choice]],
      conflict_target: [:user_id, :event_id]
    )
  end

  defp broadcast_results(event_id, event_votes) do
    results = Enum.frequencies(Map.values(event_votes))

    Phoenix.PubSub.broadcast(EventPulse.PubSub, "event:#{event_id}", {:voted, results})
  end
end
