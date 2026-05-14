defmodule EventPulse.Accounts.Auth do
  alias EventPulse.Repo
  alias EventPulse.Accounts.User

  @moduledoc """
  Autenticación y gestión de usuarios: registro, login, roles y operaciones sobre el perfil.

  Actúa entre controladores/LiveViews y `Repo`, para que la capa web no duplique lógica de persistencia.

  Funciones principales:
  - `register/1` — alta de usuario
  - `login/2` — inicio de sesión
  - `admin?/1`, `participant?/1`, `can_create_event?/1` — comprobaciones de rol
  - `update_user/2`, `update_password/2` — actualización de datos
  - `delete_user/1` — baja
  """

  @roles_can_create_event ["participant", "admin"]

  # Ejemplo de attrs: %{"username" => "eva", "email" => "eva@mail.com", "password" => "HoLa!145"}
  def register(attrs) do
    %User{}
    # Validaciones del esquema `User`
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  # Obtiene un usuario por id (UUID)
  def get_user(id) do
    Repo.get(User, id)
  end

  # Busca por email (`Repo.get_by/2`).
  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  # Autenticación por email y contraseña (comparación segura con el hash).
  def login(email, password) do
    case get_user_by_email(email) do
      nil ->
        Pbkdf2.no_user_verify()
        {:error, :invalid_credentials}

      user ->
        if Pbkdf2.verify_pass(password, user.password_hash) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end
    end
  end

  def admin?(user), do: user.role == "admin"
  def participant?(user), do: user.role == "participant"
  def can_create_event?(user), do: user.role in @roles_can_create_event

  def update_user(user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end

  def update_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> Repo.update()
  end

  def delete_user(user) do
    Repo.delete(user)
  end
end

#######################################################################################
# Guía rápida para probar `Auth` en IEx
#
# 1. Arranque:
#    $ cd event_pulse
#    $ iex -S mix
#
# 2. Datos de prueba:
#    datos = %{username: "eva", email: "evarendo@mail.com", password: "HoLa!145"}
#
# 3. Registro:
#    {:ok, usuario_reg} = EventPulse.Accounts.Auth.register(datos)
#
# 4. Login correcto:
#    {:ok, eva} = EventPulse.Accounts.Auth.login("evarendo@mail.com", "HoLa!145")
#
# 5. Login fallido (debe devolver {:error, :invalid_credentials}):
#    EventPulse.Accounts.Auth.login("evarendo@mail.com", "clave_mala")
#
# 6. Permisos:
#    EventPulse.Accounts.Auth.can_create_event?(eva)
#
# 7. Actualizar perfil:
#    {:ok, user_editado} = EventPulse.Accounts.Auth.update_user(eva, %{username: "eva_pro"})
#
# 8. Cambiar contraseña:
#    {:ok, user_final} = EventPulse.Accounts.Auth.update_password(user_editado, %{password: "NewPass!456"})
#
# 9. Borrar usuario:
#    EventPulse.Accounts.Auth.delete_user(user_final)
#
# 10. Comprobar borrado (debe ser nil):
#     EventPulse.Accounts.Auth.get_user_by_email("evarendo@mail.com")
#######################################################################################
