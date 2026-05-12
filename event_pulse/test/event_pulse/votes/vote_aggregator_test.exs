defmodule EventPulse.Votes.VoteAggregatorTest do
  use EventPulse.DataCase
  alias EventPulse.Votes.VoteAggregator
  alias EventPulse.Votes.Poll
  alias EventPulse.Repo

  setup do
    agg = Process.whereis(EventPulse.Votes.VoteAggregator)
    assert is_pid(agg)
    Ecto.Adapters.SQL.Sandbox.allow(EventPulse.Repo, self(), agg)
    :ok
  end

  defp create_test_poll do
    {:ok, event} =
      Repo.insert(%EventPulse.Events.Event{
        title: "Evento test",
        description: "Descripción test",
        category: "test",
        status: "en_directo",
        starts_at: ~U[2026-01-01 10:00:00Z],
        ends_at: ~U[2026-01-01 12:00:00Z]
      })

    {:ok, poll} =
      Repo.insert(%Poll{
        event_id: event.id,
        question: "¿Pregunta test?",
        options: ["Opción A", "Opción B", "Opción C"],
        status: "open"
      })

    poll
  end

  describe "VoteAggregator" do
    test "deduplicación: un usuario solo computa un voto aunque vote varias veces" do
      poll = create_test_poll()
      user_id = 42

      VoteAggregator.cast_vote(poll.id, user_id, "Opción A")
      VoteAggregator.cast_vote(poll.id, user_id, "Opción B")
      VoteAggregator.cast_vote(poll.id, user_id, "Opción C")

      Process.sleep(150)

      results = VoteAggregator.get_results(poll.id)
      assert results == %{"Opción C" => 1}
    end

    test "concurrencia: soporta múltiples votos de distintos usuarios a la vez" do
      poll = create_test_poll()

      1..100
      |> Enum.map(fn i ->
        Task.async(fn -> VoteAggregator.cast_vote(poll.id, i, "Opción A") end)
      end)
      |> Task.await_many()

      Process.sleep(300)

      results = VoteAggregator.get_results(poll.id)
      assert results["Opción A"] == 100
    end
  end
end
