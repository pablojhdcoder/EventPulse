defmodule EventPulse.Repo.Migrations.RemoveSocialFeeling do
  use Ecto.Migration

  def up do
    drop_if_exists table(:social_feeling_results)

    alter table(:polls) do
      remove_if_exists :contributes_to_feeling, :boolean
    end
  end

  def down do
    alter table(:polls) do
      add :contributes_to_feeling, :boolean, default: true, null: false
    end

    create table(:social_feeling_results) do
      add :event_id, :integer, null: false
      add :score, :float
      add :label, :string
      add :numeric_vote_count, :integer, default: 0
      add :breakdown, :map
      add :computed_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end
  end
end
