defmodule EventPulse.Votes.VoteAggregatorTest do
  # Importa herramientas para pruebas que interactúan con la base de datos
  use EventPulse.DataCase
  alias EventPulse.Votes.VoteAggregator
  alias EventPulse.Votes.Poll
  alias EventPulse.Repo

  # Función auxiliar para crear una poll de prueba
  defp create_test_poll do
    # Crea un evento padre para asociar la encuesta (poll)
    {:ok, event} =
      Repo.insert(%EventPulse.Events.Event{
        title: "Evento test",
        description: "Descripción test",
        category: "test",
        status: "en_directo",
        starts_at: ~U[2026-01-01 10:00:00Z],
        ends_at: ~U[2026-01-01 12:00:00Z]
      })

    # Crea una encuesta (poll) asociada a ese evento con varias opciones
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

      # Simulamos que el mismo usuario vota varias veces con diferentes opciones
      VoteAggregator.cast_vote(poll.id, user_id, "Opción A")
      VoteAggregator.cast_vote(poll.id, user_id, "Opción B")
      VoteAggregator.cast_vote(poll.id, user_id, "Opción C")

      # Pausa para que el GenServer procese los mensajes y realice el flush
      Process.sleep(100)

      # Validamos que el estado final en memoria sea el correcto (solo el último voto)
      results = VoteAggregator.get_results(poll.id)
      assert results == %{"Opción C" => 1}
    end

    test "concurrencia: soporta múltiples votos de distintos usuarios a la vez" do
      poll = create_test_poll()

      # 100 votos concurrentes de distintos usuarios
      1..100
      |> Enum.map(fn i ->
        Task.async(fn -> VoteAggregator.cast_vote(poll.id, i, "Opción A") end)
      end)
      # Esperamos a que todas las tareas terminen
      |> Task.await_many()

      # Esperamos un poco más que el intervalo de flush para asegurarnos de que se hayan persistido
      Process.sleep(600)

      results = VoteAggregator.get_results(poll.id)
      # Validamos que el conteo de votos sea correcto
      assert results["Opción A"] == 100
    end
  end
end
