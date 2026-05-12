defmodule EventPulse.Votes.Poll do
  alias ElixirLS.LanguageServer.Providers.Definition
  use Ecto.Schema
  import Ecto.Changeset

  # Definición del esquema que mapea a la tabla "polls" de la BD
  schema "polls" do
    field :question, :string
    # Almacena las opciones de respuesta como un array de strings
    field :options, {:array, :string}
    # Estado de la encuesta, por defecto "open" (abierta)
    field :status, :string, default: "open"
    # Cada encuesta está asociada a un evento específico
    belongs_to :event, EventPulse.Events.Event
    # Relación con los votos, una encuesta puede tener muchos votos asociados
    has_many :votes, EventPulse.Votes.Vote
    timestamps(type: :utc_datetime)
  end

  @doc """
  Crea un changeset para validar y transformar los datos de una encuesta.
  """
  def changeset(poll, attrs) do
    poll
    # Cast: filtra los parámetros permitidos
    |> cast(attrs, [:question, :options, :status, :event_id])
    # Campos obligatorios
    |> validate_required([:question, :options, :event_id])
    # Debe haber entre 2 y 4 opciones
    |> validate_length(:options, min: 2, max: 4)
    # El estado solo puede ser "open" o "closed"
    |> validate_inclusion(:status, ["open", "closed"])
  end
end
