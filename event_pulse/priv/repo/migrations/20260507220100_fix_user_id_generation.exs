defmodule EventPulse.Repo.Migrations.FixUserIdGeneration do
  use Ecto.Migration

  def change do
    # Remover el valor por defecto que genera UUID en la BD
    alter table(:users) do
      modify :id, :uuid
      #Ponemos solo ":uuid" para asegurarnos de que NO tenga un "default" en la BD
    end
  end
end
