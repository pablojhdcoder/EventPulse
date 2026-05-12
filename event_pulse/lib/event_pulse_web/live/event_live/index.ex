defmodule EventPulseWeb.EventLive.Index do
  @moduledoc """
  Lista eventos, permite filtrarlos por categoría y muestra acciones de
  administración cuando el usuario autenticado tiene rol admin.
  """

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

  def handle_event("delete", %{"id" => id}, socket) do
    if admin_socket?(socket) do
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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div style="display:flex;justify-content:space-between;align-items:center;gap:1rem;margin-bottom:1.25rem;">
        <h1 style="font-size:1.5rem;font-weight:700;margin:0;">Todos los eventos</h1>
        <a
          :if={admin_user?(@current_user)}
          href={~p"/events/new"}
          style="background:#2563eb;color:white;padding:0.5rem 1rem;border-radius:0.375rem;text-decoration:none;"
        >
          + Nuevo Evento
        </a>
      </div>

      <form phx-change="filter_category" style="margin-bottom:1rem;">
        <select name="category" style="border:1px solid #d1d5db;border-radius:0.375rem;padding:0.5rem;">
          <option value="" selected={@category_filter == ""}>Todas las categorías</option>
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
          <div style="display:flex;align-items:center;justify-content:space-between;gap:1rem;">
            <div>
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
            <div style="display:flex;align-items:center;gap:0.5rem;flex-wrap:wrap;justify-content:flex-end;">
              <span style={status_style(event.status)}>{event.status}</span>
              <a href={~p"/events/#{event.id}"} style="color:#2563eb;">Ver</a>
              <a :if={admin_user?(@current_user)} href={~p"/events/#{event.id}/edit"} style="color:#d97706;">Editar</a>
              <button
                :if={admin_user?(@current_user)}
                phx-click="delete"
                phx-value-id={event.id}
                data-confirm="¿Eliminar este evento?"
                style="color:#dc2626;background:none;border:none;cursor:pointer;padding:0;"
              >
                Eliminar
              </button>
            </div>
          </div>
        </li>
      </ul>
    </Layouts.app>
    """
  end

  defp admin_user?(%{role: "admin"}), do: true
  defp admin_user?(_), do: false

  defp admin_socket?(socket) do
    admin_user?(socket.assigns[:current_user])
  end

  def status_style("en_directo"),
    do:
      "background:#dcfce7;color:#166534;border-radius:9999px;padding:0.2rem 0.65rem;font-size:0.75rem;font-weight:600;white-space:nowrap;"

  def status_style("programado"),
    do:
      "background:#e0e7ff;color:#3730a3;border-radius:9999px;padding:0.2rem 0.65rem;font-size:0.75rem;font-weight:600;white-space:nowrap;"

  def status_style(_),
    do:
      "background:#f1f5f9;color:#475569;border-radius:9999px;padding:0.2rem 0.65rem;font-size:0.75rem;font-weight:600;white-space:nowrap;"
end
