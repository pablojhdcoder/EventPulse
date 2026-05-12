defmodule EventPulse.EventsFixtures do
  @moduledoc """
  Este módulo define funciones auxiliares (test helpers) para crear
  entidades a través del contexto `EventPulse.Events`.

  Se usa principalmente en los archivos de test para generar datos
  válidos de forma rápida.
  """

  @doc """
  Genera un evento con valores por defecto.
  Permite sobrescribir cualquier campo pasando un mapa de atributos.
  """
  def event_fixture(attrs \\ %{}) do
    {:ok, event} =
      attrs
      |> Enum.into(%{
        # Valores por defecto para que el evento sea válido según el esquema definido
        category: "some category",
        description: "some description",
        ends_at: ~U[2026-04-25 07:50:00Z],
        starts_at: ~U[2026-04-25 07:50:00Z],
        status: "programado",
        title: "some title"
      })
      |> EventPulse.Events.create_event()     # Llama a la función del contexto para crear el evento en la base de datos

    event
  end
end
