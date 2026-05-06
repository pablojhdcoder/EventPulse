defmodule EventPulse.Events do
  @moduledoc """
  The Events context.
  """

  import Ecto.Query, warn: false
  alias EventPulse.Repo
  alias EventPulse.Events.Event
  alias EventPulse.ChatBuffer
  alias EventPulse.SocialFeeling.Worker, as: SocialFeelingWorker

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
    update_event_status(event, "finalizado")
  end

  def update_event_status(%Event{} = event, new_status) do
    event
    |> Event.changeset(%{status: new_status})
    |> Repo.update()
    |> case do
      {:ok, updated} ->
        Phoenix.PubSub.broadcast(
          EventPulse.PubSub,
          "events:#{updated.id}",
          {:status_changed, updated}
        )

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
end
