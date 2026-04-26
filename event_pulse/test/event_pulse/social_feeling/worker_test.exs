defmodule EventPulse.SocialFeeling.WorkerTest do
  use EventPulse.DataCase

  alias EventPulse.Repo
  alias EventPulse.SocialFeeling.Result
  alias EventPulse.SocialFeeling.Worker
  alias EventPulse.Votes.Vote

  describe "process_event_sync/1" do
    test "sin votos -> score 0.0 y label 'sin_datos'" do
      event_id = 888
      assert {:ok, %Result{} = r} = Worker.process_event_sync(event_id)
      assert r.event_id == event_id
      assert r.score == 0.0
      assert r.label == "sin_datos"
      assert r.total_votes == 0
    end

    test "calcula y persiste a partir de los votos en DB" do
      event_id = 999

      votes = [
        {1, "positivo"},
        {2, "positivo"},
        {3, "positivo"},
        {4, "negativo"},
        {5, "neutral"},
        {6, "neutral"}
      ]

      Enum.each(votes, fn {user_id, choice} ->
        %Vote{}
        |> Vote.changeset(%{event_id: event_id, user_id: user_id, choice: choice})
        |> Repo.insert!()
      end)

      assert {:ok, %Result{} = r} = Worker.process_event_sync(event_id)
      assert r.event_id == event_id
      assert r.total_votes == 6
      assert r.label in ["positivo", "neutral", "muy_positivo"]
      assert is_float(r.score)
    end

    test "idempotencia: llamar dos veces reemplaza el resultado sin duplicar" do
      event_id = 777

      assert {:ok, %Result{} = first} = Worker.process_event_sync(event_id)
      assert {:ok, %Result{} = second} = Worker.process_event_sync(event_id)

      assert first.event_id == second.event_id
      assert Repo.aggregate(Result, :count, :event_id) == 1
    end
  end
end
