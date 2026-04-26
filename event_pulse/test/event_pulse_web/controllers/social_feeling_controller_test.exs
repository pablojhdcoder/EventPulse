defmodule EventPulseWeb.SocialFeelingControllerTest do
  use EventPulseWeb.ConnCase

  alias EventPulse.SocialFeeling.Worker

  test "400 si el id no es un entero", %{conn: conn} do
    conn = get(conn, ~p"/api/events/abc/social_feeling")
    assert json_response(conn, 400)["error"] == "invalid_id"
  end

  test "404 si aún no hay resultado persistido", %{conn: conn} do
    conn = get(conn, ~p"/api/events/99999/social_feeling")
    assert json_response(conn, 404)["error"] == "social_feeling_not_found"
  end

  test "200 con los datos del Social Feeling tras cerrar (pipeline)", %{conn: conn} do
    event_id = 77_007

    assert {:ok, _} = Worker.process_event_sync(event_id)

    conn = get(conn, ~p"/api/events/#{event_id}/social_feeling")
    data = json_response(conn, 200)["data"]

    assert data["event_id"] == event_id
    assert is_binary(data["label"])
    assert data["total_votes"] == 0
    assert is_map(data["breakdown"])
    assert is_number(data["score"])
  end
end
