defmodule EventPulse.Events do
  @moduledoc """
  The Events context.
  """

  import Ecto.Query, warn: false
  alias EventPulse.Repo
  alias EventPulse.Events.Event
  alias EventPulse.ChatBuffer
  alias EventPulse.SocialFeeling.Worker, as: SocialFeelingWorker
  alias EventPulse.Votes.Poll

  def list_events do
    list_events_filtered(nil, nil)
  end

  def list_events_by_category(category) do
    list_events_filtered(category, nil)
  end

  @doc """
  Lista eventos con filtros opcionales por categoría y/o estado.
  Ordenados por `starts_at` ascendente.
  """
  def list_events_filtered(category \\ nil, status \\ nil) do
    Event
    |> maybe_filter_category(category)
    |> maybe_filter_status(status)
    |> order_by([e], asc: e.starts_at)
    |> Repo.all()
  end

  defp maybe_filter_category(query, nil), do: query

  defp maybe_filter_category(query, category) do
    where(query, [e], e.category == ^category)
  end

  defp maybe_filter_status(query, nil), do: query

  defp maybe_filter_status(query, status) do
    where(query, [e], e.status == ^status)
  end

  def get_event(id) when is_integer(id) do
    case Repo.get(Event, id) do
      nil -> :error
      %Event{} = event -> {:ok, event}
    end
  end

  def get_event!(id), do: Repo.get!(Event, id)

  def create_event(attrs \\ %{}) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end

  def update_event(%Event{} = event, attrs) do
    event
    |> Event.changeset(attrs)
    |> Repo.update()
  end

  def delete_event(%Event{} = event) do
    Repo.delete(event)
  end

  def close_event(%Event{} = event) do
    Repo.transaction(fn ->
      current = Repo.get!(Event, event.id, lock: "FOR UPDATE")

      if current.status == "finalizado" do
        {current, false}
      else
        {:ok, updated} =
          current
          |> Event.changeset(%{status: "finalizado"})
          |> Repo.update()

        close_event_polls(updated.id)
        {updated, true}
      end
    end)
    |> case do
      {:ok, {updated, just_closed?}} ->
        broadcast_status_changed(updated)

        if just_closed? do
          _ = ChatBuffer.delete_buffer(Integer.to_string(updated.id))
          SocialFeelingWorker.process_event(updated.id)
        end

        {:ok, updated}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def update_event_status(%Event{} = event, "finalizado"), do: close_event(event)

  def update_event_status(%Event{} = event, new_status) do
    event
    |> Event.changeset(%{status: new_status})
    |> Repo.update()
    |> case do
      {:ok, updated} ->
        broadcast_status_changed(updated)

        if updated.status == "finalizado" do
          _ = ChatBuffer.delete_buffer(Integer.to_string(updated.id))
          SocialFeelingWorker.process_event(updated.id)
        end

        {:ok, updated}

      error ->
        error
    end
  end

  def change_event(%Event{} = event, attrs \\ %{}) do
    Event.changeset(event, attrs)
  end

  defp close_event_polls(event_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(p in Poll, where: p.event_id == ^event_id and p.status != "closed")
    |> Repo.update_all(set: [status: "closed", updated_at: now])
  end

  defp broadcast_status_changed(%Event{} = event) do
    Phoenix.PubSub.broadcast(
      EventPulse.PubSub,
      "events:#{event.id}",
      {:status_changed, event}
    )
  end
end
