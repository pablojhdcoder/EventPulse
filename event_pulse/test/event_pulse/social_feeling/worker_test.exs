defmodule EventPulse.SocialFeeling.WorkerTest do
  use EventPulse.DataCase

  alias EventPulse.EventRoom
  alias EventPulse.Repo
  alias EventPulse.SocialFeeling.Result
  alias EventPulse.SocialFeeling.Worker
  alias EventPulse.Votes.Poll
  alias EventPulse.Votes.Vote

  describe "process_event_sync/1" do
    test "sin votaciones numericas -> score y label nil (sin indicador)" do
      event_id = 888
      assert {:ok, %Result{} = r} = Worker.process_event_sync(event_id)
      assert r.event_id == event_id
      assert is_nil(r.score)
      assert is_nil(r.label)
      assert r.numeric_vote_count == 0
    end

    test "votacion numerica con votos -> persiste Social Feeling en [0,1]" do
      {:ok, event} =
        Repo.insert(%EventPulse.Events.Event{
          title: "Worker scale event",
          description: "test",
          category: "test",
          status: "finalizado",
          starts_at: ~U[2026-01-01 10:00:00Z],
          ends_at: ~U[2026-01-01 12:00:00Z]
        })

      {:ok, poll} =
        %Poll{}
        |> Poll.changeset(%{
          event_id: event.id,
          question: "¿Valoración?",
          options: ["1", "2", "3"],
          contributes_to_feeling: true,
          status: "open"
        })
        |> Repo.insert()

      for {uid, choice} <- [{1, "3"}, {2, "3"}, {3, "1"}, {4, "2"}, {5, "2"}, {6, "2"}] do
        %Vote{}
        |> Vote.changeset(%{poll_id: poll.id, user_id: uid, choice: choice})
        |> Repo.insert!()
      end

      assert {:ok, %Result{} = r} = Worker.process_event_sync(event.id)
      assert r.event_id == event.id
      assert r.numeric_vote_count == 6
      assert is_binary(r.label)
      assert is_float(r.score)
      assert r.score >= 0.0 and r.score <= 1.0
    end

    test "rechaza votaciones con opciones de texto" do
      {:ok, event} =
        Repo.insert(%EventPulse.Events.Event{
          title: "Worker text poll event",
          description: "test",
          category: "test",
          status: "finalizado",
          starts_at: ~U[2026-01-02 10:00:00Z],
          ends_at: ~U[2026-01-02 12:00:00Z]
        })

      changeset =
        Poll.changeset(%Poll{}, %{
          event_id: event.id,
          question: "¿Equipo?",
          options: ["A", "B"]
        })

      refute changeset.valid?
      assert %{options: [_]} = errors_on(changeset)
    end

    test "varias votaciones numericas -> media simple entre votaciones" do
      {:ok, event} =
        Repo.insert(%EventPulse.Events.Event{
          title: "Worker multi numeric event",
          description: "test",
          category: "test",
          status: "finalizado",
          starts_at: ~U[2026-01-03 10:00:00Z],
          ends_at: ~U[2026-01-03 12:00:00Z]
        })

      {:ok, low} =
        %Poll{}
        |> Poll.changeset(%{
          event_id: event.id,
          question: "Nota baja",
          options: ["1", "5"],
          status: "open"
        })
        |> Repo.insert()

      {:ok, scale} =
        %Poll{}
        |> Poll.changeset(%{
          event_id: event.id,
          question: "Nota",
          options: ["1", "5"],
          status: "open"
        })
        |> Repo.insert()

      %Vote{}
      |> Vote.changeset(%{poll_id: low.id, user_id: 1, choice: "1"})
      |> Repo.insert!()

      %Vote{}
      |> Vote.changeset(%{poll_id: scale.id, user_id: 10, choice: "5"})
      |> Repo.insert!()

      %Vote{}
      |> Vote.changeset(%{poll_id: scale.id, user_id: 11, choice: "5"})
      |> Repo.insert!()

      assert {:ok, %Result{} = r} = Worker.process_event_sync(event.id)
      assert r.score == 0.5
      assert r.numeric_vote_count == 3
    end

    test "votacion numerica sin votos -> sin indicador" do
      {:ok, event} =
        Repo.insert(%EventPulse.Events.Event{
          title: "Worker empty scale",
          description: "test",
          category: "test",
          status: "finalizado",
          starts_at: ~U[2026-01-04 10:00:00Z],
          ends_at: ~U[2026-01-04 12:00:00Z]
        })

      {:ok, _poll} =
        %Poll{}
        |> Poll.changeset(%{
          event_id: event.id,
          question: "Vacía",
          options: ["1", "2", "3"],
          contributes_to_feeling: true,
          status: "open"
        })
        |> Repo.insert()

      assert {:ok, %Result{} = r} = Worker.process_event_sync(event.id)
      assert is_nil(r.score)
      assert is_nil(r.label)
    end

    test "idempotencia: llamar dos veces reemplaza el resultado sin duplicar" do
      event_id = 777

      assert {:ok, %Result{} = first} = Worker.process_event_sync(event_id)
      assert {:ok, %Result{} = second} = Worker.process_event_sync(event_id)

      assert first.event_id == second.event_id
      assert Repo.aggregate(Result, :count, :event_id) == 1
    end

    test "termina el EventRoom asociado al cerrar el evento" do
      event_id = 776
      Phoenix.PubSub.subscribe(EventPulse.PubSub, "event:#{event_id}")

      assert {:ok, pid} =
               DynamicSupervisor.start_child(EventPulse.EventSupervisor, {EventRoom, event_id})

      assert Process.alive?(pid)

      assert {:ok, %Result{}} = Worker.process_event_sync(event_id)
      assert_receive {:event_room_closed, ^event_id}

      assert eventually(fn ->
               not Process.alive?(pid) &&
                 Registry.lookup(EventPulse.EventRegistry, event_id) == []
             end)
    end
  end

  defp eventually(fun, attempts \\ 10)

  defp eventually(fun, attempts) when attempts > 0 do
    if fun.() do
      true
    else
      Process.sleep(20)
      eventually(fun, attempts - 1)
    end
  end

  defp eventually(_fun, 0), do: false
end
