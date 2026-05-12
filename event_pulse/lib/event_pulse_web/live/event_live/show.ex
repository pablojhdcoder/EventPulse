defmodule EventPulseWeb.EventLive.Show do
  @moduledoc """
  Vista LiveView de un evento: chat, votación en tiempo real (poll + `VoteAggregator`)
  y panel Social Feeling vía PubSub.

  El usuario autenticado (`EventPulse.Accounts.Auth`) define el autor en el chat
  (`current_user.username`). Los votos usan el entero `demo_user_id` de sesión
  (`EnsureDemoUserId`) con `Votes.cast_vote/3` porque `Vote.user_id` es numérico.

  Mensajes PubSub:
  - `{:new_message, message}` — chat (`EventPulse.Chat.EventRoom`)
  - `{:voted, results}` — votos (`VoteAggregator`, tópico `poll:<id>`)
  - `{:status_changed, event}` — cambio de estado (`EventPulse.Events`)
  - `{:social_feeling, result}` — resultado consolidado al cerrar
  - `{:event_room_closed, event_id}` — cierre de sala (worker de Social Feeling; mismo tópico `event:<id>` que el chat)
  """

  use EventPulseWeb, :live_view

  alias EventPulse.Accounts.Auth
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
  def mount(%{"id" => id_str}, session, socket) do
    session_uid = Map.get(session, "user_id") || Map.get(session, :user_id)
    current_user = if session_uid, do: Auth.get_user(session_uid), else: nil

    if is_nil(current_user) do
      {:ok,
       push_navigate(socket, to: ~p"/login")
       |> put_flash(:error, "Debes iniciar sesión para acceder.")}
    else
      case Integer.parse(id_str) do
        {event_id, ""} ->
          case Events.get_event(event_id) do
            {:ok, event} ->
              event_key = Integer.to_string(event_id)
              polls = open_polls(event_id)

              demo_user_id =
                normalize_demo_user_id(
                  Map.get(session, "demo_user_id") || Map.get(session, :demo_user_id)
                )

              socket =
                socket
                |> assign(:event, event)
                |> assign(:event_key, event_key)
                |> assign(:polls, polls)
                |> assign(:social_feeling, SocialFeeling.get_for_event(event_id))
                |> assign(:current_user, current_user)
                |> assign(:demo_user_id, demo_user_id)
                |> assign(:vote_results, vote_results_by_poll(polls))
                |> assign(:final_poll_rows, final_poll_rows(event))
                |> assign(:new_poll_form, new_poll_form())
                |> assign(:draft, "")
                |> assign(:max_body_length, @max_body_length)
                |> assign(:valid_transitions, @valid_transitions)
                |> stream(:messages, [], dom_id: &message_dom_id/1)

              socket =
                if connected?(socket) do
                  Phoenix.PubSub.subscribe(EventPulse.PubSub, "event:#{event_key}")
                  Phoenix.PubSub.subscribe(EventPulse.PubSub, "events:#{event_id}")

                  for poll <- polls do
                    Phoenix.PubSub.subscribe(EventPulse.PubSub, "poll:#{poll.id}")
                  end

                  history = EventRoom.recent_messages(event_key)
                  stream(socket, :messages, history, reset: true)
                else
                  socket
                end

              {:ok, socket}

            :error ->
              {:ok,
               push_navigate(socket, to: ~p"/")
               |> put_flash(:error, "Evento no encontrado.")}
          end

        _ ->
          {:ok,
           push_navigate(socket, to: ~p"/")
           |> put_flash(:error, "ID de evento inválido.")}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
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
        <div style="display:flex;flex-direction:column;align-items:flex-end;gap:0.75rem;">
          <span style={status_style(@event.status)}>{@event.status}</span>
          <div :if={admin?(@current_user)} style="display:flex;flex-direction:column;align-items:flex-end;gap:0.5rem;">
            <div style="display:flex;flex-wrap:wrap;gap:0.5rem;justify-content:flex-end;">
              <button
                :for={next_status <- Map.get(@valid_transitions, @event.status, [])}
                type="button"
                phx-click="change_status"
                phx-value-status={next_status}
                style="background:#16a34a;color:#fff;border:none;border-radius:0.375rem;padding:0.35rem 0.75rem;font-size:0.8rem;cursor:pointer;"
              >
                → {next_status}
              </button>
            </div>
            <a
              href={~p"/events/#{@event.id}/edit"}
              style="display:inline-block;background:#d97706;color:#fff;border-radius:0.375rem;padding:0.35rem 0.75rem;font-size:0.8rem;font-weight:600;text-decoration:none;"
            >
              Editar evento
            </a>
          </div>
        </div>
      </div>

      <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:1.5rem;">
        <%!-- Panel de votaciones --%>
        <section style="background:#fff;border-radius:0.5rem;padding:1.25rem;box-shadow:0 1px 3px rgba(0,0,0,.08);">
          <h2 style="font-size:1rem;font-weight:600;margin:0 0 1rem;">Votaciones</h2>

          <div
            :if={@event.status == "en_directo" && @polls != []}
            style="display:flex;flex-direction:column;gap:1rem;margin-bottom:1rem;"
          >
            <article
              :for={poll <- @polls}
              style="border:1px solid #e2e8f0;border-radius:0.5rem;padding:0.75rem;background:#f8fafc;"
            >
              <p style="margin:0 0 0.5rem;color:#475569;font-size:0.875rem;font-weight:700;">
                {poll.question}
              </p>
              <div style="display:flex;flex-direction:column;gap:0.5rem;margin-bottom:0.75rem;">
                <.vote_button :for={choice <- poll.options} poll_id={poll.id} choice={choice} />
              </div>

              <div :if={map_size(Map.get(@vote_results, poll.id, %{})) > 0}>
                <h3 style="font-size:0.8rem;font-weight:600;margin:0 0 0.5rem;color:#475569;">Recuento actual</h3>
                <ul style="list-style:none;padding:0;margin:0;display:flex;flex-direction:column;gap:0.375rem;">
                  <li
                    :for={{choice, count} <- Enum.sort(Map.get(@vote_results, poll.id, %{}))}
                    style="display:flex;justify-content:space-between;"
                  >
                    <span style="font-size:0.875rem;">{choice}</span>
                    <span style="font-weight:700;font-size:0.875rem;">{count}</span>
                  </li>
                </ul>
              </div>

              <div
                :if={map_size(Map.get(@vote_results, poll.id, %{})) == 0}
                style="color:#94a3b8;font-size:0.875rem;"
              >
                Sin votos aún.
              </div>
            </article>
          </div>

          <div :if={@event.status == "en_directo" && @polls == []} style="color:#64748b;font-size:0.875rem;margin-bottom:1rem;">
            No hay votaciones abiertas para este evento.
          </div>

          <div :if={@event.status == "programado"} style="color:#64748b;font-size:0.875rem;margin-bottom:1rem;">
            Las votaciones solo están abiertas cuando el evento está en directo.
          </div>

          <div
            :if={@event.status == "finalizado"}
            style="display:flex;flex-direction:column;gap:1rem;margin-bottom:1rem;"
          >
            <p style="margin:0;color:#64748b;font-size:0.875rem;">
              Resultado final de cada votación (evento cerrado).
            </p>
            <p :if={@final_poll_rows == []} style="color:#64748b;font-size:0.875rem;margin:0;">
              No hubo votaciones en este evento.
            </p>
            <article
              :for={row <- @final_poll_rows}
              style="border:1px solid #e2e8f0;border-radius:0.5rem;padding:0.75rem;background:#f8fafc;"
            >
              <p style="margin:0 0 0.35rem;font-size:0.75rem;font-weight:600;color:#64748b;text-transform:uppercase;">
                Votación finalizada
              </p>
              <p style="margin:0 0 0.75rem;color:#334155;font-size:0.9rem;font-weight:700;">
                {row.poll.question}
              </p>
              <ul style="list-style:none;padding:0;margin:0;display:flex;flex-direction:column;gap:0.375rem;">
                <li
                  :for={choice <- row.poll.options}
                  style="display:flex;justify-content:space-between;font-size:0.875rem;"
                >
                  <span>{choice}</span>
                  <span style="font-weight:700;">{Map.get(row.results, choice, 0)}</span>
                </li>
              </ul>
              <p
                :if={Enum.sum(Map.values(row.results)) == 0}
                style="margin:0.5rem 0 0;color:#94a3b8;font-size:0.8rem;"
              >
                Sin votos registrados en esta encuesta.
              </p>
            </article>
          </div>

          <.new_poll_form :if={@event.status == "en_directo" && admin?(@current_user)} form={@new_poll_form} />
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

        <%!-- Panel de chat (oculto al finalizar el evento) --%>
        <section
          :if={@event.status != "finalizado"}
          style="background:#fff;border-radius:0.5rem;padding:1.25rem;box-shadow:0 1px 3px rgba(0,0,0,.08);display:flex;flex-direction:column;gap:0.75rem;"
        >
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
      phx-value-poll-id={@poll_id}
      phx-value-choice={@choice}
      style="text-align:left;background:#f0f9ff;border:1px solid #bae6fd;border-radius:0.375rem;padding:0.4rem 0.75rem;font-size:0.875rem;cursor:pointer;"
    >
      Votar: {@choice}
    </button>
    """
  end

  defp new_poll_form(assigns) do
    ~H"""
    <form
      phx-change="validate_new_poll"
      phx-submit="create_poll"
      style="border-top:1px solid #e2e8f0;margin-top:1rem;padding-top:1rem;display:flex;flex-direction:column;gap:0.75rem;"
    >
      <h3 style="font-size:0.9rem;font-weight:700;margin:0;">Añadir votación</h3>

      <div>
        <label for="new-poll-question" style="display:block;font-size:0.8rem;font-weight:600;margin-bottom:0.25rem;">Pregunta</label>
        <input
          id="new-poll-question"
          name="poll[question]"
          type="text"
          value={@form.question}
          placeholder="Ej. ¿Qué opción prefieres?"
          style="width:100%;border:1px solid #cbd5e1;border-radius:0.375rem;padding:0.45rem 0.6rem;font-size:0.875rem;"
        />
      </div>

      <div>
        <label for="new-poll-option-count" style="display:block;font-size:0.8rem;font-weight:600;margin-bottom:0.25rem;">Número de opciones</label>
        <select
          id="new-poll-option-count"
          name="poll[option_count]"
          style="width:100%;border:1px solid #cbd5e1;border-radius:0.375rem;padding:0.45rem 0.6rem;font-size:0.875rem;background:#fff;"
        >
          <option value="2" selected={@form.option_count == 2}>2 opciones</option>
          <option value="3" selected={@form.option_count == 3}>3 opciones</option>
          <option value="4" selected={@form.option_count == 4}>4 opciones</option>
        </select>
      </div>

      <div :for={{option, index} <- Enum.with_index(@form.options)}>
        <label for={"new-poll-option-#{index}"} style="display:block;font-size:0.8rem;font-weight:600;margin-bottom:0.25rem;">
          Opción {index + 1}
        </label>
        <input
          id={"new-poll-option-#{index}"}
          name={"poll[options][#{index}]"}
          type="text"
          value={option}
          placeholder={"Texto de la opción #{index + 1}"}
          style="width:100%;border:1px solid #cbd5e1;border-radius:0.375rem;padding:0.45rem 0.6rem;font-size:0.875rem;"
        />
      </div>

      <button
        type="submit"
        style="background:#4f46e5;color:#fff;border:none;border-radius:0.375rem;padding:0.45rem 0.9rem;font-size:0.875rem;font-weight:700;cursor:pointer;"
      >
        Crear votación
      </button>
    </form>
    """
  end

  # ---------------------------------------------------------------------------
  # handle_event
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("send_message", %{"body" => body}, socket) do
    if socket.assigns.event.status == "en_directo" do
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
    if admin?(socket.assigns.current_user) do
      case Events.update_event_status(socket.assigns.event, new_status) do
        {:ok, updated} ->
          {:noreply, assign(socket, :event, updated)}

        {:error, :invalid_transition} ->
          {:noreply,
           put_flash(socket, :error, "No se puede pasar a ese estado desde el estado actual.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "No se pudo cambiar el estado.")}
      end
    else
      {:noreply, put_flash(socket, :error, "No autorizado")}
    end
  end

  def handle_event("validate_new_poll", %{"poll" => params}, socket) do
    {:noreply,
     assign(socket, :new_poll_form, poll_form_from_params(params, socket.assigns.new_poll_form))}
  end

  def handle_event("create_poll", %{"poll" => params}, socket) do
    poll_form = poll_form_from_params(params, socket.assigns.new_poll_form)

    cond do
      !admin?(socket.assigns.current_user) ->
        {:noreply, put_flash(socket, :error, "No autorizado")}

      socket.assigns.event.status != "en_directo" ->
        {:noreply,
         put_flash(socket, :error, "Solo puedes añadir votaciones en eventos en directo.")}

      true ->
        case required_poll_attrs(poll_form) do
          {:ok, %{question: question, options: options}} ->
            case Votes.create_poll(socket.assigns.event.id, question, options) do
              {:ok, poll} ->
                socket = subscribe_to_poll(socket, poll.id)
                polls = open_polls(socket.assigns.event.id)

                {:noreply,
                 socket
                 |> assign(:polls, polls)
                 |> assign(:vote_results, vote_results_by_poll(polls))
                 |> assign(:new_poll_form, new_poll_form())
                 |> put_flash(:info, "Votación creada correctamente.")}

              {:error, _changeset} ->
                {:noreply,
                 socket
                 |> assign(:new_poll_form, poll_form)
                 |> put_flash(
                   :error,
                   "No se pudo crear la votación. Revisa la pregunta y las opciones."
                 )}
            end

          {:error, :invalid_poll} ->
            {:noreply,
             socket
             |> assign(:new_poll_form, poll_form)
             |> put_flash(:error, "La votación debe tener pregunta y al menos dos opciones.")}
        end
    end
  end

  def handle_event("cast_vote", %{"poll-id" => poll_id, "choice" => choice}, socket) do
    poll = Enum.find(socket.assigns.polls, &(Integer.to_string(&1.id) == poll_id))

    cond do
      socket.assigns.event.status != "en_directo" ->
        {:noreply,
         put_flash(socket, :error, "Las votaciones solo están abiertas en eventos en directo.")}

      is_nil(poll) ->
        {:noreply, put_flash(socket, :error, "No hay votación activa.")}

      true ->
        user_id = socket.assigns.demo_user_id

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

  def handle_info({:voted, _results}, socket) do
    polls = open_polls(socket.assigns.event.id)

    {:noreply,
     socket
     |> assign(:polls, polls)
     |> assign(:vote_results, vote_results_by_poll(polls))}
  end

  def handle_info({:poll_created, poll}, socket) do
    socket = subscribe_to_poll(socket, poll.id)
    polls = open_polls(socket.assigns.event.id)

    {:noreply,
     socket
     |> assign(:polls, polls)
     |> assign(:vote_results, vote_results_by_poll(polls))}
  end

  def handle_info({:social_feeling, result}, socket) do
    {:noreply, assign(socket, :social_feeling, result)}
  end

  def handle_info({:event_room_closed, event_id}, socket) do
    if socket.assigns.event.id == event_id do
      {:noreply, put_flash(socket, :info, "El chat de este evento se ha cerrado.")}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:status_changed, updated_event}, socket) do
    old_poll_ids = Enum.map(socket.assigns.polls, & &1.id)
    event_id = updated_event.id
    polls = open_polls(event_id)
    vote_results = vote_results_by_poll(polls)

    socket =
      socket
      |> assign(:event, updated_event)
      |> assign(:polls, polls)
      |> assign(:social_feeling, SocialFeeling.get_for_event(event_id))
      |> assign(:vote_results, vote_results)
      |> assign(:final_poll_rows, final_poll_rows(updated_event))

    socket =
      if connected?(socket) do
        new_poll_ids = Enum.map(polls, & &1.id)

        for old_poll_id <- old_poll_ids -- new_poll_ids do
          Phoenix.PubSub.unsubscribe(EventPulse.PubSub, "poll:#{old_poll_id}")
        end

        for new_poll_id <- new_poll_ids -- old_poll_ids do
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

  defp open_polls(event_id) do
    event_id
    |> Votes.list_polls()
    |> Enum.filter(&(&1.status == "open"))
    |> Enum.sort_by(& &1.inserted_at, DateTime)
  end

  defp final_poll_rows(%{status: "finalizado", id: event_id}) do
    Votes.list_polls_with_db_results(event_id)
  end

  defp final_poll_rows(_event), do: []

  defp vote_results_by_poll(polls) do
    polls
    |> Enum.map(fn poll -> {poll.id, VoteAggregator.get_results(poll.id)} end)
    |> Map.new()
  end

  defp subscribe_to_poll(socket, poll_id) do
    already_subscribed? = Enum.any?(socket.assigns.polls, &(&1.id == poll_id))

    if connected?(socket) and not already_subscribed? do
      Phoenix.PubSub.subscribe(EventPulse.PubSub, "poll:#{poll_id}")
    end

    socket
  end

  defp new_poll_form do
    %{question: "", option_count: 2, options: ["", ""]}
  end

  defp poll_form_from_params(params, current) do
    option_count =
      params
      |> Map.get("option_count", current.option_count)
      |> parse_option_count()

    options =
      params
      |> Map.get("options", %{})
      |> options_from_params(current.options)
      |> resize_options(option_count)

    %{
      question: Map.get(params, "question", current.question),
      option_count: option_count,
      options: options
    }
  end

  defp required_poll_attrs(%{question: question, options: options}) do
    question = String.trim(question)
    options = options |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

    if question != "" and length(options) >= 2 do
      {:ok, %{question: question, options: options}}
    else
      {:error, :invalid_poll}
    end
  end

  defp parse_option_count(value) when is_integer(value), do: value |> max(2) |> min(4)

  defp parse_option_count(value) when is_binary(value) do
    case Integer.parse(value) do
      {count, ""} -> parse_option_count(count)
      _ -> 2
    end
  end

  defp parse_option_count(_), do: 2

  defp options_from_params(options, current) when is_map(options) do
    0..3
    |> Enum.map(fn index ->
      Map.get(options, Integer.to_string(index), Enum.at(current, index, ""))
    end)
  end

  defp options_from_params(_options, current), do: current

  defp resize_options(options, count) do
    options
    |> Enum.concat(List.duplicate("", count))
    |> Enum.take(count)
  end

  defp normalize_demo_user_id(id) when is_integer(id) and id > 0, do: id

  defp normalize_demo_user_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} when n > 0 -> n
      _ -> 1
    end
  end

  defp normalize_demo_user_id(_), do: :rand.uniform(999_999)

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

  defp admin?(nil), do: false
  defp admin?(%{role: "admin"}), do: true
  defp admin?(_), do: false
end
