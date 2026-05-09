defmodule EventPulseWeb.EventLive.Show do
  use EventPulseWeb, :live_view

  alias EventPulse.Events

  @valid_transitions %{
    "programado" => ["en_directo"],
    "en_directo" => ["finalizado"],
    "finalizado" => []
  }

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    event = Events.get_event!(id)
    if connected?(socket) do
      Phoenix.PubSub.subscribe(EventPulse.PubSub, "events:#{id}")
    end
    {:ok, assign(socket, event: event, valid_transitions: @valid_transitions)}
  end

  @impl true
  def handle_event("change_status", %{"status" => new_status}, socket) do
    if admin?(socket) do
      case Events.update_event_status(socket.assigns.event, new_status) do
        {:ok, updated} ->
          {:noreply, assign(socket, event: updated)}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Transición inválida")}
      end
    else
      {:noreply, put_flash(socket, :error, "No autorizado")}
    end
  end

  @impl true
  def handle_info({:status_changed, updated_event}, socket) do
    {:noreply, assign(socket, event: updated_event)}
  end

  defp admin?(socket) do
    socket.assigns[:current_user] &&
      socket.assigns.current_user.role == "admin"
  end
end