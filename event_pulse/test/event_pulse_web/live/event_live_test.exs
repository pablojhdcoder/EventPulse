defmodule EventPulseWeb.EventLiveTest do
  use EventPulseWeb.ConnCase

  alias EventPulse.Events

  defp create_event(_) do
    {:ok, event} = Events.create_event(%{
      title: "Evento Test",
      category: "deportes",
      status: "programado",
      starts_at: ~U[2026-06-01 10:00:00Z]
    })
    %{event: event}
  end

  describe "Index - listado de eventos" do
    setup [:create_event]

    test "muestra la lista de eventos", %{conn: conn, event: event} do
      {:ok, _view, html} = live(conn, ~p"/events")
      assert html =~ event.title
      assert html =~ "deportes"
    end

    test "filtra eventos por categoría", %{conn: conn, event: event} do
      {:ok, view, _html} = live(conn, ~p"/events")
      html = view |> element("select[name='category']") |> render_change(%{category: "deportes"})
      assert html =~ event.title
    end

    test "no muestra botón nuevo evento sin admin", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/events")
      refute html =~ "Nuevo Evento"
    end
  end

  describe "Show - detalle del evento" do
    setup [:create_event]

    test "muestra el detalle del evento", %{conn: conn, event: event} do
      {:ok, _view, html} = live(conn, ~p"/events/#{event.id}")
      assert html =~ event.title
      assert html =~ "programado"
    end

    test "no muestra botón cambiar estado sin admin", %{conn: conn, event: event} do
      {:ok, _view, html} = live(conn, ~p"/events/#{event.id}")
      refute html =~ "→ en_directo"
    end
  end

  describe "transiciones de estado" do
    test "programado acepta en_directo" do
      changeset = EventPulse.Events.Event.changeset(
        %EventPulse.Events.Event{},
        %{title: "T", category: "c", status: "en_directo", starts_at: ~U[2026-06-01 10:00:00Z]}
      )
      assert changeset.valid?
    end

    test "en_directo acepta finalizado" do
      changeset = EventPulse.Events.Event.changeset(
        %EventPulse.Events.Event{},
        %{title: "T", category: "c", status: "finalizado", starts_at: ~U[2026-06-01 10:00:00Z]}
      )
      assert changeset.valid?
    end

    test "estado inválido es rechazado" do
      changeset = EventPulse.Events.Event.changeset(
        %EventPulse.Events.Event{},
        %{title: "T", category: "c", status: "invalido", starts_at: ~U[2026-06-01 10:00:00Z]}
      )
      refute changeset.valid?
    end
  end
end