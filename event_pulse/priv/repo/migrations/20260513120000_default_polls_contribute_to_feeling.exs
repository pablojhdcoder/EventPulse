defmodule EventPulse.Repo.Migrations.DefaultPollsContributeToFeeling do
  use Ecto.Migration

  def change do
    alter table(:polls) do
      modify :contributes_to_feeling, :boolean, default: true, null: false
    end
  end
end
