defmodule EventPulse.Votes do
  @moduledoc """
  Contexto principal para la gestión de encuestas y votos.
  Actúa como orquestador entre el almacenamiento persistente (Repo)
  y el estado en tiempo real (VoteAggregator).
  """
  import Ecto.Query
  alias EventPulse.Repo
  alias EventPulse.Votes.{Poll, Vote, VoteAggregator}

  # --- Gestión de encuestas, Polls ---

  @doc "Crea una votación para un evento."
  def create_poll(event_id, question, options) do
    %Poll{}
    |> Poll.changeset(%{
      event_id: event_id,
      question: question,
      options: options
    })
    |> Repo.insert()
    |> case do
      {:ok, poll} ->
        EventPulse.broadcast("event:#{event_id}", {:poll_created, poll})
        {:ok, poll}

      error ->
        error
    end
  end

  @doc "Obtiene todas las encuestas asociadas a un id de evento."
  def list_polls(event_id) do
    Repo.all(from p in Poll, where: p.event_id == ^event_id)
  end

  @doc "Obtiene una encuesta por id o `nil`."
  def get_poll(id), do: Repo.get(Poll, id)

  @doc """
  Actualiza pregunta y opciones de una votación.

  Si ya hay votos persistidos, no se permiten cambiar las opciones (solo la pregunta si las opciones coinciden).
  """
  def update_poll(%Poll{} = poll, attrs) when is_map(attrs) do
    question = attrs[:question] || attrs["question"]
    options = attrs[:options] || attrs["options"]

    vote_count = poll_vote_count(poll.id)

    cond do
      is_nil(question) or not is_list(options) ->
        {:error, :invalid_attrs}

      vote_count > 0 and options != poll.options ->
        {:error, :cannot_change_options_with_votes}

      true ->
        poll
        |> Poll.changeset(%{question: question, options: options})
        |> Repo.update()
    end
  end

  defp poll_vote_count(poll_id) do
    from(v in Vote, where: v.poll_id == ^poll_id, select: count(v.id))
    |> Repo.one()
  end

  @doc """
  Recuento de votos persistidos por opción para una encuesta (resultado fiel al cierre).
  """
  def poll_vote_counts(poll_id) do
    from(v in Vote,
      where: v.poll_id == ^poll_id,
      group_by: v.choice,
      select: {v.choice, count(v.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Lista encuestas del evento ordenadas por creación, cada una con `results` desde la BD.
  Útil cuando el evento está finalizado y ya no hay encuestas abiertas en vivo.
  """
  def list_polls_with_db_results(event_id) do
    event_id
    |> list_polls()
    |> Enum.sort_by(& &1.inserted_at, DateTime)
    |> Enum.map(fn poll ->
      %{poll: poll, results: poll_vote_counts(poll.id)}
    end)
  end

  @doc "Cambia el estado de una encuesta a 'closed' para impedir nuevos votos."
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
    case get_poll_with_event_status(poll_id) do
      nil ->
        {:error, :not_found}

      {%Poll{status: "closed"}, _event_status} ->
        {:error, :poll_closed}

      {%Poll{}, event_status} when event_status != "en_directo" ->
        {:error, :event_not_live}

      {%Poll{options: options} = poll, _event_status} ->
        if choice in options do
          VoteAggregator.cast_vote_for_poll(poll.id, user_id, choice)
          :ok
        else
          {:error, :invalid_choice}
        end
    end
  end

  @doc "Obtiene el estado actual de los votos para una encuesta específica."
  def get_results(poll_id) do
    VoteAggregator.get_results(poll_id)
  end

  defp get_poll_with_event_status(poll_id) do
    from(p in Poll,
      join: e in assoc(p, :event),
      where: p.id == ^poll_id,
      select: {p, e.status}
    )
    |> Repo.one()
  end
end
