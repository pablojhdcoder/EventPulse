defmodule EventPulse.Votes.VoteAggregator do
  use GenServer

  alias EventPulse.Repo
  alias EventPulse.Votes.Vote

  # --- API Pública ---

  def start_link(opts) do
    # Estado: %{poll_id => %{user_id => choice}}
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @doc "Registra o actualiza un voto en memoria"
  def cast_vote(poll_id, user_id, choice) do
    GenServer.cast(__MODULE__, {:cast_vote, poll_id, user_id, choice})
  end

  @doc "Obtiene el recuento actual de una votación"
  def get_results(poll_id) do
    GenServer.call(__MODULE__, {:get_results, poll_id})
  end

  # --- Servidor (Callbacks) ---

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_cast({:cast_vote, poll_id, user_id, choice}, state) do
    # 1. Actualizar memoria
    poll_votes = Map.get(state, poll_id, %{})
    new_poll_votes = Map.put(poll_votes, user_id, choice)
    new_state = Map.put(state, poll_id, new_poll_votes)

    # 2. Persistencia asíncrona a PostgreSQL
    persist_vote(poll_id, user_id, choice)

    # 3. Difundir por PubSub
    broadcast_results(poll_id, new_poll_votes)

    {:noreply, new_state}
  end

  @impl true
  def handle_call({:get_results, poll_id}, _from, state) do
    votes = Map.get(state, poll_id, %{})
    results = Enum.frequencies(Map.values(votes))
    {:reply, results, state}
  end

  # --- Funciones Privadas Auxiliares ---

  defp persist_vote(poll_id, user_id, choice) do
    Task.start(fn ->
      %Vote{}
      |> Vote.changeset(%{poll_id: poll_id, user_id: user_id, choice: choice})
      |> Repo.insert(
        on_conflict: [set: [choice: choice]],
        conflict_target: [:user_id, :poll_id]
      )
    end)
  end

  defp broadcast_results(poll_id, poll_votes) do
    results = Enum.frequencies(Map.values(poll_votes))
    Phoenix.PubSub.broadcast(EventPulse.PubSub, "poll:#{poll_id}", {:voted, results})
  end
end
