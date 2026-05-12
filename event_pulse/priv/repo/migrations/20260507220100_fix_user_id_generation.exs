defmodule EventPulse.Repo.Migrations.FixUserIdGeneration do
  use Ecto.Migration

  @moduledoc """
  Esta migración corrige la generación del campo "id" en la tabla "users".
  Anteriormente, el campo "id" se generaba automáticamente con un valor UUID por
  defecto en la base de datos, lo que causaba problemas al intentar crear usuarios con UUIDs personalizados (ej. durante las pruebas).
  Esta migración elimina el valor por defecto, permitiendo que el campo "id" sea
  un UUID pero sin generar automáticamente un valor, de modo que podamos asignar manualmente el UUID que queramos al crear usuarios.
  """
  def change do
    # Remover el valor por defecto que genera UUID en la BD
    alter table(:users) do
      modify :id, :uuid
      #Ponemos solo ":uuid" para asegurarnos de que NO tenga un "default" en la BD
    end
  end
end
