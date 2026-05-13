defmodule EventPulse.Votes.VoteAggregatorTest do
  use EventPulse.DataCase

  alias EventPulse.Repo
  alias EventPulse.Votes
  alias EventPulse.Votes.Poll
  alias EventPulse.Votes.VoteAggregator

  setup do
    aggregator = :global.whereis_name(EventPulse.Votes.VoteAggregator)
    assert is_pid(aggregator)
    Ecto.Adapters.SQL.Sandbox.allow(EventPulse.Repo, self(), aggregator)
    %{aggregator: aggregator}
  end

  defp create_test_poll(options \\ ["1", "2", "3"]) do
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
        options: options,
        status: "open"
      })

    poll
  end

  # ---------------------------------------------------------------------------
  # Poll.changeset — validaciones de opciones
  # ---------------------------------------------------------------------------

  describe "Poll.changeset — opciones de texto" do
    test "acepta opciones con palabras" do
      changeset =
        Poll.changeset(%Poll{}, %{
          event_id: 1,
          question: "¿Tecnología favorita?",
          options: ["Phoenix", "LiveView", "Docker"]
        })

      assert changeset.valid?
    end

    test "acepta opciones numéricas (compatibilidad legada)" do
      changeset =
        Poll.changeset(%Poll{}, %{
          event_id: 1,
          question: "Valora del 1 al 3",
          options: ["1", "2", "3"]
        })

      assert changeset.valid?
    end

    test "Ecto elimina strings vacíos del array — si quedan menos de 2 opciones falla min:2" do
      # Ecto cast de {:array, :string} descarta strings vacíos y whitespace-only.
      # ["Phoenix", ""] → ["Phoenix"] → falla validate_length min:2
      changeset =
        Poll.changeset(%Poll{}, %{
          event_id: 1,
          question: "Pregunta",
          options: ["Phoenix", ""]
        })

      refute changeset.valid?
      assert %{options: [_]} = errors_on(changeset)
    end

    test "rechaza opciones duplicadas" do
      changeset =
        Poll.changeset(%Poll{}, %{
          event_id: 1,
          question: "Pregunta",
          options: ["Phoenix", "Phoenix"]
        })

      refute changeset.valid?
      assert %{options: [_]} = errors_on(changeset)
    end

    test "rechaza opción que supera 50 caracteres" do
      long_opt = String.duplicate("a", 51)

      changeset =
        Poll.changeset(%Poll{}, %{
          event_id: 1,
          question: "Pregunta",
          options: [long_opt, "Otra"]
        })

      refute changeset.valid?
      assert %{options: [_]} = errors_on(changeset)
    end

    test "rechaza menos de 2 opciones" do
      changeset =
        Poll.changeset(%Poll{}, %{
          event_id: 1,
          question: "Pregunta",
          options: ["Solo una"]
        })

      refute changeset.valid?
    end

    test "rechaza más de 4 opciones" do
      changeset =
        Poll.changeset(%Poll{}, %{
          event_id: 1,
          question: "Pregunta",
          options: ["a", "b", "c", "d", "e"]
        })

      refute changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # VoteAggregator — comportamiento con opciones de texto y numéricas
  # ---------------------------------------------------------------------------

  describe "VoteAggregator — opciones numéricas (legado)" do
    test "deduplicación: un usuario solo computa un voto aunque vote varias veces", %{
      aggregator: aggregator
    } do
      poll = create_test_poll()
      user_id = 42

      VoteAggregator.cast_vote(poll.id, user_id, "1")
      VoteAggregator.cast_vote(poll.id, user_id, "2")
      VoteAggregator.cast_vote(poll.id, user_id, "3")
      _ = :sys.get_state(aggregator)

      results = VoteAggregator.get_results(poll.id)
      assert results == %{"3" => 1}
    end

    test "concurrencia: soporta múltiples votos de distintos usuarios a la vez", %{
      aggregator: aggregator
    } do
      poll = create_test_poll()

      1..100
      |> Enum.map(fn i ->
        Task.async(fn -> VoteAggregator.cast_vote(poll.id, i, "1") end)
      end)
      |> Task.await_many()

      _ = :sys.get_state(aggregator)

      results = VoteAggregator.get_results(poll.id)
      assert results["1"] == 100
    end
  end

  describe "VoteAggregator — opciones de texto" do
    test "agrega votos correctamente con opciones en palabras", %{aggregator: aggregator} do
      poll = create_test_poll(["Phoenix", "LiveView", "Docker"])

      VoteAggregator.cast_vote(poll.id, 1, "Phoenix")
      VoteAggregator.cast_vote(poll.id, 2, "Phoenix")
      VoteAggregator.cast_vote(poll.id, 3, "LiveView")
      _ = :sys.get_state(aggregator)

      results = VoteAggregator.get_results(poll.id)
      assert results == %{"Phoenix" => 2, "LiveView" => 1}
    end

    test "deduplicación funciona con opciones texto", %{aggregator: aggregator} do
      poll = create_test_poll(["Sí", "No"])

      VoteAggregator.cast_vote(poll.id, 99, "Sí")
      VoteAggregator.cast_vote(poll.id, 99, "No")
      _ = :sys.get_state(aggregator)

      results = VoteAggregator.get_results(poll.id)
      assert results == %{"No" => 1}
    end

    test "cast_vote via Votes.cast_vote acepta opciones texto", %{aggregator: aggregator} do
      {:ok, event} =
        Repo.insert(%EventPulse.Events.Event{
          title: "Evento texto",
          category: "test",
          status: "en_directo",
          starts_at: ~U[2026-01-01 10:00:00Z]
        })

      {:ok, poll} = Votes.create_poll(event.id, "¿Favorito?", ["Phoenix", "LiveView", "Docker"])

      assert :ok = Votes.cast_vote(poll.id, 10, "Phoenix")
      assert :ok = Votes.cast_vote(poll.id, 11, "Docker")
      assert {:error, :invalid_choice} = Votes.cast_vote(poll.id, 12, "Rails")

      _ = :sys.get_state(aggregator)

      results = VoteAggregator.get_results(poll.id)
      assert results["Phoenix"] == 1
      assert results["Docker"] == 1
    end
  end
end
