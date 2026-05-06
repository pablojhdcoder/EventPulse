defmodule EventPulse.Votes.Poll do
  use Ecto.Schema
  import Ecto.Changeset

  schema "polls" do
    field :question, :string
    field :options, {:array, :string}
    field :status, :string, default: "open"
    belongs_to :event, EventPulse.Events.Event
    has_many :votes, EventPulse.Votes.Vote
    timestamps(type: :utc_datetime)
  end

  def changeset(poll, attrs) do
    poll
    |> cast(attrs, [:question, :options, :status, :event_id])
    |> validate_required([:question, :options, :event_id])
    |> validate_length(:options, min: 2, max: 4)
    |> validate_inclusion(:status, ["open", "closed"])
  end
end
