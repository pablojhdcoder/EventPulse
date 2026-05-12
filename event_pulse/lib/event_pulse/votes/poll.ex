defmodule EventPulse.Votes.Poll do
  alias ElixirLS.LanguageServer.Providers.Definition
  use Ecto.Schema
  import Ecto.Changeset

  # Definición del esquema que mapea a la tabla "polls" de la BD
  schema "polls" do
    field :question, :string
    field :options, {:array, :string}           # Almacena las opciones de respuesta como un array de strings
    field :status, :string, default: "open"     # Estado de la encuesta, por defecto "open" (abierta)
    belongs_to :event, EventPulse.Events.Event  # Cada encuesta está asociada a un evento específico
    has_many :votes, EventPulse.Votes.Vote      # Relación con los votos, una encuesta puede tener muchos votos asociados
    timestamps(type: :utc_datetime)
  end

  @doc """
  Crea un changeset para validar y transformar los datos de una encuesta.
  """
  def changeset(poll, attrs) do
    poll
    |> cast(attrs, [:question, :options, :status, :event_id])     # Cast: filtra los parámetros permitidos
    |> validate_required([:question, :options, :event_id])        # Campos obligatorios
    |> validate_length(:options, min: 2, max: 4)                  # Debe haber entre 2 y 4 opciones
    |> validate_inclusion(:status, ["open", "closed"])            # El estado solo puede ser "open" o "closed"
  end
end
