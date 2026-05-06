defmodule EventPulse.Repo.Migrations.CreatePolls do
  use Ecto.Migration

  def change do
    # Tabla de votaciones (cada evento puede tener varias)
    create table(:polls) do
      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :question, :string, null: false
      add :options, {:array, :string}, null: false
      add :status, :string, default: "open"
      timestamps(type: :utc_datetime)
    end

    create index(:polls, [:event_id])

    # Añadir poll_id a la tabla votes existente
    alter table(:votes) do
      add :poll_id, references(:polls, on_delete: :delete_all)
    end

    # Reemplazar el índice único antiguo (user_id + event_id)
    # por uno nuevo (user_id + poll_id)
    drop unique_index(:votes, [:user_id, :event_id])
    create unique_index(:votes, [:user_id, :poll_id])
  end
end
