defmodule EventPulse.Accounts.User do
  @moduledoc """
  Esquema de Ecto que representa a los usuarios registrados en la aplicación. Define los
  campos que se almacenan en la base de datos (id, username, email, password_hash, role, timestamps) y las validaciones necesarias para crear o actualizar un usuario.
  Además, incluye funciones para hashear la contraseña antes de guardarla, verificar roles y permisos
  y generar cambiosets para crear o actualizar usuarios.
  """
  use Ecto.Schema
  import Ecto.Changeset
  #GEneramos el id (UUID) en Ecto automáticamente, no en la base de datos. SE genera automáticamente durante
  #la inserccion del usaurio con Repo.insert()
  @primary_key {:id, :binary_id, autogenerate: true}
  #CUando otros schemas referencien a User, sus claves foráneas también serán UUID
  @foreign_key_type :binary_id

  schema "users" do
    field :username, :string
    field :email, :string
    field :password_hash, :string
    field :password, :string, virtual: true #Campo temporal. A la bd llega la contraseña hasheada
    field :role, :string, default: "participant"

    timestamps()
    # Agrega campos inserted_at (fecha creación cuenta) y updated_at (fecha última modificación) automáticamente.
  end

  # Registrar usuario nuevo
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :password, :role]) #Permitir pasar role para registrar admin en tests
    |> validate_required([:username, :email, :password])

    # Validar formato básico de email (debe contener @ y un dominio válido)
    |> validate_format(:email, ~r/@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/, message: "Email inválido")

    # Validar longitud del username (mínimo 3, máximo 20 caracteres) y el formato del username (solo letras, números y guiones bajos)
    |> validate_length(:username, min: 3, max: 20, message: "El nombre de usuario debe tener entre 3 y 20 caracteres")
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/, message: "El nombre de usuario solo puede contener letras, números y guiones bajos")

    # Validar que el rol sea uno de los valores válidos
    |> validate_inclusion(:role, ["participant", "admin"])
    # Validar que la contraseña tenga al menos 8 caracteres y contenga mayúsculas, minúsculas, números y símbolos
    |> validate_length(:password, min: 8, message: "La contraseña debe tener al menos 8 caracteres")
    |> validate_format(:password, ~r/(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/, message: "La contraseña debe incluir mayúsculas, minúsculas, números y símbolos")

    |> unique_constraint(:email)
    |> unique_constraint(:username)

    |> hash_password() #La contraseña se guarda en la base de datos hasheada
  end

  # Editar email y/o username
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email])
    |> validate_required([:username, :email])
    # Validar formato de email (debe contener @ y un dominio válido)
    |> validate_format(:email, ~r/@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/)
    # Validar longitud del username (mínimo 3, máximo 20 caracteres) y el formato del username (solo letras, números y guiones bajos)
    |> validate_length(:username, min: 3, max: 20)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/)

    |> unique_constraint(:email)
    |> unique_constraint(:username)
  end

  # Editar contraseña
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8, message: "La contraseña debe tener al menos 8 caracteres")
    |> validate_format(:password, ~r/(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/, message: "La contraseña debe incluir mayúsculas, minúsculas, números y símbolos")
    |> hash_password()
  end

  # Función privada para hashear la contraseña antes de guardarla en la base de datos
  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      pwd -> put_change(changeset, :password_hash, Pbkdf2.hash_pwd_salt(pwd))
    end
  end
end
