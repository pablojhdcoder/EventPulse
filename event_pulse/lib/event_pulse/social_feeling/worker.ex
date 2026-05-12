defmodule EventPulse.SocialFeeling.Worker do
  @moduledoc """
  `GenServer` que procesa el cierre de un evento:

    1. Obtiene los votos (prioriza la memoria del `VoteAggregator`,
       con *fallback* a la base de datos).
    2. Calcula el Social Feeling (`Calculator`).
    3. Persiste el resultado en `social_feeling_results` (idempotente:
       *upsert* por `event_id`).
    4. Difunde por `Phoenix.PubSub` en el tópico `"event:<id>"`.
    5. Difunde `{:event_room_closed, event_id}` en `event:<id>` (misma convención
       que el chat en `Chat.EventRoom`) para que las LiveViews cierren la sala
       aunque no exista proceso `EventPulse.EventRoom` en el registry.
    6. Si hay proceso `EventPulse.EventRoom` registrado, lo termina vía
       `EventPulse.EventRegistry` + `EventPulse.EventSupervisor`.

  Expone dos formas de disparo:

    * `process_event/1` — asíncrono (cast) para producción.
    * `process_event_sync/1` — síncrono (call) usado por los tests.
  """

  use GenServer
  require Logger
  import Ecto.Query

  alias EventPulse.EventRoom
  alias EventPulse.Repo
  alias EventPulse.SocialFeeling.Calculator
  alias EventPulse.SocialFeeling.Result
  alias EventPulse.Votes.Poll
  alias EventPulse.Votes.Vote
  alias EventPulse.Votes.VoteAggregator

  @registry_name EventPulse.EventRegistry
  @supervisor_name EventPulse.EventSupervisor
  @max_retries 3
  @retry_base_ms 100

  # --- API pública ---

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  @doc "Dispara el procesamiento del cierre de forma asíncrona."
  def process_event(event_id, server \\ __MODULE__) do
    GenServer.cast(server, {:process_event, event_id, 0})
  end

  @doc """
  Variante síncrona: devuelve `{:ok, %Result{}}` o `{:error, _}`.
  Pensada para tests y para flujos que necesiten el resultado.
  """
  def process_event_sync(event_id, server \\ __MODULE__) do
    GenServer.call(server, {:process_event, event_id})
  end

  # --- Callbacks ---

  @impl true
  def init(:ok), do: {:ok, %{}}

  @impl true
  def handle_cast({:process_event, event_id, attempt}, state) do
    _ = process_async(event_id, attempt)
    {:noreply, state}
  end

  @impl true
  def handle_info({:retry_process_event, event_id, attempt}, state) do
    _ = process_async(event_id, attempt)
    {:noreply, state}
  end

  @impl true
  def handle_call({:process_event, event_id}, _from, state) do
    {:reply, do_process(event_id), state}
  end

  # --- Lógica interna ---

  defp process_async(event_id, attempt) do
    case safe_process(event_id) do
      {:ok, _result} = ok ->
        ok

      {:error, reason} = err ->
        maybe_retry(event_id, attempt, reason)
        err
    end
  end

  defp safe_process(event_id) do
    do_process(event_id)
  rescue
    exception ->
      {:error, exception}
  catch
    kind, reason ->
      {:error, {kind, reason}}
  end

  defp maybe_retry(event_id, attempt, reason) when attempt < @max_retries do
    delay = @retry_base_ms * (attempt + 1)

    Logger.warning(
      "social_feeling.worker: reintentando event_id=#{event_id} " <>
        "attempt=#{attempt + 1}/#{@max_retries} reason=#{inspect(reason)}"
    )

    Process.send_after(self(), {:retry_process_event, event_id, attempt + 1}, delay)
  end

  defp maybe_retry(event_id, _attempt, reason) do
    Logger.error(
      "social_feeling.worker: agotados los reintentos event_id=#{event_id} " <>
        "reason=#{inspect(reason)}"
    )
  end

  defp do_process(event_id) do
    vote_counts = gather_votes(event_id)
    feeling = Calculator.calculate(vote_counts)

    case persist_result(event_id, feeling) do
      {:ok, result} ->
        broadcast(event_id, result)
        cleanup_event_room(event_id)
        {:ok, result}

      {:error, reason} = err ->
        Logger.error(
          "social_feeling.worker: no se pudo persistir event_id=#{event_id} " <>
            "(#{inspect(reason)})"
        )

        err
    end
  end

  defp gather_votes(event_id) do
    mem = mem_vote_counts_for_event(event_id)

    if map_size(mem) > 0 do
      mem
    else
      votes_from_db(event_id)
    end
  end

  defp mem_vote_counts_for_event(event_id) do
    poll_ids =
      from(p in Poll, where: p.event_id == ^event_id, select: p.id)
      |> Repo.all()

    Enum.reduce(poll_ids, %{}, fn poll_id, acc ->
      try do
        VoteAggregator.get_results(poll_id)
        |> merge_vote_count_maps(acc)
      catch
        :exit, _ -> acc
      end
    end)
  end

  defp merge_vote_count_maps(%{} = results, acc) do
    Map.merge(acc, results, fn _choice, c1, c2 -> c1 + c2 end)
  end

  defp votes_from_db(event_id) do
    from(v in Vote,
      join: p in Poll,
      on: v.poll_id == p.id,
      where: p.event_id == ^event_id,
      group_by: v.choice,
      select: {v.choice, count(v.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  defp persist_result(event_id, feeling) do
    attrs = %{
      event_id: event_id,
      score: feeling.score,
      label: Atom.to_string(feeling.label),
      total_votes: feeling.total_votes,
      breakdown: stringify_breakdown(feeling.breakdown),
      computed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    %Result{}
    |> Result.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: [:event_id]
    )
  end

  defp stringify_breakdown(breakdown) do
    Map.new(breakdown, fn {k, v} -> {to_string(k), v} end)
  end

  defp broadcast(event_id, %Result{} = result) do
    Phoenix.PubSub.broadcast(
      EventPulse.PubSub,
      "event:#{event_id}",
      {:social_feeling, result}
    )
  end

  # La limpieza del `EventRoom` depende de la infraestructura OTP
  # (Persona 6: Registry + DynamicSupervisor). Si aún no está arrancada,
  # no hacemos nada y devolvemos :ok.
  defp cleanup_event_room(event_id) do
    _ =
      with true <- registry_alive?(),
           [{pid, _meta}] <- safe_lookup(event_id),
           true <- supervisor_alive?() do
        close_event_room(pid)
      else
        _ -> :ok
      end

    Phoenix.PubSub.broadcast(
      EventPulse.PubSub,
      "event:#{event_id}",
      {:event_room_closed, event_id}
    )
  end

  defp close_event_room(pid) do
    EventRoom.close(pid)
  catch
    :exit, _ -> DynamicSupervisor.terminate_child(@supervisor_name, pid)
  end

  defp registry_alive?, do: not is_nil(Process.whereis(@registry_name))
  defp supervisor_alive?, do: not is_nil(Process.whereis(@supervisor_name))

  defp safe_lookup(event_id) do
    Registry.lookup(@registry_name, event_id)
  rescue
    _ -> []
  end
end
