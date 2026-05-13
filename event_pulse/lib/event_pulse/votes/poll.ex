defmodule EventPulse.Votes.Poll do
  use Ecto.Schema
  import Ecto.Changeset

  # Definición del esquema que mapea a la tabla "polls" de la BD
  schema "polls" do
    field :question, :string
    # Almacena las opciones de respuesta como un array de strings
    field :options, {:array, :string}
    # Todas las votaciones son numéricas y alimentan el Social Feeling.
    field :contributes_to_feeling, :boolean, default: true
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
    |> cast(attrs, [:question, :options, :status, :event_id, :contributes_to_feeling])
    # Campos obligatorios
    |> validate_required([:question, :options, :event_id])
    # Debe haber entre 2 y 4 opciones
    |> validate_length(:options, min: 2, max: 4)
    # El estado solo puede ser "open" o "closed"
    |> validate_inclusion(:status, ["open", "closed"])
    |> put_change(:contributes_to_feeling, true)
    |> validate_numeric_options()
  end

  defp validate_numeric_options(changeset) do
    options = Ecto.Changeset.get_field(changeset, :options) || []

    if options != [] and Enum.all?(options, &integer_string?/1) do
      changeset
    else
      add_error(
        changeset,
        :options,
        "todas las opciones de votación deben ser números enteros (ej. 1, 2, 3)"
      )
    end
  end

  defp integer_string?(s) when is_binary(s) do
    case Integer.parse(String.trim(s)) do
      {_n, ""} -> true
      _ -> false
    end
  end

  defp integer_string?(_), do: false
end
