defmodule EventPulse.Repo.Migrations.CreateUsersTable do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS \"pgcrypto\""

    create table(:users, primary_key: false) do
      add :id,            :uuid,   primary_key: true, default: fragment("gen_random_uuid()")
      add :username,      :string, null: false, size: 20
      add :email,         :string, null: false, size: 255
      add :password_hash, :string, null: false, size: 255
      add :role,          :string, null: false, default: "participant"

      timestamps()
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:username])

    create constraint(:users, :role_must_be_valid, check: "role IN ('participant', 'admin')")
  end
end
