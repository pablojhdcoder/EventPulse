defmodule EventPulse.EventsTest do
  use EventPulse.DataCase

  alias EventPulse.Events

  describe "events" do
    alias EventPulse.Events.Event

    import EventPulse.EventsFixtures

    @invalid_attrs %{status: nil, description: nil, title: nil, category: nil, starts_at: nil, ends_at: nil}

    test "list_events/0 returns all events" do
      event = event_fixture()
      assert Events.list_events() == [event]
    end

    test "get_event!/1 returns the event with given id" do
      event = event_fixture()
      assert Events.get_event!(event.id) == event
    end

    test "create_event/1 with valid data creates a event" do
      valid_attrs = %{status: "some status", description: "some description", title: "some title", category: "some category", starts_at: ~U[2026-04-25 07:50:00Z], ends_at: ~U[2026-04-25 07:50:00Z]}

      assert {:ok, %Event{} = event} = Events.create_event(valid_attrs)
      assert event.status == "some status"
      assert event.description == "some description"
      assert event.title == "some title"
      assert event.category == "some category"
      assert event.starts_at == ~U[2026-04-25 07:50:00Z]
      assert event.ends_at == ~U[2026-04-25 07:50:00Z]
    end

    test "create_event/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Events.create_event(@invalid_attrs)
    end

    test "update_event/2 with valid data updates the event" do
      event = event_fixture()
      update_attrs = %{status: "some updated status", description: "some updated description", title: "some updated title", category: "some updated category", starts_at: ~U[2026-04-26 07:50:00Z], ends_at: ~U[2026-04-26 07:50:00Z]}

      assert {:ok, %Event{} = event} = Events.update_event(event, update_attrs)
      assert event.status == "some updated status"
      assert event.description == "some updated description"
      assert event.title == "some updated title"
      assert event.category == "some updated category"
      assert event.starts_at == ~U[2026-04-26 07:50:00Z]
      assert event.ends_at == ~U[2026-04-26 07:50:00Z]
    end

    test "update_event/2 with invalid data returns error changeset" do
      event = event_fixture()
      assert {:error, %Ecto.Changeset{}} = Events.update_event(event, @invalid_attrs)
      assert event == Events.get_event!(event.id)
    end

    test "delete_event/1 deletes the event" do
      event = event_fixture()
      assert {:ok, %Event{}} = Events.delete_event(event)
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(event.id) end
    end

    test "change_event/1 returns a event changeset" do
      event = event_fixture()
      assert %Ecto.Changeset{} = Events.change_event(event)
    end
  end

  describe "events" do
    alias EventPulse.Events.Event

    import EventPulse.EventsFixtures

    @invalid_attrs %{status: nil, description: nil, title: nil, category: nil, starts_at: nil, ends_at: nil}

    test "list_events/0 returns all events" do
      event = event_fixture()
      assert Events.list_events() == [event]
    end

    test "get_event!/1 returns the event with given id" do
      event = event_fixture()
      assert Events.get_event!(event.id) == event
    end

    test "create_event/1 with valid data creates a event" do
      valid_attrs = %{status: "some status", description: "some description", title: "some title", category: "some category", starts_at: ~U[2026-04-25 07:51:00Z], ends_at: ~U[2026-04-25 07:51:00Z]}

      assert {:ok, %Event{} = event} = Events.create_event(valid_attrs)
      assert event.status == "some status"
      assert event.description == "some description"
      assert event.title == "some title"
      assert event.category == "some category"
      assert event.starts_at == ~U[2026-04-25 07:51:00Z]
      assert event.ends_at == ~U[2026-04-25 07:51:00Z]
    end

    test "create_event/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Events.create_event(@invalid_attrs)
    end

    test "update_event/2 with valid data updates the event" do
      event = event_fixture()
      update_attrs = %{status: "some updated status", description: "some updated description", title: "some updated title", category: "some updated category", starts_at: ~U[2026-04-26 07:51:00Z], ends_at: ~U[2026-04-26 07:51:00Z]}

      assert {:ok, %Event{} = event} = Events.update_event(event, update_attrs)
      assert event.status == "some updated status"
      assert event.description == "some updated description"
      assert event.title == "some updated title"
      assert event.category == "some updated category"
      assert event.starts_at == ~U[2026-04-26 07:51:00Z]
      assert event.ends_at == ~U[2026-04-26 07:51:00Z]
    end

    test "update_event/2 with invalid data returns error changeset" do
      event = event_fixture()
      assert {:error, %Ecto.Changeset{}} = Events.update_event(event, @invalid_attrs)
      assert event == Events.get_event!(event.id)
    end

    test "delete_event/1 deletes the event" do
      event = event_fixture()
      assert {:ok, %Event{}} = Events.delete_event(event)
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(event.id) end
    end

    test "change_event/1 returns a event changeset" do
      event = event_fixture()
      assert %Ecto.Changeset{} = Events.change_event(event)
    end
  end
end
