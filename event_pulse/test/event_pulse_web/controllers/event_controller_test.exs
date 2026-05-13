defmodule EventPulseWeb.EventControllerTest do
  use EventPulseWeb.ConnCase

  import EventPulse.EventsFixtures

  alias EventPulse.Repo
  alias EventPulse.SocialFeeling.Result
  alias EventPulse.Votes

  test "GET show de evento finalizado incluye social_feeling_label y voting_results", %{conn: conn} do
    event =
      event_fixture(%{
        status: "finalizado",
        title: "API SF",
        starts_at: ~U[2026-05-01 10:00:00Z]
      })

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Result{}
    |> Result.changeset(%{
      event_id: event.id,
      score: 0.75,
      label: "positivo",
      numeric_vote_count: 4,
      breakdown: %{},
      computed_at: now
    })
    |> Repo.insert!()

    assert {:ok, _} = Votes.create_poll(event.id, "¿Gustó?", ["1", "2"], contributes_to_feeling: true)

    conn = get(conn, ~p"/api/events/#{event.id}")
    assert %{"data" => data} = json_response(conn, 200)
    assert data["status"] == "finalizado"
    assert data["social_feeling_label"] == "Positivo"
    refute Map.has_key?(data, "social_feeling")
    assert [%{"poll_id" => _, "question" => _} | _] = data["voting_results"]
  end

  test "GET show de evento no finalizado no expone campos de cierre", %{conn: conn} do
    event = event_fixture(%{title: "Prog"})
    conn = get(conn, ~p"/api/events/#{event.id}")
    data = json_response(conn, 200)["data"]
    refute Map.has_key?(data, "social_feeling")
    refute Map.has_key?(data, "social_feeling_label")
    refute Map.has_key?(data, "voting_results")
    assert data["id"] == event.id
  end
end
