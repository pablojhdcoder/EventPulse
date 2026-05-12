defmodule EventPulse.Votes.VoteAggregator do
  use GenServer

  @moduledoc """
  Gestiona el estado de las votaciones en memoria para alta disponibilidad
  y persiste en base de datos de forma asíncrona (batching).
  """

  alias EventPulse.Repo
  alias EventPulse.Votes.Vote

  @flush_interval 500  # ms entre cada persistencia en lote para no saturar la base de datos con escrituras individuales

  # --- API Pública ---

  def start_link(opts) do   # El estado inicial es un mapa de votos vacío por encuesta y una lista de pendientes
    GenServer.start_link(__MODULE__, %{votes: %{}, pending: []}, opts)
  end

  def cast_vote(poll_id, user_id, choice) do    # Enviar un mensaje asíncrono para registrar un voto, no espera respuesta inmediata
    GenServer.cast(__MODULE__, {:cast_vote, poll_id, user_id, choice})
  end

  def get_results(poll_id) do     # Solicitar los resultados actuales de una encuesta, devuelve un mapa con el conteo de votos por opción
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

    # 2. Gestión de la cola "pending", si el usuario cambia de opinión antes del flush, eliminamos su voto anterior de la cola y ponemos el nuevo
    new_pending = [{poll_id, user_id, choice} | Enum.reject(state.pending, fn {_p, u, _c} -> u == user_id end)]

    # 3. Broadcast inmediato con Phoenix PubSub
    broadcast_results(poll_id, new_poll_votes)

    {:noreply, %{state | votes: new_votes, pending: new_pending}}
  end

  @impl true
  def handle_call({:get_results, poll_id}, _from, state) do
    votes = Map.get(state.votes, poll_id, %{})
    results = Enum.frequencies(Map.values(votes))   # Transformamos el mapa de usuarios en un recuento de frecuencias
    {:reply, results, state}
  end

  @impl true
  def handle_info(:flush, state) do
    flush_pending(state.pending)        # Persistir todos los pendientes en un lote
    schedule_flush()                    # Programar el siguiente flush
    {:noreply, %{state | pending: []}}  # Limpiar la cola de pendientes después de persistir
  end

  # --- Funciones Privadas ---

  defp schedule_flush do      # Envía el mensaje :flush a sí mismo tras el intervalo definido
    Process.send_after(self(), :flush, @flush_interval)
  end

  defp flush_pending([]), do: :ok
  defp flush_pending(pending) do    # Persistencia con manejo de conflictos
    Enum.each(pending, fn {poll_id, user_id, choice} ->
      %Vote{}
      |> Vote.changeset(%{poll_id: poll_id, user_id: user_id, choice: choice})
      |> Repo.insert(
        # Si el usuario ya había votado en esta encuesta, actualizamos su voto en lugar de insertar uno nuevo
        on_conflict: [set: [choice: choice]],
        conflict_target: [:user_id, :poll_id]
      )
    end)
  end

  defp broadcast_results(poll_id, poll_votes) do
    results = Enum.frequencies(Map.values(poll_votes))
    Phoenix.PubSub.broadcast(EventPulse.PubSub, "poll:#{poll_id}", {:voted, results})   # Notifica a los suscriptores de esta encuesta que hay un nuevo voto y envía los resultados actualizados
  end
end
