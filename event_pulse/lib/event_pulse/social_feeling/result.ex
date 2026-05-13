defmodule EventPulse.SocialFeeling.Result do
  @moduledoc """
  Resultado persistente del Social Feeling para un evento cerrado.

  `numeric_vote_count` es la suma de filas de voto en encuestas numéricas que
  intervinieron en el agregado (no participantes únicos).

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
    field :numeric_vote_count, :integer, default: 0
    field :breakdown, :map, default: %{}
    field :computed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(result, attrs) do
    result
    |> cast(attrs, [:event_id, :score, :label, :numeric_vote_count, :breakdown, :computed_at])
    |> validate_required([:event_id, :numeric_vote_count, :computed_at])
    |> validate_number(:numeric_vote_count, greater_than_or_equal_to: 0)
    |> validate_score_label_pair()
    |> unique_constraint(:event_id)
  end

  defp validate_score_label_pair(changeset) do
    score = get_field(changeset, :score)
    label = get_field(changeset, :label)

    cond do
      is_nil(score) and is_nil(label) ->
        changeset

      not is_nil(score) and not is_nil(label) ->
        changeset
        |> validate_number(:score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)

      true ->
        add_error(changeset, :score, "debe ser nil junto con label o ambos presentes")
    end
  end
end
