defmodule EventPulseWeb.EventController do
  use EventPulseWeb, :controller

  alias EventPulse.Events
  alias EventPulse.Events.Event
  alias EventPulse.SocialFeeling
  alias EventPulse.Votes

  action_fallback EventPulseWeb.FallbackController

  def index(conn, params) do
    events =
      case Map.get(params, "category") do
        nil -> Events.list_events()
        category -> Events.list_events_by_category(category)
      end

    render(conn, :index, events: events)
  end

  def create(conn, %{"event" => event_params}) do
    with {:ok, %Event{} = event} <- Events.create_event(event_params) do
      conn
      |> put_status(:created)
      |> render(:show, event: event)
    end
  end

  def show(conn, %{"id" => id}) do
    event = Events.get_event!(id)

    assigns =
      if event.status == "finalizado" do
        sf = SocialFeeling.get_for_event(event.id)

        [
          event: event,
          social_feeling_label: social_feeling_label_json(sf),
          voting_results: Votes.list_polls_voting_results_for_event(event.id)
        ]
      else
        [event: event]
      end

    render(conn, :show, assigns)
  end

  def update(conn, %{"id" => id, "event" => event_params}) do
    event = Events.get_event!(id)

    with {:ok, %Event{} = event} <- Events.update_event(event, event_params) do
      render(conn, :show, event: event)
    end
  end

  def delete(conn, %{"id" => id}) do
    event = Events.get_event!(id)

    with {:ok, %Event{}} <- Events.delete_event(event) do
      send_resp(conn, :no_content, "")
    end
  end

  def update_status(conn, %{"id" => id, "status" => new_status}) do
    event = Events.get_event!(id)

    with {:ok, %Event{} = event} <- Events.update_event_status(event, new_status) do
      render(conn, :show, event: event)
    end
  end

  defp social_feeling_label_json(nil), do: nil
  defp social_feeling_label_json(%EventPulse.SocialFeeling.Result{label: nil}), do: nil

  defp social_feeling_label_json(%EventPulse.SocialFeeling.Result{label: label}),
    do: SocialFeeling.humanize_label(label)

  defp social_feeling_label_json(_), do: nil
end
