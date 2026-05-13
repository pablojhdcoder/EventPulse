defmodule EventPulse.Events do
  @moduledoc """
  The Events context.

  Tras cerrar un evento (`close_event/1`), los efectos secundarios (vaciar buffer Redis
  de chat y disparar el cálculo de Social Feeling) se ejecutan **fuera** de la
  transacción y de forma **best-effort**: un fallo en Redis o en el worker se
  registra en logs y no revierte el cierre en base de datos.
  """

  import Ecto.Query, warn: false
  require Logger
  alias EventPulse.Repo
  alias EventPulse.Events.Event
  alias EventPulse.ChatBuffer
  alias EventPulse.SocialFeeling.Worker, as: SocialFeelingWorker
  alias EventPulse.Votes.Poll

  # Transiciones permitidas vía `update_event_status/2` (alineado con la UI LiveView).
  # `close_event/1` sigue pudiendo finalizar desde otros estados si se invoca directamente.
  @status_transitions %{
    "programado" => ["en_directo"],
    "en_directo" => ["finalizado"],
    "finalizado" => []
  }

  def list_events do
    list_events_filtered(nil, nil)
  end

  def list_events_by_category(category) do
    list_events_filtered(category, nil)
  end

  @doc """
  Lista eventos con filtros opcionales por categoría y/o estado.
  Ordenados por `starts_at` ascendente.
  """
  def list_events_filtered(category \\ nil, status \\ nil) do
    Event
    |> maybe_filter_category(category)
    |> maybe_filter_status(status)
    |> order_by([e], asc: e.starts_at)
    |> Repo.all()
  end

  defp maybe_filter_category(query, nil), do: query

  defp maybe_filter_category(query, category) do
    where(query, [e], e.category == ^category)
  end

  defp maybe_filter_status(query, nil), do: query

  defp maybe_filter_status(query, status) do
    where(query, [e], e.status == ^status)
  end

  def get_event(id) when is_integer(id) do
    case Repo.get(Event, id) do
      nil -> :error
      %Event{} = event -> {:ok, event}
    end
  end

  def get_event!(id), do: Repo.get!(Event, id)

  def create_event(attrs \\ %{}) do
    case %Event{}
         |> Event.changeset(attrs)
         |> Repo.insert() do
      {:ok, _} = ok ->
        broadcast_events_catalog_changed()
        ok

      err ->
        err
    end
  end

  def update_event(%Event{} = event, attrs) do
    case event
         |> Event.changeset(attrs)
         |> Repo.update() do
      {:ok, _} = ok ->
        broadcast_events_catalog_changed()
        ok

      err ->
        err
    end
  end

  def delete_event(%Event{} = event) do
    case Repo.delete(event) do
      {:ok, _} = ok ->
        broadcast_events_catalog_changed()
        ok

      err ->
        err
    end
  end

  def close_event(%Event{} = event) do
    Repo.transaction(fn ->
      current = Repo.get!(Event, event.id, lock: "FOR UPDATE")

      if current.status == "finalizado" do
        {current, false}
      else
        {:ok, updated} =
          current
          |> Event.changeset(%{status: "finalizado"})
          |> Repo.update()

        close_event_polls(updated.id)
        {updated, true}
      end
    end)
    |> case do
      {:ok, {updated, just_closed?}} ->
        broadcast_status_changed(updated)

        if just_closed? do
          run_close_side_effects(updated)
        end

        {:ok, updated}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def update_event_status(%Event{} = event, new_status) do
    allowed = Map.get(@status_transitions, event.status, [])

    if new_status in allowed do
      case new_status do
        "finalizado" ->
          close_event(event)

        _ ->
          event
          |> Event.changeset(%{status: new_status})
          |> Repo.update()
          |> case do
            {:ok, updated} ->
              broadcast_status_changed(updated)
              {:ok, updated}

            error ->
              error
          end
      end
    else
      {:error, :invalid_transition}
    end
  end

  def change_event(%Event{} = event, attrs \\ %{}) do
    Event.changeset(event, attrs)
  end

  defp close_event_polls(event_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(p in Poll, where: p.event_id == ^event_id and p.status != "closed")
    |> Repo.update_all(set: [status: "closed", updated_at: now])
  end

  defp broadcast_events_catalog_changed do
    EventPulse.broadcast("events:updates", :events_catalog_changed)
  end

  defp run_close_side_effects(%Event{id: id}) do
    room = Integer.to_string(id)

    case ChatBuffer.delete_buffer(room) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("events: delete_buffer failed event_id=#{id} reason=#{inspect(reason)}")
    end

    try do
      SocialFeelingWorker.process_event(id)
    rescue
      exception ->
        Logger.error(
          "events: social_feeling process_event failed event_id=#{id} error=#{inspect(exception)}"
        )
    end

    :ok
  end

  defp broadcast_status_changed(%Event{} = event) do
    EventPulse.broadcast("events:#{event.id}", {:status_changed, event})
    EventPulse.broadcast("events:updates", {:status_changed, event})
  end
end
