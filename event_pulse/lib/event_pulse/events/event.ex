defmodule EventPulse.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_statuses ["programado", "en_directo", "finalizado"]

  schema "events" do
    field :title, :string
    field :description, :string
    field :category, :string
    field :status, :string, default: "programado"
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:title, :description, :category, :status, :starts_at, :ends_at])
    |> validate_required([:title, :category, :starts_at])
    |> validate_inclusion(:status, @valid_statuses,
      message: "debe ser programado, en_directo o finalizado"
    )
  end

  def valid_statuses, do: @valid_statuses

  @doc """
  Opciones del desplegable de categoría en formularios.
  El valor es el que se persiste en `events.category`.
  """
  def category_select_options do
    [
      {"Deportes", "deportes"},
      {"Música", "musica"},
      {"Política", "politica"},
      {"Cultura", "cultura"},
      {"Tecnología", "tecnologia"}
    ]
  end
end
