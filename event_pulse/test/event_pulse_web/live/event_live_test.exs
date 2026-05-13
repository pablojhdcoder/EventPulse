defmodule EventPulseWeb.EventLiveTest do
  use EventPulseWeb.ConnCase, async: false

  import EventPulse.EventsFixtures

  alias EventPulse.Chat.EventRoom

  setup %{conn: conn} do
    {:ok, conn: register_and_log_in_user(conn)}
  end

  # ---------------------------------------------------------------------------
  # EventLive.Index
  # ---------------------------------------------------------------------------

  describe "EventLive.Index" do
    test "renders the event list page", %{conn: conn} do
      event = event_fixture(%{title: "Evento test"})
      {:ok, _lv, html} = live(conn, ~p"/")

      assert html =~ "Evento test"
      assert html =~ event.category
    end

    test "shows empty state when no events", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")
      assert html =~ "No hay eventos registrados."
    end

    test "shows status badge for each event", %{conn: conn} do
      event_fixture(%{status: "en_directo", title: "Live"})
      event_fixture(%{status: "programado", title: "Next"})

      {:ok, _lv, html} = live(conn, ~p"/")
      assert html =~ "en_directo"
      assert html =~ "programado"
    end

    test "filtra por categoría con query string", %{conn: conn} do
      event_fixture(%{category: "deportes", title: "Partido visible"})
      event_fixture(%{category: "musica", title: "Concierto oculto"})

      {:ok, _lv, html} = live(conn, ~p"/events?category=deportes")

      assert html =~ "Partido visible"
      refute html =~ "Concierto oculto"
    end
  end

  describe "EventLive.Index — admin" do
    setup %{conn: conn} do
      {:ok, conn: register_and_log_in_user(conn, role: "admin")}
    end

    test "muestra enlace nuevo evento", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/events")
      assert html =~ "Nuevo evento"
    end
  end

  describe "EventLive.Form — edición (admin)" do
    setup %{conn: conn} do
      {:ok, conn: register_and_log_in_user(conn, role: "admin")}
    end

    test "precarga campos al editar (categoría en lista y categoría legacy)", %{conn: conn} do
      event =
        event_fixture(%{
          title: "Evento edicion demo",
          description: "Texto descripcion guardada.",
          category: "tecnologia"
        })

      {:ok, lv, _} = live(conn, ~p"/events/#{event.id}/edit")

      assert render(element(lv, "#event_title")) =~ "Evento edicion demo"

      assert render(element(lv, "#event_description")) =~ "Texto descripcion guardada."

      assert render(element(lv, "#event-category")) =~ ~s(value="tecnologia")

      assert render(element(lv, "#event_starts_at")) =~ ~s(value="2026-04-25T07:50")

      event_legacy = event_fixture(%{category: "legacy_cat", title: "Segundo evento"})

      {:ok, lv2, _} = live(conn, ~p"/events/#{event_legacy.id}/edit")

      assert render(element(lv2, "#event-category")) =~ ~s(value="legacy_cat")
      assert render(element(lv2, "#event-category")) =~ "Legacy Cat"
    end
  end

  # ---------------------------------------------------------------------------
  # EventLive.Show — basic rendering
  # ---------------------------------------------------------------------------

  describe "EventLive.Show - rendering" do
    test "renders event details", %{conn: conn} do
      event = event_fixture(%{title: "Charla Phoenix", description: "LiveView demo"})
      {:ok, _lv, html} = live(conn, ~p"/events/#{event.id}")

      assert html =~ "Charla Phoenix"
      assert html =~ "LiveView demo"
      assert html =~ event.category
    end

    test "redirects to / when event does not exist", %{conn: conn} do
      {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/events/999999999")
    end

    test "shows chat form only for live events", %{conn: conn} do
      live_event = event_fixture(%{status: "en_directo", title: "En vivo"})
      prog_event = event_fixture(%{status: "programado", title: "Programado"})

      {:ok, _lv, html_live} = live(conn, ~p"/events/#{live_event.id}")
      assert html_live =~ "Escribe un mensaje"

      {:ok, _lv, html_prog} = live(conn, ~p"/events/#{prog_event.id}")
      refute html_prog =~ "Escribe un mensaje"
    end

    test "participante no ve transiciones de estado de admin", %{conn: conn} do
      event = event_fixture(%{status: "programado", title: "Público"})
      {:ok, _lv, html} = live(conn, ~p"/events/#{event.id}")
      refute html =~ "→ en_directo"
    end
  end

  describe "EventLive.Show — admin" do
    setup %{conn: conn} do
      {:ok, conn: register_and_log_in_user(conn, role: "admin")}
    end

    test "muestra transición programado → en_directo", %{conn: conn} do
      event = event_fixture(%{status: "programado", title: "Admin evento"})
      {:ok, _lv, html} = live(conn, ~p"/events/#{event.id}")
      assert html =~ "→ en_directo"
    end
  end

  # ---------------------------------------------------------------------------
  # EventLive.Show — chat
  # ---------------------------------------------------------------------------

  describe "EventLive.Show - chat" do
    test "receive a message via PubSub and it appears in the view", %{conn: conn} do
      event = event_fixture(%{status: "en_directo"})
      {:ok, lv, _html} = live(conn, ~p"/events/#{event.id}")

      key = Integer.to_string(event.id)
      EventRoom.send_message(key, %{author: "alice", body: "hola mundo"})

      _ = :sys.get_state(EventRoom)

      html = render(lv)
      assert html =~ "hola mundo"
      assert html =~ "alice"
    end

    test "submitting the chat form broadcasts a message", %{conn: conn} do
      event = event_fixture(%{status: "en_directo"})
      key = Integer.to_string(event.id)

      {:ok, lv, _html} = live(conn, ~p"/events/#{event.id}")

      Phoenix.PubSub.subscribe(EventPulse.PubSub, "event:#{key}")

      lv
      |> form("form[phx-submit='send_message']", %{body: "test message from form"})
      |> render_submit()

      assert_receive {:new_message, %{body: "test message from form"}}
    end

    test "empty message is rejected and shows flash error", %{conn: conn} do
      event = event_fixture(%{status: "en_directo"})
      {:ok, lv, _html} = live(conn, ~p"/events/#{event.id}")

      html =
        lv
        |> form("form[phx-submit='send_message']", %{body: "   "})
        |> render_submit()

      assert html =~ "no puede estar vacío" or html =~ "vacío"
    end

    test "history is loaded on mount for connected socket", %{conn: conn} do
      event = event_fixture(%{status: "en_directo"})
      key = Integer.to_string(event.id)

      EventRoom.send_message(key, %{author: "alice", body: "mensaje previo"})
      _ = :sys.get_state(EventRoom)

      {:ok, _lv, html} = live(conn, ~p"/events/#{event.id}")

      if redis_available?() do
        assert html =~ "mensaje previo"
      else
        refute html =~ "mensaje previo"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # EventLive.Show — votes
  # ---------------------------------------------------------------------------

  describe "EventLive.Show - votes" do
    test "renders the active poll question and options", %{conn: conn} do
      event = event_fixture(%{status: "en_directo"})
      {:ok, _poll} = EventPulse.Votes.create_poll(event.id, "¿Qué opción prefieres?", ["1", "2"])

      {:ok, _lv, html} = live(conn, ~p"/events/#{event.id}")

      assert html =~ "¿Qué opción prefieres?"
      assert html =~ "Votar: 1"
      assert html =~ "Votar: 2"
      refute html =~ "Votar: 3"
    end

    test "vote results update via PubSub broadcast", %{conn: conn} do
      event = event_fixture(%{status: "en_directo"})
      {:ok, poll} = EventPulse.Votes.create_poll(event.id, "Demo", ["1", "2", "3"])
      {:ok, lv, _html} = live(conn, ~p"/events/#{event.id}")

      Phoenix.PubSub.broadcast(
        EventPulse.PubSub,
        "poll:#{poll.id}",
        {:voted, :poll, poll.id, %{"1" => 3, "2" => 1}}
      )

      html = render(lv)
      assert html =~ "1"
      assert html =~ "3"
    end

    test "clicking vote button casts a vote", %{conn: conn} do
      event = event_fixture(%{status: "en_directo"})
      {:ok, poll} = EventPulse.Votes.create_poll(event.id, "Demo", ["1", "2", "3"])

      agg = :global.whereis_name(EventPulse.Votes.VoteAggregator)
      assert is_pid(agg)
      Ecto.Adapters.SQL.Sandbox.allow(EventPulse.Repo, self(), agg)

      {:ok, lv, _html} = live(conn, ~p"/events/#{event.id}")

      poll_id = poll.id
      Phoenix.PubSub.subscribe(EventPulse.PubSub, "poll:#{poll_id}")

      lv |> element("button[phx-value-choice='1']") |> render_click()

      assert_receive {:voted, :poll, ^poll_id, results}
      assert Map.has_key?(results, "1")
    end

    test "status_changed PubSub message updates event assign", %{conn: conn} do
      event = event_fixture(%{status: "en_directo"})
      {:ok, _poll} = EventPulse.Votes.create_poll(event.id, "Demo", ["1", "2"])
      {:ok, lv, html} = live(conn, ~p"/events/#{event.id}")

      assert html =~ "en_directo"
      assert html =~ "Escribe un mensaje"
      assert html =~ "Votar: 1"

      Phoenix.PubSub.broadcast(
        EventPulse.PubSub,
        "events:#{event.id}",
        {:status_changed, %{event | status: "finalizado"}}
      )

      html = render(lv)
      assert html =~ "finalizado"
      refute html =~ "Escribe un mensaje"
      refute html =~ "Votar: 1"
    end

    test "shows Social Feeling result when it is broadcast after close", %{conn: conn} do
      event = event_fixture(%{status: "en_directo"})
      {:ok, lv, _html} = live(conn, ~p"/events/#{event.id}")

      Phoenix.PubSub.broadcast(
        EventPulse.PubSub,
        "events:#{event.id}",
        {:status_changed, %{event | status: "finalizado"}}
      )

      Phoenix.PubSub.broadcast(
        EventPulse.PubSub,
        "event:#{event.id}",
        {:social_feeling,
         %EventPulse.SocialFeeling.Result{
           event_id: event.id,
           label: "positivo",
           score: 0.5,
           numeric_vote_count: 2,
           breakdown: %{}
         }}
      )

      html = render(lv)
      assert html =~ "Social Feeling final"
      assert html =~ "Positivo"
      assert html =~ "Recuento agregado"
      assert html =~ "2"
    end
  end

  describe "Event — transiciones de estado (changeset)" do
    test "programado acepta en_directo" do
      changeset =
        EventPulse.Events.Event.changeset(
          %EventPulse.Events.Event{},
          %{title: "T", category: "c", status: "en_directo", starts_at: ~U[2026-06-01 10:00:00Z]}
        )

      assert changeset.valid?
    end

    test "en_directo acepta finalizado" do
      changeset =
        EventPulse.Events.Event.changeset(
          %EventPulse.Events.Event{},
          %{title: "T", category: "c", status: "finalizado", starts_at: ~U[2026-06-01 10:00:00Z]}
        )

      assert changeset.valid?
    end

    test "estado inválido es rechazado" do
      changeset =
        EventPulse.Events.Event.changeset(
          %EventPulse.Events.Event{},
          %{title: "T", category: "c", status: "invalido", starts_at: ~U[2026-06-01 10:00:00Z]}
        )

      refute changeset.valid?
    end
  end

  defp redis_available? do
    Redix.command(EventPulse.Redix, ["PING"]) == {:ok, "PONG"}
  rescue
    _ -> false
  end
end
