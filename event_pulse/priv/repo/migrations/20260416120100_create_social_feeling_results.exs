defmodule EventPulse.Repo.Migrations.CreateSocialFeelingResults do
  use Ecto.Migration

  def change do
    create table(:social_feeling_results) do
      add :event_id, :integer, null: false
      add :score, :float, null: false
      add :label, :string, null: false
      add :total_votes, :integer, null: false, default: 0
      # no es estrictamente necesario, pero ensena el recuento de los votos
      add :breakdown, :map, null: false, default: %{}
      add :computed_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:social_feeling_results, [:event_id])
  end
end
