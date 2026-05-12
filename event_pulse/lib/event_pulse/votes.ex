defmodule EventPulse.Votes do
  @moduledoc """
  Contexto principal para la gestión de encuestas y votos.
  Actúa como orquestador entre el almacenamiento persistente (Repo)
  y el estado en tiempo real (VoteAggregator).
  """
  import Ecto.Query
  alias EventPulse.Repo
  alias EventPulse.Votes.{Poll, VoteAggregator}

  # --- Gestión de encuestas, Polls ---

  @doc "Crea una votación para un evento"
  def create_poll(event_id, question, options) do
    %Poll{}
    |> Poll.changeset(%{event_id: event_id, question: question, options: options})
    |> Repo.insert()
  end

  @doc "Obtiene todas las encuestas asociadas a un id de evento"
  def list_polls(event_id) do
    Repo.all(from p in Poll, where: p.event_id == ^event_id)
  end

  @doc "Cambia el estado de una encuesta a 'closed' para impedir nuevos votos"
  def close_poll(poll_id) do
    case Repo.get(Poll, poll_id) do
      nil ->
        {:error, :not_found}

      poll ->
        poll
        |> Poll.changeset(%{status: "closed"})
        |> Repo.update()
    end
  end

  # --- Gestión de votos ---

  @doc """
  Registra un voto validando primero la existencia, el estado y las opciones.
  Si las reglas de negocio se cumplen, delega el procesamiento al VoteAggregator.
  """
  def cast_vote(poll_id, user_id, choice) do
    case Repo.get(Poll, poll_id) do
      nil ->
        {:error, :not_found}

      # No votar en encuestas cerradas
      %Poll{status: "closed"} ->
        {:error, :poll_closed}

      # Solo permite opciones definidas en la encuesta
      %Poll{options: options} ->
        if choice in options do
          VoteAggregator.cast_vote(poll_id, user_id, choice)
          :ok
        else
          {:error, :invalid_choice}
        end
    end
  end

  @doc "Obtiene el estado actual de los votos para una encuesta específica"
  def get_results(poll_id) do
    VoteAggregator.get_results(poll_id)
  end

  @doc """
  Construye un mapa detallado con todas las encuestas y sus resultados
  calculados en tiempo real para un evento específico.
  """
  def get_event_results(event_id) do
    list_polls(event_id)
    |> Enum.map(fn poll ->
      {poll.id,
       %{
         question: poll.question,
         options: poll.options,
         status: poll.status,
         results: VoteAggregator.get_results(poll.id)
       }}
    end)
    |> Map.new()
  end
end
