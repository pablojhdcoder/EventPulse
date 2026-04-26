defmodule EventPulseWeb.EventControllerTest do
  use EventPulseWeb.ConnCase

  import EventPulse.EventsFixtures
  alias EventPulse.Events.Event

  @create_attrs %{
    status: "some status",
    description: "some description",
    title: "some title",
    category: "some category",
    starts_at: ~U[2026-04-25 07:51:00Z],
    ends_at: ~U[2026-04-25 07:51:00Z]
  }
  @update_attrs %{
    status: "some updated status",
    description: "some updated description",
    title: "some updated title",
    category: "some updated category",
    starts_at: ~U[2026-04-26 07:51:00Z],
    ends_at: ~U[2026-04-26 07:51:00Z]
  }
  @invalid_attrs %{
    status: nil,
    description: nil,
    title: nil,
    category: nil,
    starts_at: nil,
    ends_at: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all events", %{conn: conn} do
      conn = get(conn, ~p"/api/events")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create event" do
    test "renders event when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/events", event: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/events/#{id}")

      assert %{
               "id" => ^id,
               "category" => "some category",
               "description" => "some description",
               "ends_at" => "2026-04-25T07:51:00Z",
               "starts_at" => "2026-04-25T07:51:00Z",
               "status" => "some status",
               "title" => "some title"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/events", event: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update event" do
    setup [:create_event]

    test "renders event when data is valid", %{conn: conn, event: %Event{id: id} = event} do
      conn = put(conn, ~p"/api/events/#{event}", event: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/events/#{id}")

      assert %{
               "id" => ^id,
               "category" => "some updated category",
               "description" => "some updated description",
               "ends_at" => "2026-04-26T07:51:00Z",
               "starts_at" => "2026-04-26T07:51:00Z",
               "status" => "some updated status",
               "title" => "some updated title"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, event: event} do
      conn = put(conn, ~p"/api/events/#{event}", event: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete event" do
    setup [:create_event]

    test "deletes chosen event", %{conn: conn, event: event} do
      conn = delete(conn, ~p"/api/events/#{event}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/events/#{event}")
      end
    end
  end

  defp create_event(_) do
    event = event_fixture()

    %{event: event}
  end
end
