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
  def show(%{event: event} = assigns) do
    %{data: data(event, assigns)}
  end

  defp data(%Event{} = event), do: data(event, %{})

  defp data(%Event{} = event, assigns) do
    base = %{
      id: event.id,
      title: event.title,
      description: event.description,
      category: event.category,
      status: event.status,
      starts_at: event.starts_at,
      ends_at: event.ends_at
    }

    if event.status == "finalizado" do
      base
      |> Map.put(:social_feeling_label, Map.get(assigns, :social_feeling_label))
      |> Map.put(:voting_results, Map.get(assigns, :voting_results, []))
    else
      base
    end
  end
end
