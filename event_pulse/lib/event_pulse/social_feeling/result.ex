defmodule EventPulse.SocialFeeling.Result do
  @moduledoc """
  Resultado persistente del Social Feeling para un evento cerrado.

  Un resultado por evento (unique index sobre `event_id`). Al recerrar
  un evento, el `SocialFeelingWorker` reemplaza los campos salvo
  `id` e `inserted_at`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}

  schema "social_feeling_results" do
    field :event_id, :integer
    field :score, :float
    field :label, :string
    field :total_votes, :integer, default: 0
    field :breakdown, :map, default: %{}
    field :computed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(result, attrs) do
    result
    |> cast(attrs, [:event_id, :score, :label, :total_votes, :breakdown, :computed_at])
    |> validate_required([:event_id, :score, :label, :total_votes, :breakdown, :computed_at])
    |> validate_number(:score, greater_than_or_equal_to: -1.0, less_than_or_equal_to: 1.0)
    |> validate_number(:total_votes, greater_than_or_equal_to: 0)
    |> unique_constraint(:event_id)
  end
end
