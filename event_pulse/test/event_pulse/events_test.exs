defmodule EventPulse.EventsTest do
  use EventPulse.DataCase

  import EventPulse.EventsFixtures

  alias EventPulse.Events
  alias EventPulse.Events.Event
  alias EventPulse.Repo
  alias EventPulse.Votes
  alias EventPulse.Votes.Poll

  describe "Event.changeset/2 — validaciones de campos" do
    test "changeset válido con datos correctos" do
      attrs = %{
        title: "Evento de prueba",
        category: "deportes",
        status: "programado",
        starts_at: ~U[2026-06-01 10:00:00Z]
      }

      changeset = Event.changeset(%Event{}, attrs)
      assert changeset.valid?
    end

    test "changeset inválido sin título" do
      attrs = %{category: "deportes", starts_at: ~U[2026-06-01 10:00:00Z]}
      changeset = Event.changeset(%Event{}, attrs)
      refute changeset.valid?
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "changeset inválido sin categoría" do
      attrs = %{title: "Evento", starts_at: ~U[2026-06-01 10:00:00Z]}
      changeset = Event.changeset(%Event{}, attrs)
      refute changeset.valid?
      assert %{category: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "estados del evento" do
    test "estado por defecto es programado" do
      changeset =
        Event.changeset(%Event{}, %{
          title: "Evento",
          category: "música",
          starts_at: ~U[2026-06-01 10:00:00Z]
        })

      assert Ecto.Changeset.get_field(changeset, :status) == "programado"
    end

    test "estado programado es válido" do
      changeset =
        Event.changeset(%Event{}, %{
          title: "Evento",
          category: "música",
          status: "programado",
          starts_at: ~U[2026-06-01 10:00:00Z]
        })

      assert changeset.valid?
    end

    test "estado en_directo es válido" do
      changeset =
        Event.changeset(%Event{}, %{
          title: "Evento",
          category: "música",
          status: "en_directo",
          starts_at: ~U[2026-06-01 10:00:00Z]
        })

      assert changeset.valid?
    end

    test "estado finalizado es válido" do
      changeset =
        Event.changeset(%Event{}, %{
          title: "Evento",
          category: "música",
          status: "finalizado",
          starts_at: ~U[2026-06-01 10:00:00Z]
        })

      assert changeset.valid?
    end

    test "estado inválido es rechazado" do
      changeset =
        Event.changeset(%Event{}, %{
          title: "Evento",
          category: "música",
          status: "inventado",
          starts_at: ~U[2026-06-01 10:00:00Z]
        })

      refute changeset.valid?

      assert %{status: ["debe ser programado, en_directo o finalizado"]} =
               errors_on(changeset)
    end

    test "valid_statuses incluye los tres estados" do
      assert Event.valid_statuses() == ["programado", "en_directo", "finalizado"]
    end
  end

  describe "Evento — consulta por id (get_event/1)" do
    test "devuelve el evento cuando existe" do
      event = event_fixture()
      assert {:ok, got} = Events.get_event(event.id)
      assert got.id == event.id
    end

    test "devuelve :error si no existe" do
      assert :error = Events.get_event(999_999_999)
    end
  end

  describe "Evento — listado filtrado (list_events_filtered/2)" do
    test "sin filtros lista todos ordenados por fecha de inicio" do
      e1 =
        event_fixture(%{
          title: "primero",
          starts_at: ~U[2026-01-01 10:00:00Z]
        })

      e2 =
        event_fixture(%{
          title: "segundo",
          starts_at: ~U[2026-02-01 10:00:00Z]
        })

      ids = Events.list_events_filtered(nil, nil) |> Enum.map(& &1.id)
      assert Enum.find_index(ids, &(&1 == e1.id)) < Enum.find_index(ids, &(&1 == e2.id))
    end

    test "filtra por estado" do
      _p = event_fixture(%{status: "programado"})
      live = event_fixture(%{status: "en_directo", title: "live"})
      got = Events.list_events_filtered(nil, "en_directo")
      assert length(got) == 1
      assert hd(got).id == live.id
    end

    test "filtra por categoría y estado a la vez" do
      _ =
        event_fixture(%{
          status: "en_directo",
          category: "deportes",
          title: "d"
        })

      m =
        event_fixture(%{
          status: "en_directo",
          category: "musica",
          title: "m"
        })

      got = Events.list_events_filtered("musica", "en_directo")
      assert length(got) == 1
      assert hd(got).id == m.id
    end
  end

  describe "Evento — cierre (close_event/1)" do
    test "marca el evento como finalizado" do
      event = event_fixture()

      assert {:ok, %Event{} = closed_event} = Events.close_event(event)
      assert closed_event.status == "finalizado"
    end

    test "cierra las votaciones del evento y bloquea votos posteriores" do
      event = event_fixture(%{status: "en_directo"})
      {:ok, poll} = Votes.create_poll(event.id, "¿Continuar?", ["1", "2"])

      assert {:ok, %Event{} = closed_event} = Events.close_event(event)
      assert closed_event.status == "finalizado"

      assert %Poll{status: "closed"} = Repo.get!(Poll, poll.id)
      assert {:error, :poll_closed} = Votes.cast_vote(poll.id, 123, "1")
    end

    test "update_event_status a finalizado usa el cierre estricto" do
      event = event_fixture(%{status: "en_directo"})
      {:ok, poll} = Votes.create_poll(event.id, "¿Cerrar?", ["1", "2"])

      assert {:ok, %Event{} = closed_event} = Events.update_event_status(event, "finalizado")
      assert closed_event.status == "finalizado"
      assert %Poll{status: "closed"} = Repo.get!(Poll, poll.id)
    end

    test "update_event_status programado -> en_directo está permitido" do
      event = event_fixture(%{status: "programado"})

      assert {:ok, %Event{status: "en_directo"} = updated} =
               Events.update_event_status(event, "en_directo")

      assert updated.id == event.id
    end

    test "update_event_status rechaza saltos no permitidos" do
      event = event_fixture(%{status: "programado"})
      assert {:error, :invalid_transition} = Events.update_event_status(event, "finalizado")
    end

    test "update_event_status rechaza retrocesos arbitrarios" do
      event = event_fixture(%{status: "en_directo"})
      assert {:error, :invalid_transition} = Events.update_event_status(event, "programado")
    end

    test "update_event_status no permite cambios desde finalizado" do
      event = event_fixture(%{status: "finalizado"})
      assert {:error, :invalid_transition} = Events.update_event_status(event, "en_directo")
    end
  end
end
