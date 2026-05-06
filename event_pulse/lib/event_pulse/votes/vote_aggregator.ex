defmodule EventPulse.Votes.VoteAggregator do
  use GenServer

  alias EventPulse.Repo
  alias EventPulse.Votes.Vote

  @flush_interval 500  # ms entre cada persistencia en lote

  # --- API Pública ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{votes: %{}, pending: []}, opts)
  end

  @doc "Registra o actualiza un voto en memoria"
  def cast_vote(poll_id, user_id, choice) do
    GenServer.cast(__MODULE__, {:cast_vote, poll_id, user_id, choice})
  end

  @doc "Obtiene el recuento actual de una votación"
  def get_results(poll_id) do
    GenServer.call(__MODULE__, {:get_results, poll_id})
  end

  # --- Callbacks ---

  @impl true
  def init(state) do
    # Programar el primer flush
    schedule_flush()
    {:ok, state}
  end

  @impl true
  def handle_cast({:cast_vote, poll_id, user_id, choice}, state) do
    # 1. Actualizar memoria
    poll_votes = Map.get(state.votes, poll_id, %{})
    new_poll_votes = Map.put(poll_votes, user_id, choice)
    new_votes = Map.put(state.votes, poll_id, new_poll_votes)

    # 2. Añadir a la cola de pendientes (sobreescribe si ya existe)
    new_pending = [{poll_id, user_id, choice} | Enum.reject(state.pending, fn {_p, u, _c} -> u == user_id end)]

    # 3. Broadcast inmediato
    broadcast_results(poll_id, new_poll_votes)

    {:noreply, %{state | votes: new_votes, pending: new_pending}}
  end

  @impl true
  def handle_call({:get_results, poll_id}, _from, state) do
    votes = Map.get(state.votes, poll_id, %{})
    results = Enum.frequencies(Map.values(votes))
    {:reply, results, state}
  end

  @impl true
  def handle_info(:flush, state) do
    # Persistir todos los pendientes en un lote
    flush_pending(state.pending)

    # Programar el siguiente flush
    schedule_flush()

    {:noreply, %{state | pending: []}}
  end

  # --- Funciones Privadas ---

  defp schedule_flush do
    Process.send_after(self(), :flush, @flush_interval)
  end

  defp flush_pending([]), do: :ok
  defp flush_pending(pending) do
    Enum.each(pending, fn {poll_id, user_id, choice} ->
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
