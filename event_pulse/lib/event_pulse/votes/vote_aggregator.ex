defmodule EventPulse.Votes.VoteAggregator do
  use GenServer

  import Ecto.Query

  @moduledoc """
  Gestiona el estado de las votaciones en memoria para alta disponibilidad
  y persiste en base de datos de forma asíncrona (batching).
  """

  alias EventPulse.Repo
  alias EventPulse.Votes.Poll
  alias EventPulse.Votes.Vote

  @flush_interval 500

  # --- API Pública ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{votes: %{}, pending: []}, opts)
  end

  @doc """
  Registra o actualiza un voto.

  Si el identificador corresponde a una `Poll`, usa el modelo nuevo por encuesta.
  Si no existe esa encuesta, mantiene el flujo anterior por evento que usa la LiveView.
  """
  def cast_vote(id, user_id, choice) do
    GenServer.cast(__MODULE__, {:cast_vote, vote_scope(id), user_id, choice})
  end

  @doc "Obtiene los resultados actuales de una encuesta o evento."
  def get_results(id) do
    GenServer.call(__MODULE__, {:get_results, vote_scope(id)})
  end

  # --- Callbacks ---

  @impl true
  def init(state) do
    schedule_flush()
    {:ok, state}
  end

  @impl true
  def handle_cast({:cast_vote, scope, user_id, choice}, state) do
    current_votes = Map.get(state.votes, scope) || votes_map_from_db(scope)
    updated_scope_votes = Map.put(current_votes, user_id, choice)
    updated_votes = Map.put(state.votes, scope, updated_scope_votes)

    updated_pending = [
      {scope, user_id, choice}
      | Enum.reject(state.pending, fn {pending_scope, pending_user_id, _choice} ->
          pending_scope == scope and pending_user_id == user_id
        end)
    ]

    broadcast_results(scope, updated_scope_votes)

    {:noreply, %{state | votes: updated_votes, pending: updated_pending}}
  end

  @impl true
  def handle_call({:get_results, scope}, _from, state) do
    scope_votes = Map.get(state.votes, scope) || votes_map_from_db(scope)
    results = Enum.frequencies(Map.values(scope_votes))

    {:reply, results, %{state | votes: Map.put(state.votes, scope, scope_votes)}}
  end

  @impl true
  def handle_info(:flush, state) do
    flush_pending(state.pending)
    schedule_flush()
    {:noreply, %{state | pending: []}}
  end

  # --- Funciones Privadas ---

  defp vote_scope(id) do
    case Repo.get(Poll, id) do
      %Poll{} -> {:poll, id}
      nil -> {:event, id}
    end
  end

  defp votes_map_from_db({:poll, poll_id}) do
    Vote
    |> where([v], v.poll_id == ^poll_id)
    |> select([v], {v.user_id, v.choice})
    |> Repo.all()
    |> Map.new()
  end

  defp votes_map_from_db({:event, event_id}) do
    Vote
    |> where([v], v.event_id == ^event_id)
    |> select([v], {v.user_id, v.choice})
    |> Repo.all()
    |> Map.new()
  end

  defp schedule_flush do
    Process.send_after(self(), :flush, @flush_interval)
  end

  defp flush_pending([]), do: :ok

  defp flush_pending(pending) do
    Enum.each(pending, fn {scope, user_id, choice} ->
      persist_vote(scope, user_id, choice)
    end)
  end

  defp persist_vote({:poll, poll_id}, user_id, choice) do
    %Vote{}
    |> Vote.changeset(%{poll_id: poll_id, user_id: user_id, choice: choice})
    |> Repo.insert(
      on_conflict: [set: [choice: choice]],
      conflict_target: [:user_id, :poll_id]
    )
  end

  defp persist_vote({:event, event_id}, user_id, choice) do
    %Vote{}
    |> Vote.changeset(%{event_id: event_id, user_id: user_id, choice: choice})
    |> Repo.insert(
      on_conflict: [set: [choice: choice]],
      conflict_target: [:user_id, :event_id]
    )
  end

  defp broadcast_results({:poll, poll_id}, scope_votes) do
    results = Enum.frequencies(Map.values(scope_votes))
    Phoenix.PubSub.broadcast(EventPulse.PubSub, "poll:#{poll_id}", {:voted, results})

    case Repo.get(Poll, poll_id) do
      %Poll{event_id: event_id} ->
        Phoenix.PubSub.broadcast(EventPulse.PubSub, "event:#{event_id}", {:voted, results})

      nil ->
        :ok
    end
  end

  defp broadcast_results({:event, event_id}, scope_votes) do
    results = Enum.frequencies(Map.values(scope_votes))
    Phoenix.PubSub.broadcast(EventPulse.PubSub, "event:#{event_id}", {:voted, results})
  end
end
