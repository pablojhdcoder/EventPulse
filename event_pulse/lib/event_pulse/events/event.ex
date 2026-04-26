defmodule EventPulse.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  schema "events" do
    field :title, :string
    field :description, :string
    field :category, :string
    field :status, :string
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:title, :description, :category, :status, :starts_at, :ends_at])
    |> validate_required([:title, :description, :category, :status, :starts_at, :ends_at])
  end
end
