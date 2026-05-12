defmodule EventPulseWeb.EventLive.Show do
  @moduledoc """
  Vista LiveView de un evento: chat y recuento de votos en tiempo real vía PubSub.

  Identidad: El usuario autenticado se obtiene de current_user, asignado por
  el plug RequireAuth antes de entrar a esta vista. Se usa su username como
  autor en el chat y su id para registrar los votos.

  Mensajes PubSub:
  - `{:new_message, message}` — chat (`EventPulse.Chat.EventRoom`)
  - `{:voted, results}` — votos (`VoteAggregator`, tópico `poll:<id>`)
  - `{:status_changed, event}` — cambio de estado (`EventPulse.Events`)
  """

  use EventPulseWeb, :live_view

  alias EventPulse.Chat.EventRoom
  alias EventPulse.Events
  alias EventPulse.SocialFeeling
  alias EventPulse.Votes
  alias EventPulse.Votes.VoteAggregator

  @max_body_length Application.compile_env(:event_pulse, :chat_max_body_length, 500)
  @valid_transitions %{
    "programado" => ["en_directo"],
    "en_directo" => ["finalizado"],
    "finalizado" => []
  }

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(%{"id" => id_str}, _session, socket) do
    case Integer.parse(id_str) do
      {event_id, ""} ->
        case Events.get_event(event_id) do
          {:ok, event} ->
            event_key = Integer.to_string(event_id)
            poll = primary_open_poll(event_id)

            current_user = socket.assigns.current_user

            vote_results =
              if poll, do: VoteAggregator.get_results(poll.id), else: %{}

            socket =
              socket
              |> assign(:event, event)
              |> assign(:event_key, event_key)
              |> assign(:current_user, current_user)
              |> assign(:valid_transitions, @valid_transitions)
              |> assign(:poll, poll)
              |> assign(:social_feeling, SocialFeeling.get_for_event(event_id))
              |> assign(:vote_results, vote_results)
              |> assign(:draft, "")
              |> assign(:max_body_length, @max_body_length)
              |> stream(:messages, [], dom_id: &message_dom_id/1)

            socket =
              if connected?(socket) do
                Phoenix.PubSub.subscribe(EventPulse.PubSub, "event:#{event_key}")
                Phoenix.PubSub.subscribe(EventPulse.PubSub, "events:#{event_id}")

                if poll do
                  Phoenix.PubSub.subscribe(EventPulse.PubSub, "poll:#{poll.id}")
                end

                history = EventRoom.recent_messages(event_key)
                stream(socket, :messages, history, reset: true)
              else
                socket
              end

            {:ok, socket}

          :error ->
            {:ok, push_navigate(socket, to: ~p"/") |> put_flash(:error, "Evento no encontrado.")}
        end

      _ ->
        {:ok, push_navigate(socket, to: ~p"/") |> put_flash(:error, "ID de evento inválido.")}
    end
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <%!-- Cabecera del evento --%>
      <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:1rem;margin-bottom:1.5rem;">
        <div>
          <h1 style="font-size:1.5rem;font-weight:700;margin:0.4rem 0 0.25rem;">{@event.title}</h1>
          <p style="color:#64748b;font-size:0.875rem;">
            {@event.category}
            <span :if={@event.starts_at} style="margin-left:0.5rem;">
              · {Calendar.strftime(@event.starts_at, "%d/%m/%Y %H:%M")} UTC
            </span>
          </p>
          <p :if={@event.description} style="margin-top:0.5rem;">{@event.description}</p>
        </div>
        <span style={status_style(@event.status)}>{@event.status}</span>
      </div>

      <div :if={admin_user?(@current_user)} style="margin:-0.5rem 0 1.5rem;display:flex;align-items:center;gap:0.75rem;flex-wrap:wrap;">
        <span style="font-size:0.875rem;font-weight:600;color:#475569;">Cambiar estado:</span>
        <button
          :for={next_status <- Map.get(@valid_transitions, @event.status, [])}
          phx-click="change_status"
          phx-value-status={next_status}
          style="background:#16a34a;color:white;padding:0.4rem 0.75rem;border-radius:0.375rem;border:none;cursor:pointer;"
        >
          → {next_status}
        </button>
        <a href={~p"/events/#{@event.id}/edit"} style="color:#d97706;font-size:0.875rem;">
          Editar evento
        </a>
      </div>

      <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:1.5rem;">
        <%!-- Panel de votación --%>
        <section style="background:#fff;border-radius:0.5rem;padding:1.25rem;box-shadow:0 1px 3px rgba(0,0,0,.08);">
          <h2 style="font-size:1rem;font-weight:600;margin:0 0 1rem;">Votación</h2>

          <div :if={@event.status == "en_directo" && @poll} style="display:flex;flex-direction:column;gap:0.5rem;margin-bottom:1rem;">
            <p style="margin:0 0 0.25rem;color:#475569;font-size:0.875rem;font-weight:600;">
              {@poll.question}
            </p>
            <.vote_button :for={choice <- @poll.options} choice={choice} />
          </div>

          <div :if={@event.status == "en_directo" && !@poll} style="color:#64748b;font-size:0.875rem;margin-bottom:1rem;">
            No hay una votación abierta para este evento.
          </div>

          <div :if={@event.status != "en_directo"} style="color:#64748b;font-size:0.875rem;margin-bottom:1rem;">
            Las votaciones solo están abiertas cuando el evento está en directo.
          </div>

          <div :if={map_size(@vote_results) > 0}>
            <h3 style="font-size:0.875rem;font-weight:600;margin:0 0 0.5rem;color:#475569;">Recuento actual</h3>
            <ul style="list-style:none;padding:0;display:flex;flex-direction:column;gap:0.375rem;">
              <li :for={{choice, count} <- Enum.sort(@vote_results)} style="display:flex;justify-content:space-between;">
                <span style="font-size:0.875rem;">{choice}</span>
                <span style="font-weight:700;font-size:0.875rem;">{count}</span>
              </li>
            </ul>
          </div>

          <div :if={map_size(@vote_results) == 0} style="color:#94a3b8;font-size:0.875rem;">
            Sin votos aún.
          </div>
        </section>

        <%!-- Resultado final --%>
        <section :if={@event.status == "finalizado"} style="background:#fff;border-radius:0.5rem;padding:1.25rem;box-shadow:0 1px 3px rgba(0,0,0,.08);">
          <h2 style="font-size:1rem;font-weight:600;margin:0 0 1rem;">Social Feeling final</h2>

          <div :if={@social_feeling}>
            <p style="font-size:0.875rem;color:#64748b;margin:0 0 0.5rem;">Resultado consolidado del evento.</p>
            <p style="margin:0 0 0.5rem;">
              <span style="font-weight:600;">Etiqueta:</span> {@social_feeling.label}
            </p>
            <p style="margin:0 0 0.5rem;">
              <span style="font-weight:600;">Score:</span> {@social_feeling.score}
            </p>
            <p style="margin:0;">
              <span style="font-weight:600;">Votos totales:</span> {@social_feeling.total_votes}
            </p>
          </div>

          <p :if={!@social_feeling} style="color:#94a3b8;font-size:0.875rem;margin:0;">
            Calculando resultado final…
          </p>
        </section>

        <%!-- Panel de chat --%>
        <section style="background:#fff;border-radius:0.5rem;padding:1.25rem;box-shadow:0 1px 3px rgba(0,0,0,.08);display:flex;flex-direction:column;gap:0.75rem;">
          <h2 style="font-size:1rem;font-weight:600;margin:0;">Chat en directo</h2>

          <div
            id="messages"
            phx-update="stream"
            phx-hook="AutoScrollChat"
            style="flex:1;min-height:220px;max-height:340px;overflow-y:auto;display:flex;flex-direction:column;gap:0.375rem;padding:0.5rem;border:1px solid #e2e8f0;border-radius:0.375rem;background:#f8fafc;"
          >
            <div
              :for={{dom_id, msg} <- @streams.messages}
              id={dom_id}
              style="font-size:0.85rem;word-break:break-word;"
            >
              <span style="font-weight:600;color:#4f46e5;">{msg.author}</span>
              <span style="color:#64748b;font-size:0.75rem;margin:0 0.3rem;">
                {format_time(msg.inserted_at)}
              </span>
              <span>{msg.body}</span>
            </div>
          </div>

          <form
            :if={@event.status == "en_directo"}
            phx-submit="send_message"
            phx-change="update_draft"
            style="display:flex;gap:0.5rem;"
          >
            <label for="chat-message-body" style="position:absolute;left:-10000px;top:auto;width:1px;height:1px;overflow:hidden;">
              Mensaje del chat
            </label>
            <input
              id="chat-message-body"
              type="text"
              name="body"
              value={@draft}
              placeholder="Escribe un mensaje…"
              autocomplete="off"
              maxlength={@max_body_length}
              style="flex:1;border:1px solid #cbd5e1;border-radius:0.375rem;padding:0.4rem 0.6rem;font-size:0.875rem;"
            />
            <button
              type="submit"
              style="background:#4f46e5;color:#fff;border:none;border-radius:0.375rem;padding:0.4rem 0.9rem;font-size:0.875rem;cursor:pointer;"
            >
              Enviar
            </button>
          </form>

          <p :if={@event.status != "en_directo"} style="color:#94a3b8;font-size:0.875rem;">
            El chat solo está activo cuando el evento está en directo.
          </p>
        </section>
      </div>
    </Layouts.app>
    """
  end

  # Small helper component for vote buttons
  defp vote_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="cast_vote"
      phx-value-choice={@choice}
      style="text-align:left;background:#f0f9ff;border:1px solid #bae6fd;border-radius:0.375rem;padding:0.4rem 0.75rem;font-size:0.875rem;cursor:pointer;"
    >
      Votar: {@choice}
    </button>
    """
  end

  # ---------------------------------------------------------------------------
  # handle_event
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("send_message", %{"body" => body}, socket) do
    if socket.assigns.event.status == "en_directo" do
      # Cambiamos
      author = socket.assigns.current_user.username

      case EventRoom.send_message(socket.assigns.event_key, %{author: author, body: body}) do
        :ok ->
          {:noreply, assign(socket, :draft, "")}

        {:error, :empty_body} ->
          {:noreply, put_flash(socket, :error, "El mensaje no puede estar vacío.")}

        {:error, :body_too_long} ->
          {:noreply, put_flash(socket, :error, "Mensaje demasiado largo.")}
      end
    else
      {:noreply, put_flash(socket, :error, "El chat solo está activo en eventos en directo.")}
    end
  end

  def handle_event("update_draft", %{"body" => body}, socket) do
    {:noreply, assign(socket, :draft, body)}
  end

  def handle_event("change_status", %{"status" => new_status}, socket) do
    if admin_user?(socket.assigns.current_user) do
      case Events.update_event_status(socket.assigns.event, new_status) do
        {:ok, updated} ->
          {:noreply, assign(socket, :event, updated)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Transición inválida")}
      end
    else
      {:noreply, put_flash(socket, :error, "No autorizado")}
    end
  end

  def handle_event("cast_vote", %{"choice" => choice}, socket) do
    poll = socket.assigns.poll

    cond do
      socket.assigns.event.status != "en_directo" ->
        {:noreply,
         put_flash(socket, :error, "Las votaciones solo están abiertas en eventos en directo.")}

      is_nil(poll) ->
        {:noreply, put_flash(socket, :error, "No hay votación activa.")}

      true ->
        user_id = socket.assigns.current_user.id

        case Votes.cast_vote(poll.id, user_id, choice) do
          :ok ->
            {:noreply, socket}

          {:error, :invalid_choice} ->
            {:noreply, put_flash(socket, :error, "Opción de voto no válida.")}

          {:error, :poll_closed} ->
            {:noreply, put_flash(socket, :error, "La votación está cerrada.")}

          {:error, :event_not_live} ->
            {:noreply, put_flash(socket, :error, "El evento ya no está en directo.")}

          {:error, :not_found} ->
            {:noreply, put_flash(socket, :error, "Votación no encontrada.")}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # handle_info (PubSub)
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({:new_message, message}, socket) do
    {:noreply, stream_insert(socket, :messages, message)}
  end

  def handle_info({:voted, results}, socket) do
    {:noreply, assign(socket, :vote_results, results)}
  end

  def handle_info({:social_feeling, result}, socket) do
    {:noreply, assign(socket, :social_feeling, result)}
  end

  def handle_info({:status_changed, updated_event}, socket) do
    old_poll_id = socket.assigns.poll && socket.assigns.poll.id
    event_id = updated_event.id
    poll = primary_open_poll(event_id)
    vote_results = if poll, do: VoteAggregator.get_results(poll.id), else: %{}

    socket =
      socket
      |> assign(:event, updated_event)
      |> assign(:poll, poll)
      |> assign(:social_feeling, SocialFeeling.get_for_event(event_id))
      |> assign(:vote_results, vote_results)

    socket =
      if connected?(socket) do
        new_poll_id = poll && poll.id

        if old_poll_id && old_poll_id != new_poll_id do
          Phoenix.PubSub.unsubscribe(EventPulse.PubSub, "poll:#{old_poll_id}")
        end

        if new_poll_id && new_poll_id != old_poll_id do
          Phoenix.PubSub.subscribe(EventPulse.PubSub, "poll:#{new_poll_id}")
        end

        socket
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp primary_open_poll(event_id) do
    event_id
    |> Votes.list_polls()
    |> Enum.filter(&(&1.status == "open"))
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
    |> List.first()
  end

  defp message_dom_id(%{id: id}) when is_integer(id), do: "msg-#{id}"

  defp message_dom_id(%{inserted_at: ts, author: author, body: body}) do
    hash = :erlang.phash2({ts, author, body})
    "msg-#{hash}"
  end

  defp format_time(nil), do: ""

  defp format_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%H:%M")
  end

  defp format_time(_), do: ""

  defp status_style("en_directo"),
    do:
      "background:#dcfce7;color:#166534;border-radius:9999px;padding:0.25rem 0.75rem;font-size:0.8rem;font-weight:600;white-space:nowrap;"

  defp status_style("programado"),
    do:
      "background:#e0e7ff;color:#3730a3;border-radius:9999px;padding:0.25rem 0.75rem;font-size:0.8rem;font-weight:600;white-space:nowrap;"

  defp status_style(_),
    do:
      "background:#f1f5f9;color:#475569;border-radius:9999px;padding:0.25rem 0.75rem;font-size:0.8rem;font-weight:600;white-space:nowrap;"

  defp admin_user?(%{role: "admin"}), do: true
  defp admin_user?(_), do: false
end
