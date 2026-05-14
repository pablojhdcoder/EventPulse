defmodule EventPulse.Votes.Vote do
  @moduledoc """
  Voto de un usuario: opción elegida, asociado a una encuesta (`poll_id`) y/o a un
  evento en el modelo legado (`event_id`). Ver validación en `changeset/2`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "votes" do
    field :choice, :string
    field :user_id, :integer
    field :event_id, :integer
    belongs_to :poll, EventPulse.Votes.Poll
    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset para insertar o actualizar un voto (vía `VoteAggregator` + `Repo.insert`).
  """
  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:event_id, :poll_id, :user_id, :choice])
    |> validate_required([:user_id, :choice])
    |> validate_event_or_poll()
    |> unique_constraint([:user_id, :event_id], message: "Ya has votado en este evento")
    |> unique_constraint([:user_id, :poll_id], message: "Ya has votado en esta encuesta")
  end

  defp validate_event_or_poll(changeset) do
    event_id = get_field(changeset, :event_id)
    poll_id = get_field(changeset, :poll_id)

    if is_nil(event_id) and is_nil(poll_id) do
      add_error(changeset, :base, "El voto debe estar asociado a un evento o a una encuesta")
    else
      changeset
    end
  end
end
