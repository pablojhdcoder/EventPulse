defmodule EventPulse.Votes.Vote do
  # Representa un voto individual de un usuario en una encuesta (poll). Cada voto está asociado a una encuesta específica y contiene la opción elegida por el usuario.

  use Ecto.Schema
  import Ecto.Changeset

  schema "votes" do
    # Opción elegida por el usuario, debe ser una de las opciones definidas en la encuesta (poll)
    field :choice, :string
    # ID del usuario que emitió el voto proveniente de la autenticación
    field :user_id, :integer
    # Compatibilidad con la votación directa por evento
    field :event_id, :integer
    # Cada voto está asociado a una encuesta específica
    belongs_to :poll, EventPulse.Votes.Poll
    timestamps(type: :utc_datetime)
  end

  @doc """
  Crea un changeset para registrar un voto.
  """
  def changeset(vote, attrs) do
    vote
    # Cast: filtra los parámetros permitidos para crear un voto
    |> cast(attrs, [:event_id, :poll_id, :user_id, :choice])
    # El voto puede pertenecer a un evento legacy o a una poll
    |> validate_required([:user_id, :choice])
    |> validate_event_or_poll()
    |> unique_constraint([:user_id, :event_id], message: "Ya has votado en este evento")
    # Restringe que un usuario solo pueda votar una vez por encuesta (poll)
    |> unique_constraint([:user_id, :poll_id], message: "Ya has votado en esta encuesta")
  end

  defp validate_event_or_poll(changeset) do
    event_id = get_field(changeset, :event_id)
    poll_id = get_field(changeset, :poll_id)

    if is_nil(event_id) and is_nil(poll_id) do
      add_error(changeset, :base, "El voto debe estar asociado a un evento o a una encuesta")
    else
      changeset
    end
  end
end
