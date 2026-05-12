defmodule EventPulseWeb.EventLive.Index do
  @moduledoc """
  Listado de eventos con filtro por categoría, refresco vía PubSub y acciones de administración.
  """

  use EventPulseWeb, :live_view

  alias EventPulse.Accounts.Auth
  alias EventPulse.Events

  @impl true
  def mount(_params, session, socket) do
    session_uid = Map.get(session, "user_id") || Map.get(session, :user_id)
    current_user = if session_uid, do: Auth.get_user(session_uid), else: nil

    if is_nil(current_user) do
      {:ok,
       push_navigate(socket, to: ~p"/login")
       |> put_flash(:error, "Debes iniciar sesión para acceder.")}
    else
      socket =
        socket
        |> assign(:current_user, current_user)
        |> assign(:events, Events.list_events())
        |> assign(:category_filter, "")

      socket =
        if connected?(socket) do
          Phoenix.PubSub.subscribe(EventPulse.PubSub, "events:updates")
          socket
        else
          socket
        end

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    category = params |> Map.get("category", "") |> to_string()

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
    path =
      if category == "" do
        ~p"/events"
      else
        ~p"/events?#{[category: category]}"
      end

    {:noreply, push_patch(socket, to: path)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    if admin?(socket.assigns.current_user) do
      event = Events.get_event!(id)
      {:ok, _} = Events.delete_event(event)

      events =
        if socket.assigns.category_filter == "" do
          Events.list_events()
        else
          Events.list_events_by_category(socket.assigns.category_filter)
        end

      {:noreply, assign(socket, events: events)}
    else
      {:noreply, put_flash(socket, :error, "No autorizado")}
    end
  end

  @impl true
  def handle_info({:status_changed, _event}, socket) do
    {:noreply, assign(socket, :events, reload_events(socket))}
  end

  def handle_info(:events_catalog_changed, socket) do
    {:noreply, assign(socket, :events, reload_events(socket))}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp reload_events(socket) do
    if socket.assigns.category_filter == "" do
      Events.list_events()
    else
      Events.list_events_by_category(socket.assigns.category_filter)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1.25rem;flex-wrap:wrap;gap:0.75rem;">
        <h1 style="font-size:1.5rem;font-weight:700;margin:0;">Todos los eventos</h1>
        <a
          :if={admin?(@current_user)}
          href={~p"/events/new"}
          style="display:inline-block;background:#2563eb;color:#fff;padding:0.45rem 0.9rem;border-radius:0.375rem;font-size:0.875rem;font-weight:600;"
        >
          + Nuevo evento
        </a>
      </div>

      <form phx-change="filter_category" style="margin-bottom:1rem;">
        <label for="category-filter" style="font-size:0.875rem;color:#64748b;margin-right:0.5rem;">
          Categoría
        </label>
        <select
          id="category-filter"
          name="category"
          style="border:1px solid #cbd5e1;border-radius:0.375rem;padding:0.4rem 0.6rem;font-size:0.875rem;"
        >
          <option value="" selected={@category_filter == ""}>Todas</option>
          <option value="deportes" selected={@category_filter == "deportes"}>Deportes</option>
          <option value="musica" selected={@category_filter == "musica"}>Música</option>
          <option value="politica" selected={@category_filter == "politica"}>Política</option>
          <option value="cultura" selected={@category_filter == "cultura"}>Cultura</option>
        </select>
      </form>

      <div :if={@events == []} style="color:#64748b;">
        No hay eventos registrados.
      </div>

      <ul style="list-style:none;padding:0;display:flex;flex-direction:column;gap:0.75rem;">
        <li
          :for={event <- @events}
          style="background:#fff;border-radius:0.5rem;padding:1rem 1.25rem;box-shadow:0 1px 3px rgba(0,0,0,.08);"
        >
          <div style="display:flex;align-items:center;justify-content:space-between;gap:1rem;flex-wrap:wrap;">
            <div style="flex:1;min-width:200px;">
              <a href={~p"/events/#{event.id}"} style="font-weight:600;font-size:1.05rem;">
                {event.title}
              </a>
              <p style="margin:0.25rem 0 0;color:#64748b;font-size:0.85rem;">
                {event.category}
                <span :if={event.starts_at} style="margin-left:0.5rem;">
                  · {Calendar.strftime(event.starts_at, "%d/%m/%Y %H:%M")} UTC
                </span>
              </p>
              <p :if={event.description} style="margin:0.25rem 0 0;font-size:0.875rem;">
                {event.description}
              </p>
            </div>
            <div style="display:flex;align-items:center;gap:0.75rem;">
              <span style={status_style(event.status)}>{event.status}</span>
              <div :if={admin?(@current_user)} style="display:flex;gap:0.5rem;align-items:center;">
                <a href={~p"/events/#{event.id}/edit"} style="font-size:0.8rem;color:#d97706;font-weight:600;">
                  Editar
                </a>
                <button
                  type="button"
                  phx-click="delete"
                  phx-value-id={event.id}
                  data-confirm="¿Eliminar este evento?"
                  style="font-size:0.8rem;color:#dc2626;background:none;border:none;cursor:pointer;padding:0;"
                >
                  Eliminar
                </button>
              </div>
            </div>
          </div>
        </li>
      </ul>
    </Layouts.app>
    """
  end

  defp admin?(nil), do: false
  defp admin?(%{role: "admin"}), do: true
  defp admin?(_), do: false

  defp status_style("en_directo"),
    do:
      "background:#dcfce7;color:#166534;border-radius:9999px;padding:0.2rem 0.65rem;font-size:0.75rem;font-weight:600;white-space:nowrap;"

  defp status_style("programado"),
    do:
      "background:#e0e7ff;color:#3730a3;border-radius:9999px;padding:0.2rem 0.65rem;font-size:0.75rem;font-weight:600;white-space:nowrap;"

  defp status_style(_),
    do:
      "background:#f1f5f9;color:#475569;border-radius:9999px;padding:0.2rem 0.65rem;font-size:0.75rem;font-weight:600;white-space:nowrap;"
end
