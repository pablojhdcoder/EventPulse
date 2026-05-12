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
           mode: mode,
           poll_form: new_poll_form()
         )}
    end
  end

  @impl true
  def handle_event("validate", %{"event" => params} = all_params, socket) do
    changeset = Events.change_event(socket.assigns.event, params)

    {:noreply,
     assign(socket,
       form: to_form(changeset, action: :validate),
       poll_form:
         poll_form_from_params(Map.get(all_params, "poll", %{}), socket.assigns.poll_form)
     )}
  end

  @impl true
  def handle_event("save", %{"event" => params} = all_params, socket) do
    poll_form = poll_form_from_params(Map.get(all_params, "poll", %{}), socket.assigns.poll_form)

    case save_event(socket.assigns.event, params, poll_form) do
      {:ok, event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Evento guardado correctamente")
         |> redirect(to: ~p"/events/#{event.id}")}

      {:error, :invalid_poll} ->
        {:noreply,
         socket
         |> assign(:poll_form, poll_form)
         |> put_flash(:error, "La votación debe tener pregunta y al menos dos opciones.")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset), poll_form: poll_form)}
    end
  end

  defp save_event(%Event{id: nil}, params, poll_form) do
    with {:ok, poll_attrs} <- optional_poll_attrs(poll_form),
         {:ok, event} <- Events.create_event(params),
         :ok <- maybe_create_poll(event.id, poll_attrs) do
      {:ok, event}
    end
  end

  defp save_event(event, params, _poll_form), do: Events.update_event(event, params)

  defp maybe_create_poll(_event_id, nil), do: :ok

  defp maybe_create_poll(event_id, %{question: question, options: options}) do
    case Votes.create_poll(event_id, question, options) do
      {:ok, _poll} -> :ok
      {:error, _changeset} -> {:error, :invalid_poll}
    end
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
end
