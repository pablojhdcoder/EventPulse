defmodule EventPulseWeb.EventController do
  use EventPulseWeb, :controller

  alias EventPulse.Events
  alias EventPulse.Events.Event

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
    render(conn, :show, event: event)
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
end
