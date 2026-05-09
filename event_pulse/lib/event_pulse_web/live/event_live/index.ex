defmodule EventPulseWeb.EventLive.Index do
  use EventPulseWeb, :live_view

  alias EventPulse.Events

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(EventPulse.PubSub, "events:updates")
    end

    {:ok, assign(socket, events: Events.list_events(), category_filter: "")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    category = Map.get(params, "category", "")

    events =
      if category == "" do
        Events.list_events()
      else
        Events.list_events_by_category(category)
      end

    {:noreply, assign(socket, events: events, category_filter: category)}
  end

  @impl true
  def handle_event("filter_category", %{"category" => category}, socket) do
    {:noreply, push_patch(socket, to: ~p"/events?category=#{category}")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    if admin?(socket) do
      event = Events.get_event!(id)
      {:ok, _} = Events.delete_event(event)
      {:noreply, assign(socket, events: Events.list_events())}
    else
      {:noreply, put_flash(socket, :error, "No autorizado")}
    end
  end

  @impl true
  def handle_info({:status_changed, _event}, socket) do
    {:noreply, assign(socket, events: Events.list_events())}
  end

  defp admin?(socket) do
    socket.assigns[:current_user] &&
      socket.assigns.current_user.role == "admin"
  end
end