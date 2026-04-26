defmodule EventPulse.Events do
  @moduledoc """
  The Events context.
  """

  import Ecto.Query, warn: false
  alias EventPulse.Repo
  alias EventPulse.Events.Event
  alias EventPulse.SocialFeeling.Worker, as: SocialFeelingWorker

  def list_events do
    Repo.all(Event)
  end

  def list_events_by_category(category) do
    Event
    |> where([e], e.category == ^category)
    |> Repo.all()
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
