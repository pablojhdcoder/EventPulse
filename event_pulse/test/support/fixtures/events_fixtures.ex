defmodule EventPulse.EventsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `EventPulse.Events` context.
  """

  @doc """
  Generate a event.
  """
  def event_fixture(attrs \\ %{}) do
    {:ok, event} =
      attrs
      |> Enum.into(%{
        category: "some category",
        description: "some description",
        ends_at: ~U[2026-04-25 07:50:00Z],
        starts_at: ~U[2026-04-25 07:50:00Z],
        status: "some status",
        title: "some title"
      })
      |> EventPulse.Events.create_event()

    event
  end

  @doc """
  Generate a event.
  """
  def event_fixture(attrs \\ %{}) do
    {:ok, event} =
      attrs
      |> Enum.into(%{
        category: "some category",
        description: "some description",
        ends_at: ~U[2026-04-25 07:51:00Z],
        starts_at: ~U[2026-04-25 07:51:00Z],
        status: "some status",
        title: "some title"
      })
      |> EventPulse.Events.create_event()

    event
  end
end
