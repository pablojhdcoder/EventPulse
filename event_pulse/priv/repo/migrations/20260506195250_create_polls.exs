defmodule EventPulse.Repo.Migrations.CreatePolls do
  use Ecto.Migration

  # Archivo de migración para crear la tabla de encuestas (polls) y modificar la tabla de votos (votes) para asociarla a las encuestas en lugar de a los eventos directamente.

  def change do
    # Crea la tabla de encuestas (cada evento puede tener varias)
    create table(:polls) do
      # Cada encuesta está asociada a un evento específico, se borra si desaparece el evento
      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :question, :string, null: false
      # Almacena las opciones de respuesta como un array de strings, no puede ser nulo
      add :options, {:array, :string}, null: false
      # Estado de la encuesta open por defecto
      add :status, :string, default: "open"
      timestamps(type: :utc_datetime)
    end

    create index(:polls, [:event_id])

    # Añadir poll_id a la tabla votes existente
    alter table(:votes) do
      add :poll_id, references(:polls, on_delete: :delete_all)
    end

    # Un usuario solo puede votar una vez por encuesta (poll)
    create unique_index(:votes, [:user_id, :poll_id])
  end
end
