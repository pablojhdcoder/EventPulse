defmodule EventPulseWeb.EventLiveTest do
  use EventPulseWeb.ConnCase, async: false

  import EventPulse.EventsFixtures

  alias EventPulse.Chat.EventRoom

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
    test "vote results update via PubSub broadcast", %{conn: conn} do
      event = event_fixture(%{status: "en_directo"})
      {:ok, lv, _html} = live(conn, ~p"/events/#{event.id}")

      Phoenix.PubSub.broadcast(
        EventPulse.PubSub,
        "event:#{event.id}",
        {:voted, %{"SÍ" => 3, "NO" => 1}}
      )

      html = render(lv)
      assert html =~ "SÍ"
      assert html =~ "3"
    end

    test "clicking vote button casts a vote", %{conn: conn} do
      event = event_fixture(%{status: "en_directo"})
      {:ok, lv, _html} = live(conn, ~p"/events/#{event.id}")

      Phoenix.PubSub.subscribe(EventPulse.PubSub, "event:#{event.id}")

      lv |> element("button[phx-value-choice='SÍ']") |> render_click()

      assert_receive {:voted, results}
      assert Map.has_key?(results, "SÍ")
    end

    test "status_changed PubSub message updates event assign", %{conn: conn} do
      event = event_fixture(%{status: "en_directo"})
      {:ok, lv, html} = live(conn, ~p"/events/#{event.id}")

      assert html =~ "en_directo"

      Phoenix.PubSub.broadcast(
        EventPulse.PubSub,
        "events:#{event.id}",
        {:status_changed, %{event | status: "finalizado"}}
      )

      html = render(lv)
      assert html =~ "finalizado"
    end
  end

  defp redis_available? do
    Redix.command(EventPulse.Redix, ["PING"]) == {:ok, "PONG"}
  rescue
    _ -> false
  end
end
