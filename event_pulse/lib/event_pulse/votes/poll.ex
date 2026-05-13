defmodule EventPulse.Votes.Poll do
  use Ecto.Schema
  import Ecto.Changeset

  @max_option_length 50

  schema "polls" do
    field :question, :string
    field :options, {:array, :string}
    field :status, :string, default: "open"
    belongs_to :event, EventPulse.Events.Event
    has_many :votes, EventPulse.Votes.Vote
    timestamps(type: :utc_datetime)
  end

  @doc """
  Crea un changeset para validar y transformar los datos de una encuesta.

  Las opciones pueden ser texto libre (palabras, frases cortas) o números.
  Reglas: entre 2 y 4 opciones, sin vacíos, sin duplicados,
  máximo #{@max_option_length} caracteres por opción.
  """
  def changeset(poll, attrs) do
    poll
    |> cast(attrs, [:question, :options, :status, :event_id])
    |> validate_required([:question, :options, :event_id])
    |> validate_length(:question, min: 1, max: 255)
    |> validate_length(:options, min: 2, max: 4)
    |> validate_inclusion(:status, ["open", "closed"])
    |> validate_options()
  end

  defp validate_options(changeset) do
    validate_change(changeset, :options, fn :options, options ->
      cond do
        Enum.any?(options, fn opt -> not is_binary(opt) or String.trim(opt) == "" end) ->
          [options: "las opciones no pueden estar vacías"]

        Enum.any?(options, fn opt -> String.length(String.trim(opt)) > @max_option_length end) ->
          [options: "cada opción puede tener como máximo #{@max_option_length} caracteres"]

        length(options) != length(Enum.uniq(options)) ->
          [options: "las opciones no pueden estar duplicadas"]

        true ->
          []
      end
    end)
  end
end
