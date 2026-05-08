defmodule EventPulse.Votes.Vote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "votes" do
    field :choice, :string
    field :user_id, :integer
    belongs_to :poll, EventPulse.Votes.Poll
    timestamps(type: :utc_datetime)
  end

  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:poll_id, :user_id, :choice])
    |> validate_required([:poll_id, :user_id, :choice])
  end
end
