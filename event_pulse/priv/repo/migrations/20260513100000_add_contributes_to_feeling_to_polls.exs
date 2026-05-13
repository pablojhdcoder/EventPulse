defmodule EventPulse.Repo.Migrations.AddContributesToFeelingToPolls do
  use Ecto.Migration

  def change do
    alter table(:polls) do
      add :contributes_to_feeling, :boolean, null: false, default: false
    end
  end
end
