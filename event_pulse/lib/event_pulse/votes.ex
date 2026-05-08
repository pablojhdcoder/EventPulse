defmodule EventPulse.Votes do
  import Ecto.Query
  alias EventPulse.Repo
  alias EventPulse.Votes.{Poll, VoteAggregator}
  # --- Polls ---

  @doc "Crea una votación para un evento"
  def create_poll(event_id, question, options) do
    %Poll{}
    |> Poll.changeset(%{event_id: event_id, question: question, options: options})
    |> Repo.insert()
  end

  @doc "Obtiene todas las votaciones de un evento"
  def list_polls(event_id) do
    Repo.all(from p in Poll, where: p.event_id == ^event_id)
  end

  @doc "Cierra una votación"
  def close_poll(poll_id) do
    case Repo.get(Poll, poll_id) do
      nil -> {:error, :not_found}
      poll ->
        poll
        |> Poll.changeset(%{status: "closed"})
        |> Repo.update()
    end
  end

  # --- Votos ---

  @doc "Registra un voto en una votación abierta"
  def cast_vote(poll_id, user_id, choice) do
    case Repo.get(Poll, poll_id) do
      nil -> {:error, :not_found}
      %Poll{status: "closed"} -> {:error, :poll_closed}
      %Poll{options: options} ->
        if choice in options do
          VoteAggregator.cast_vote(poll_id, user_id, choice)
          :ok
        else
          {:error, :invalid_choice}
        end
    end
  end

  @doc "Obtiene el recuento actual de una votación"
  def get_results(poll_id) do
    VoteAggregator.get_results(poll_id)
  end

  @doc "Obtiene los resultados de todas las votaciones de un evento"
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
