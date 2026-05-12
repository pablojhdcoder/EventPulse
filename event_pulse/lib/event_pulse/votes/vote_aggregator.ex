defmodule EventPulse.Votes.VoteAggregator do
  @moduledoc """
  GenServer que gestiona votos en tiempo real.

  Mantiene un mapa en memoria por encuesta (`Poll`) o por evento legado y persiste
  en micro-lotes. Si `Repo.insert` falla, los votos afectados permanecen en `pending`
  y se reintentan en el siguiente ciclo.

  ## Clúster (Docker / libcluster)

  Se registra con `{:global, __MODULE__}`: existe **un solo** agregador en todo el
  clúster. Cada réplica arranca el mismo hijo en el `Application`; en los nodos que
  no ganan el registro global, `start_link/1` devuelve `{:ok, pid}` del proceso que
  ya vive en otro nodo, de modo que el supervisor enlaza al líder remoto en lugar
  de duplicar estado. `cast_vote/3` y `get_results/1` siguen usando el nombre global,
  así que cualquier nodo enruta al mismo GenServer.

  En tests (`sync_persist: true`), cada `cast_vote` fuerza un flush inmediato.
  """

  use GenServer

  import Ecto.Query

  alias EventPulse.Repo
  alias EventPulse.Votes.Poll
  alias EventPulse.Votes.Vote

  @flush_interval 500
  @name {:global, __MODULE__}

  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, @name)

    case GenServer.start_link(__MODULE__, %{votes: %{}, pending: []}, opts) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_registered, leader_pid}} ->
        {:ok, leader_pid}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Registra o actualiza un voto.

  Si `id` corresponde a una `Poll`, usa el modelo por encuesta; si no existe esa
  poll, trata `id` como `event_id` del flujo legado.
  """
  def cast_vote(id, user_id, choice) do
    scope = vote_scope(id)
    :telemetry.execute([:event_pulse, :vote, :cast], %{count: 1}, telemetry_meta(scope))
    GenServer.cast(@name, {:cast_vote, scope, user_id, choice})
  end

  @doc "Obtiene el recuento actual para una encuesta o un evento (modelo legado)."
  def get_results(id) do
    GenServer.call(@name, {:get_results, vote_scope(id)})
  end

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

    state = %{state | votes: updated_votes, pending: updated_pending}

    state =
      if Application.get_env(:event_pulse, :sync_persist, false) do
        failed = flush_pending(state.pending)
        %{state | pending: failed}
      else
        state
      end

    {:noreply, state}
  end

  @impl true
  def handle_call({:get_results, scope}, _from, state) do
    scope_votes = Map.get(state.votes, scope) || votes_map_from_db(scope)
    results = Enum.frequencies(Map.values(scope_votes))

    {:reply, results, %{state | votes: Map.put(state.votes, scope, scope_votes)}}
  end

  @impl true
  def handle_info(:flush, state) do
    failed = flush_pending(state.pending)
    schedule_flush()
    {:noreply, %{state | pending: failed}}
  end

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

  defp flush_pending([]), do: []

  defp flush_pending(pending) do
    Enum.reduce(pending, [], fn {scope, user_id, choice} = vote, failed ->
      :telemetry.execute([:event_pulse, :vote, :persist], %{count: 1}, telemetry_meta(scope))

      case insert_vote(scope, user_id, choice) do
        :ok -> failed
        :error -> [vote | failed]
      end
    end)
    |> Enum.reverse()
  end

  defp insert_vote({:poll, poll_id}, user_id, choice) do
    case %Vote{}
         |> Vote.changeset(%{poll_id: poll_id, user_id: user_id, choice: choice})
         |> Repo.insert(
           on_conflict: [set: [choice: choice]],
           conflict_target: [:user_id, :poll_id]
         ) do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  rescue
    Ecto.ConstraintError -> :error
    DBConnection.ConnectionError -> :error
  end

  defp insert_vote({:event, event_id}, user_id, choice) do
    case %Vote{}
         |> Vote.changeset(%{event_id: event_id, user_id: user_id, choice: choice})
         |> Repo.insert(
           on_conflict: [set: [choice: choice]],
           conflict_target: [:user_id, :event_id]
         ) do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  rescue
    Ecto.ConstraintError -> :error
    DBConnection.ConnectionError -> :error
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

  defp telemetry_meta({:poll, poll_id}), do: %{poll_id: poll_id}
  defp telemetry_meta({:event, event_id}), do: %{event_id: event_id}
end
