defmodule EventPulseWeb.EventLive.Form do
  use EventPulseWeb, :live_view

  alias EventPulse.Events
  alias EventPulse.Events.Event

  @impl true
  def mount(params, _session, socket) do
    if admin?(socket) do
      event =
        case Map.get(params, "id") do
          nil -> %Event{}
          id -> Events.get_event!(id)
        end

      changeset = Events.change_event(event)
      {:ok, assign(socket, event: event, form: to_form(changeset))}
    else
      {:ok,
       socket
       |> put_flash(:error, "No autorizado")
       |> redirect(to: ~p"/events")}
    end
  end

  @impl true
  def handle_event("validate", %{"event" => params}, socket) do
    changeset = Events.change_event(socket.assigns.event, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  @impl true
  def handle_event("save", %{"event" => params}, socket) do
    case save_event(socket.assigns.event, params) do
      {:ok, event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Evento guardado correctamente")
         |> redirect(to: ~p"/events/#{event.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_event(%Event{id: nil}, params), do: Events.create_event(params)
  defp save_event(event, params), do: Events.update_event(event, params)

  defp admin?(socket) do
    socket.assigns[:current_user] &&
      socket.assigns.current_user.role == "admin"
  end
end
