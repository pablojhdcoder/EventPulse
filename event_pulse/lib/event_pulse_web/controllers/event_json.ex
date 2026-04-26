defmodule EventPulseWeb.EventJSON do
  alias EventPulse.Events.Event

  @doc """
  Renders a list of events.
  """
  def index(%{events: events}) do
    %{data: for(event <- events, do: data(event))}
  end

  @doc """
  Renders a single event.
  """
  def show(%{event: event}) do
    %{data: data(event)}
  end

  defp data(%Event{} = event) do
    %{
      id: event.id,
      title: event.title,
      description: event.description,
      category: event.category,
      status: event.status,
      starts_at: event.starts_at,
      ends_at: event.ends_at
    }
  end
end
