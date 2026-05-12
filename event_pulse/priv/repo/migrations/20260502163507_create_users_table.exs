defmodule EventPulse.Repo.Migrations.CreateUsersTable do
  use Ecto.Migration

  @moduledoc """
  Esta migración crea la tabla "users" en la base de datos con los campos necesarios
  para almacenar la información de los usuarios registrados en la aplicación. La tabla incluye campos para el ID (UUID), nombre de usuario, email, hash de contraseña, rol y timestamps.
  Además, se crean índices únicos para los campos "email" y "username" para garantizar que
  no haya usuarios duplicados con el mismo correo o nombre de usuario, y se agrega una restricción para asegurar que el campo "role" solo acepte los valores "participant" o "admin".
  """

  def change do

    execute "CREATE EXTENSION IF NOT EXISTS \"pgcrypto\""
    #Activamos pgcrypto para asegurar que nuestra base de datos sea capaz de manejar tipos de datos UUID y funciones de seguridad criptográfica
    create table(:users, primary_key: false) do
      # ID generado por Ecto (cliente)
      add :id,            :uuid,   primary_key: true
      #Nombre de usuario: obligatorio (null: false) y máximo 20 caracteres.
      add :username,      :string, null: false, size: 20
      #Email: obligatorio y con espacio suficiente (255 caracteres)
      add :email,         :string, null: false, size: 255
      #Password: se guarda el hash, no el texto plano. Obligatorio.
      add :password_hash, :string, null: false, size: 255
      #Rol: obligatorio, por defecto todos son "participant"
      add :role,          :string, null: false, default: "participant"

      #Crear automáticamente las columnas inerted_at y u
      timestamps()
    end

    create unique_index(:users, [:email]) #no puede haber dos usuarios con el mismo correo
    create unique_index(:users, [:username]) #no puede haber dos nombres repetidos

    create constraint(:users, :role_must_be_valid, check: "role IN ('participant', 'admin')")
    #el campo role solo aceptará los valores "participant" o "admin".Cualquier otro campo dará error.
  end
end
######################################################################################
#Probar migraciones:
#1. Crear migración: mix ecto.gen.migration create_users_table
#2. Editar el archivo de migración generado en priv/repo/migrations/ para definir la estructura de la tabla users
#3. Ejecutar migración: mix ecto.migrate
#4. Verificar estados de migración: mix ecto.migrations

########################################################################################
