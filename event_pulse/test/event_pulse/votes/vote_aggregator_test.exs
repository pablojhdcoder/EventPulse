defmodule EventPulse.Votes.VoteAggregatorTest do
  use EventPulse.DataCase
  alias EventPulse.Votes.VoteAggregator
  alias EventPulse.Votes.Vote
  alias EventPulse.Repo

  setup do
    # Iniciar procesos necesarios para los tests
    start_supervised({Task.Supervisor, name: EventPulse.TaskSupervisor})
    start_supervised({Phoenix.PubSub, name: EventPulse.PubSub})
    start_supervised({EventPulse.Votes.VoteAggregator, name: {:global, EventPulse.Votes.VoteAggregator}})
    :ok
  end

  describe "VoteAggregator" do
    test "deduplicación: un usuario solo computa un voto aunque vote varias veces" do
      event_id = 1
      user_id = 42

      # Simulamos 5 votos del mismo usuario para distintas opciones
      VoteAggregator.cast_vote(event_id, user_id, "Opción A")
      VoteAggregator.cast_vote(event_id, user_id, "Opción B")
      VoteAggregator.cast_vote(event_id, user_id, "Opción C")

      # Damos un margen mínimo para que la persistencia asíncrona actúe
      Process.sleep(500)

      # 1. Verificar memoria (GenServer)
      results = VoteAggregator.get_results(event_id)
      assert results == %{"Opción C" => 1} # Solo debe quedar el último

      # 2. Verificar base de datos (Persistencia asíncrona)
      votos_en_db = Repo.all(Vote)
      assert length(votos_en_db) == 1
      assert hd(votos_en_db).choice == "Opción C"
    end

    test "concurrencia: soporta múltiples votos de distintos usuarios a la vez" do
      event_id = 2

      # Lanzamos 100 votos de forma concurrente
      1..100
      |> Enum.map(fn i ->
        Task.async(fn -> VoteAggregator.cast_vote(event_id, i, "SÍ") end)
      end)
      |> Task.await_many()

      Process.sleep(2000)

      results = VoteAggregator.get_results(event_id)
      assert results["SÍ"] == 100
    end
  end
end
