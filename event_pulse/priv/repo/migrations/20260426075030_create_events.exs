defmodule EventPulse.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :title, :string
      add :description, :text
      add :category, :string
      add :status, :string
      add :starts_at, :utc_datetime
      add :ends_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end
  end
end
