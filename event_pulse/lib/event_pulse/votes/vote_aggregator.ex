defmodule EventPulse.Votes.VoteAggregator do
  use GenServer

  @moduledoc """
  VoteAggregator es un GenServer que gestiona los votos en tiempo real.

  ## Arquitectura

  El estado interno tiene dos partes:
    - `votes` — mapa en memoria con el recuento actual por poll: `%{poll_id => %{user_id => choice}}`
    - `pending` — cola de votos pendientes de persistir en la DB

  ## Persistencia en micro-lotes

  Los votos se acumulan en `pending` y se persisten en lote cada 500ms mediante
  `handle_info(:flush)`, salvo en tests (`sync_persist: true`), donde cada `cast`
  dispara un flush inmediato para cuadrar con el sandbox de Ecto.

  ## Consistencia

  En caso de caída del nodo, los votos en `pending` que no se hayan persistido
  se perderían. La memoria (`votes`) es la fuente de verdad en caliente; Postgres
  es la fuente de verdad persistente.
  """

  alias EventPulse.Repo
  alias EventPulse.Votes.Vote

  @registered_name EventPulse.Votes.VoteAggregator
  @flush_interval 500

  # --- API Pública ---

  def start_link(opts) do
    opts = Keyword.put_new(opts, :name, @registered_name)
    GenServer.start_link(__MODULE__, %{votes: %{}, pending: []}, opts)
  end

  @doc "Registra o actualiza un voto en memoria"
  def cast_vote(poll_id, user_id, choice) do
    :telemetry.execute([:event_pulse, :vote, :cast], %{count: 1}, %{poll_id: poll_id})
    GenServer.cast(@registered_name, {:cast_vote, poll_id, user_id, choice})
  end

  @doc "Obtiene el recuento actual de una votación"
  def get_results(poll_id) do
    GenServer.call(@registered_name, {:get_results, poll_id})
  end

  # --- Callbacks ---

  @impl true
  def init(state) do
    schedule_flush()
    {:ok, state}
  end

  @impl true
  def handle_cast({:cast_vote, poll_id, user_id, choice}, state) do
    poll_votes = Map.get(state.votes, poll_id, %{})
    new_poll_votes = Map.put(poll_votes, user_id, choice)
    new_votes = Map.put(state.votes, poll_id, new_poll_votes)

    new_pending = [
      {poll_id, user_id, choice}
      | Enum.reject(state.pending, fn {p, u, _} -> p == poll_id && u == user_id end)
    ]

    broadcast_results(poll_id, new_poll_votes)

    state = %{state | votes: new_votes, pending: new_pending}

    state =
      if Application.get_env(:event_pulse, :sync_persist, false) do
        flush_pending(state.pending)
        %{state | pending: []}
      else
        state
      end

    {:noreply, state}
  end

  @impl true
  def handle_call({:get_results, poll_id}, _from, state) do
    votes = Map.get(state.votes, poll_id, %{})
    results = Enum.frequencies(Map.values(votes))
    {:reply, results, state}
  end

  @impl true
  def handle_info(:flush, state) do
    flush_pending(state.pending)
    schedule_flush()
    {:noreply, %{state | pending: []}}
  end

  # --- Funciones privadas ---

  defp schedule_flush do
    Process.send_after(self(), :flush, @flush_interval)
  end

  defp flush_pending([]), do: :ok

  defp flush_pending(pending) do
    Enum.each(pending, fn {poll_id, user_id, choice} ->
      :telemetry.execute([:event_pulse, :vote, :persist], %{count: 1}, %{poll_id: poll_id})

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
