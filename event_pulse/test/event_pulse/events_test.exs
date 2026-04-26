defmodule EventPulse.EventsTest do
  use EventPulse.DataCase

  alias EventPulse.Events.Event

  describe "changeset/2 - validaciones de campos" do
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

    test "valid_statuses devuelve los tres estados" do
      assert Event.valid_statuses() == ["programado", "en_directo", "finalizado"]
    end
  end
end
