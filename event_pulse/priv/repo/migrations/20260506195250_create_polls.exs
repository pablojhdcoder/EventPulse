defmodule EventPulse.Repo.Migrations.CreatePolls do
  use Ecto.Migration
  # Archivo de migración para crear la tabla de encuestas (polls) y modificar la tabla de votos (votes) para asociarla a las encuestas en lugar de a los eventos directamente.

  def change do
    # Crea la tabla de encuestas (cada evento puede tener varias)
    create table(:polls) do
      add :event_id, references(:events, on_delete: :delete_all), null: false       # Cada encuesta está asociada a un evento específico, se borra si desaparece el evento
      add :question, :string, null: false
      add :options, {:array, :string}, null: false        # Almacena las opciones de respuesta como un array de strings, no puede ser nulo
      add :status, :string, default: "open"               # Estado de la encuesta open por defecto
      timestamps(type: :utc_datetime)
    end

    create index(:polls, [:event_id])

    # Añadir poll_id a la tabla votes existente
    alter table(:votes) do
      add :poll_id, references(:polls, on_delete: :delete_all)
    end


    drop unique_index(:votes, [:user_id, :event_id])      # Quitamos la restricción de que un usuario solo pueda votar una vez por evento
    create unique_index(:votes, [:user_id, :poll_id])     # Y ponemos que un usuario solo puede votar una vez por encuesta (poll)
  end
end
