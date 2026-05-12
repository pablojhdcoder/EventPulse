defmodule EventPulse.Votes.VoteAggregatorTest do
  use EventPulse.DataCase

  alias EventPulse.Repo
  alias EventPulse.Votes.Poll
  alias EventPulse.Votes.VoteAggregator

  setup do
    aggregator = :global.whereis_name(EventPulse.Votes.VoteAggregator)
    assert is_pid(aggregator)
    Ecto.Adapters.SQL.Sandbox.allow(EventPulse.Repo, self(), aggregator)
    %{aggregator: aggregator}
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
    test "deduplicación: un usuario solo computa un voto aunque vote varias veces", %{
      aggregator: aggregator
    } do
      poll = create_test_poll()
      user_id = 42

      VoteAggregator.cast_vote(poll.id, user_id, "Opción A")
      VoteAggregator.cast_vote(poll.id, user_id, "Opción B")
      VoteAggregator.cast_vote(poll.id, user_id, "Opción C")
      _ = :sys.get_state(aggregator)

      results = VoteAggregator.get_results(poll.id)
      assert results == %{"Opción C" => 1}
    end

    test "concurrencia: soporta múltiples votos de distintos usuarios a la vez", %{
      aggregator: aggregator
    } do
      poll = create_test_poll()

      1..100
      |> Enum.map(fn i ->
        Task.async(fn -> VoteAggregator.cast_vote(poll.id, i, "Opción A") end)
      end)
      |> Task.await_many()

      _ = :sys.get_state(aggregator)

      results = VoteAggregator.get_results(poll.id)
      assert results["Opción A"] == 100
    end
  end
end
