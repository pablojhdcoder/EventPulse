defmodule EventPulse.Accounts.Auth do
  alias EventPulse.Repo
  alias EventPulse.Accounts.User

  @roles_can_create_event ["participant", "admin"]

  # Función para registrar un nuevo usuario
  def register(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  # Función para obtener un usuario por su ID
  def get_user(id) do
    Repo.get(User, id)
  end

  # Función para obtener un usuario por su email
  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  # Función para autenticar a un usuario con email y contraseña
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

  # Funciones para verificar roles y permisos
  def admin?(user), do: user.role == "admin"
  def participant?(user), do: user.role == "participant"
  def can_create_event?(user), do: user.role in @roles_can_create_event

  # Función para actualizar el email y/o username de un usuario
  def update_user(user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end

  # Función para actualizar la contraseña de un usuario
  def update_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> Repo.update()
  end

  # Función para borrar un usuario
  def delete_user(user) do
    Repo.delete(user)
  end
end

#######################################################################################
# GUÍA DE PRUEBAS PARA EL MÓDULO AUTH EN IEX
#
# Sigue estos pasos en la terminal para verificar el funcionamiento del sistema:
#
# 1. Preparación:
#    $ cd event_pulse
#    $ sudo service postgresql start
#    $ iex -S mix
#
# 2. Definir datos de prueba:
#    datos = %{username: "eva", email: "evarendo@mail.com", password: "HoLa!145"}
#
# 3. Registro (Devuelve {:ok, user}):
#    {:ok, usuario_reg} = EventPulse.Accounts.Auth.register(datos)
#
# 4. Login Correcto (Necesario para cargar el ID/UUID real de la DB):
#    {:ok, eva} = EventPulse.Accounts.Auth.login("evarendo@mail.com", "HoLa!145")
#
#
# 5. Login Fallido (Verifica seguridad):
#    EventPulse.Accounts.Auth.login("evarendo@mail.com", "password_incorrecta")
#    # Debería devolver: {:error, :invalid_credentials}
#
# 6. Verificar Roles/Permisos:
#    EventPulse.Accounts.Auth.can_create_event?(eva)
#    # Debería devolver: true
#
# 7. Actualizar Usuario (Update):
#    {:ok, user_editado} = EventPulse.Accounts.Auth.update_user(eva, %{username: "eva_pro"})
#
# 8. Actualizar Contraseña:
#    {:ok, user_final} = EventPulse.Accounts.Auth.update_password(user_editado, %{password: "NewPass!456"})
#
# 9. Borrar y Limpiar:
#    EventPulse.Accounts.Auth.delete_user(user_final)
#
# 10. Verificación Final (Debe ser nil):
#     EventPulse.Accounts.Auth.get_user_by_email("evarendo@mail.com")
#    # Debería devolver: nil
#######################################################################################
