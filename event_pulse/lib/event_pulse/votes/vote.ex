defmodule EventPulse.Votes.Vote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "votes" do
    field :user_id, :integer
    field :event_id, :integer
    field :choice, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:user_id, :event_id, :choice])
    |> validate_required([:user_id, :event_id, :choice])
  end
end
