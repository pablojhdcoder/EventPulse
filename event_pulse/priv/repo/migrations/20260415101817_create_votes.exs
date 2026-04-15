defmodule EventPulse.Repo.Migrations.CreateVotes do
  use Ecto.Migration

  def change do
    create table(:votes) do
      add :user_id, :integer
      add :event_id, :integer
      add :choice, :string

      timestamps(type: :utc_datetime)
    end
    create unique_index(:votes, [:user_id, :event_id])
  end
end
