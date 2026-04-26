defmodule EventPulse.Votes.VoteAggregator do
  use GenServer
  alias EventPulse.Repo
  alias EventPulse.Votes.Vote

  # --- API Pública ---

  def start_link(opts) do
    # Iniciamos el proceso con un mapa vacío: %{event_id => %{user_id => choice}}
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @doc "Registra o actualiza un voto en memoria"
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
    # 1. Actualizar memoria (Consistencia eventual)
    event_votes = Map.get(state, event_id, %{})
    new_event_votes = Map.put(event_votes, user_id, choice)
    new_state = Map.put(state, event_id, new_event_votes)

    # 2. Persistencia asíncrona a PostgreSQL (RNF-05)
    # Aquí llamarás a una función para guardar en DB sin bloquear el proceso
    persist_vote(event_id, user_id, choice)

    # 3. Difundir por PubSub (RF-12)
    # Esto avisará a la Persona 3 para que los usuarios vean el cambio
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
    # Usamos Task para que sea asíncrono y no bloquee el GenServer
    Task.start(fn ->
      %Vote{}
      |> Vote.changeset(%{event_id: event_id, user_id: user_id, choice: choice})
      |> Repo.insert(
        # Si hay conflicto (ya votó), actualiza la opción [cite: 80, 101]
        on_conflict: [set: [choice: choice]],
        conflict_target: [:user_id, :event_id]
      )
    end)
  end

  defp broadcast_results(event_id, event_votes) do
    results = Enum.frequencies(Map.values(event_votes))
    # CAMBIA EventPulse.Sub POR EventPulse.PubSub
    Phoenix.PubSub.broadcast(EventPulse.PubSub, "event:#{event_id}", {:voted, results})
  end
end
