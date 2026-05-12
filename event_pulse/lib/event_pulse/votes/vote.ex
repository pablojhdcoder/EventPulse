defmodule EventPulse.Votes.Vote do
  # Representa un voto individual de un usuario en una encuesta (poll). Cada voto está asociado a una encuesta específica y contiene la opción elegida por el usuario.

  use Ecto.Schema
  import Ecto.Changeset

  schema "votes" do
    field :choice, :string                    # Opción elegida por el usuario, debe ser una de las opciones definidas en la encuesta (poll)
    field :user_id, :integer                  # ID del usuario que emitió el voto proveniente de la autenticación
    belongs_to :poll, EventPulse.Votes.Poll   # Cada voto está asociado a una encuesta específica
    timestamps(type: :utc_datetime)
  end

  @doc """
  Crea un changeset para registrar un voto.
  """
  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:poll_id, :user_id, :choice])            # Cast: filtra los parámetros permitidos para crear un voto
    |> validate_required([:poll_id, :user_id, :choice])       # Todos los campos son obligatorios para que el voto sea válido
    |> unique_constraint([:user_id, :poll_id], message: "Ya has votado en esta encuesta")   # Restringe que un usuario solo pueda votar una vez por encuesta (poll)
  end
end
