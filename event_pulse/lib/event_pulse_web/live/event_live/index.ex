defmodule EventPulseWeb.EventLive.Index do
  @moduledoc """
  Lists all events and links each one to its live page.
  """

  use EventPulseWeb, :live_view

  alias EventPulse.Events

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :events, Events.list_events())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1 style="font-size:1.5rem;font-weight:700;margin-bottom:1.25rem;">Todos los eventos</h1>

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
            <span style={status_style(event.status)}>{event.status}</span>
          </div>
        </li>
      </ul>
    </Layouts.app>
    """
  end

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
