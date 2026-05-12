defmodule EventPulseWeb.EventLive.Form do
  use EventPulseWeb, :live_view

  alias EventPulse.Accounts.Auth
  alias EventPulse.Events
  alias EventPulse.Events.Event

  @impl true
  def mount(params, session, socket) do
    session_uid = Map.get(session, "user_id") || Map.get(session, :user_id)
    current_user = if session_uid, do: Auth.get_user(session_uid), else: nil
    socket = assign(socket, :current_user, current_user)

    cond do
      is_nil(current_user) ->
        {:ok,
         push_navigate(socket, to: ~p"/login")
         |> put_flash(:error, "Debes iniciar sesión para acceder.")}

      !admin?(socket) ->
        {:ok,
         push_navigate(socket, to: ~p"/events")
         |> put_flash(:error, "No autorizado")}

      true ->
        {event, mode} =
          case Map.get(params, "id") do
            nil ->
              {%Event{}, :new}

            id ->
              {Events.get_event!(id), :edit}
          end

        changeset = Events.change_event(event)

        {:ok,
         assign(socket,
           event: event,
           form: to_form(changeset),
           mode: mode
         )}
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
    socket.assigns[:current_user] && socket.assigns.current_user.role == "admin"
  end
end
