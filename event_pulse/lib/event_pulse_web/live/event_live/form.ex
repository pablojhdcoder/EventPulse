defmodule EventPulseWeb.EventLive.Form do
  use EventPulseWeb, :live_view

  alias EventPulse.Accounts.Auth
  alias EventPulse.Events
  alias EventPulse.Events.Event
  alias EventPulse.Votes

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
        case mount_form_state(params) do
          {:assign, event, mode} ->
            changeset = Events.change_event(event)

            editable_poll_forms =
              if mode == :edit && event.status == "programado" &&
                   match?(%Event{id: id} when is_integer(id), event) do
                event.id
                |> Votes.list_polls()
                |> Enum.sort_by(& &1.inserted_at, DateTime)
                |> polls_to_editable_forms()
              else
                []
              end

            category_options = category_options_for(event)

            {:ok,
             assign(socket,
               event: event,
               form: to_form(changeset),
               mode: mode,
               poll_form: new_poll_form(),
               editable_poll_forms: editable_poll_forms,
               category_options: category_options
             )}

          {:redirect, path, msg} ->
            {:ok,
             push_navigate(socket, to: path)
             |> put_flash(:error, msg)}
        end
    end
  end

  @impl true
  def handle_event("validate", %{"event" => params} = all_params, socket) do
    changeset = Events.change_event(socket.assigns.event, params)
    poll_form = poll_form_from_params(Map.get(all_params, "poll", %{}), socket.assigns.poll_form)

    editable_poll_forms =
      parse_editable_polls_from_params(
        Map.get(all_params, "poll_existing", %{}),
        socket.assigns.editable_poll_forms
      )

    {:noreply,
     assign(socket,
       form: to_form(changeset, action: :validate),
       poll_form: poll_form,
       editable_poll_forms: editable_poll_forms
     )}
  end

  @impl true
  def handle_event("save", %{"event" => params} = all_params, socket) do
    poll_form = poll_form_from_params(Map.get(all_params, "poll", %{}), socket.assigns.poll_form)

    editable_poll_forms =
      parse_editable_polls_from_params(
        Map.get(all_params, "poll_existing", %{}),
        socket.assigns.editable_poll_forms
      )

    case save_event(socket.assigns.event, params, poll_form, editable_poll_forms) do
      {:ok, event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Evento guardado correctamente")
         |> redirect(to: ~p"/events/#{event.id}")}

      {:error, :invalid_poll} ->
        {:noreply,
         socket
         |> assign(:poll_form, poll_form)
         |> assign(:editable_poll_forms, editable_poll_forms)
         |> put_flash(:error, "La votación debe tener pregunta y al menos dos opciones numéricas.")}

      {:error, :cannot_change_options_with_votes} ->
        {:noreply,
         socket
         |> assign(:poll_form, poll_form)
         |> assign(:editable_poll_forms, editable_poll_forms)
         |> put_flash(
           :error,
           "No puedes cambiar las opciones de una votación que ya tiene votos registrados."
         )}

      {:error, changeset} ->
        {:noreply,
         assign(socket,
           form: to_form(changeset),
           poll_form: poll_form,
           editable_poll_forms: editable_poll_forms
         )}
    end
  end

  defp save_event(%Event{id: nil}, params, poll_form, _editable) do
    with {:ok, event} <- Events.create_event(params),
         :ok <- maybe_create_optional_new_poll(event.id, poll_form) do
      {:ok, event}
    end
  end

  defp save_event(%Event{status: "programado", id: id} = event, params, poll_form, editable_poll_forms)
       when is_integer(id) do
    with :ok <- persist_editable_poll_updates(id, editable_poll_forms),
         {:ok, updated} <- Events.update_event(event, params),
         :ok <- maybe_create_optional_new_poll(updated.id, poll_form) do
      {:ok, updated}
    else
      {:error, :cannot_change_options_with_votes} = err -> err
      {:error, :invalid_poll} = err -> err
      {:error, %Ecto.Changeset{}} = err -> err
    end
  end

  defp save_event(event, params, _poll_form, _editable), do: Events.update_event(event, params)

  defp maybe_create_optional_new_poll(event_id, poll_form) do
    case optional_poll_attrs(poll_form) do
      {:ok, nil} -> :ok
      {:ok, attrs} -> create_poll_from_attrs(event_id, attrs)
      {:error, _} = err -> err
    end
  end

  defp create_poll_from_attrs(event_id, %{question: question, options: options}) do
    case Votes.create_poll(event_id, question, options) do
      {:ok, _poll} -> :ok
      {:error, _changeset} -> {:error, :invalid_poll}
    end
  end

  defp persist_editable_poll_updates(_event_id, []), do: :ok

  defp persist_editable_poll_updates(event_id, forms) do
    Enum.reduce_while(forms, :ok, fn %{id: id, question: q, options: opt_fields}, _ ->
      trimmed_opts =
        opt_fields
        |> Enum.map(&to_string/1)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      q = String.trim(to_string(q))

      cond do
        q == "" or length(trimmed_opts) < 2 ->
          {:halt, {:error, :invalid_poll}}

        true ->
          case Votes.get_poll(id) do
            nil ->
              {:cont, :ok}

            %{event_id: ^event_id} = poll ->
              case Votes.update_poll(poll, %{question: q, options: trimmed_opts}) do
                {:ok, _} -> {:cont, :ok}
                {:error, :cannot_change_options_with_votes} ->
                  {:halt, {:error, :cannot_change_options_with_votes}}

                {:error, %Ecto.Changeset{}} ->
                  {:halt, {:error, :invalid_poll}}
              end

            _poll ->
              {:halt, {:error, :invalid_poll}}
          end
      end
    end)
  end

  defp polls_to_editable_forms(polls) do
    Enum.map(polls, fn p ->
      n = length(p.options) |> max(2) |> min(4)
      %{id: p.id, question: p.question, option_count: n, options: pad_option_fields(p.options, n)}
    end)
  end

  defp pad_option_fields(opts, n) do
    opts = Enum.take(opts, n)
    opts ++ List.duplicate("", max(0, n - length(opts)))
  end

  defp parse_editable_polls_from_params(_params, []), do: []

  defp parse_editable_polls_from_params(params, forms) when is_map(params) do
    Enum.map(forms, fn %{id: id} = defaults ->
      key = Integer.to_string(id)
      p = Map.get(params, key, %{})

      poll_form_from_params_for_edit(p, defaults)
    end)
  end

  defp poll_form_from_params_for_edit(params, defaults) do
    option_count =
      params
      |> Map.get("option_count", defaults.option_count)
      |> parse_option_count()

    options =
      params
      |> Map.get("options", %{})
      |> options_from_params(defaults.options)
      |> resize_options(option_count)

    %{
      id: defaults.id,
      question: Map.get(params, "question", defaults.question),
      option_count: option_count,
      options: options
    }
  end

  defp optional_poll_attrs(%{question: question, options: options}) do
    question = String.trim(question)
    options = options |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

    cond do
      question == "" and options == [] ->
        {:ok, nil}

      question != "" and length(options) >= 2 ->
        {:ok, %{question: question, options: options}}

      true ->
        {:error, :invalid_poll}
    end
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

  defp admin?(socket) do
    socket.assigns[:current_user] && socket.assigns.current_user.role == "admin"
  end

  defp mount_form_state(params) do
    id_raw = params["id"] || params[:id]

    cond do
      is_nil(id_raw) ->
        {:assign, %Event{}, :new}

      true ->
        case Integer.parse(to_string(id_raw)) do
          {event_id, ""} ->
            case Events.get_event(event_id) do
              {:ok, event} -> {:assign, event, :edit}
              :error -> {:redirect, ~p"/events", "Evento no encontrado."}
            end

          _ ->
            {:redirect, ~p"/events", "ID de evento inválido."}
        end
    end
  end

  defp category_options_for(%Event{category: cat}) when is_binary(cat) and cat != "" do
    base = Event.category_select_options()
    # Siempre añadir la categoría actual y deduplicar por valor guardado en BD.
    (base ++ [{humanize_category_value(cat), cat}])
    |> Enum.uniq_by(fn {_, v} -> v end)
  end

  defp category_options_for(_), do: Event.category_select_options()

  defp humanize_category_value(cat) do
    cat
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
