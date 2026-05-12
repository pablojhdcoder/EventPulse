defmodule EventPulseWeb.AuthController do
  use EventPulseWeb, :controller

  alias EventPulse.Accounts.Auth

  # POST /login - Maneja el login desde el formulario
  def login(conn, %{"email" => email, "password" => password}) do
    case Auth.login(String.trim(email), String.trim(password)) do
      {:ok, user} ->
        # Login exitoso - guardar user_id en sesión y redirigir
        conn
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Sesión iniciada correctamente.")
        |> redirect(to: ~p"/")

      {:error, :invalid_credentials} ->
        # Login fallido - volver al formulario con error
        conn
        |> put_flash(:error, "Email o contraseña incorrectos.")
        |> redirect(to: ~p"/login")
    end
  end

  # POST /register - Maneja el registro desde el formulario
  def register(conn, %{"username" => username, "email" => email, "password" => password, "password_confirmation" => password_confirmation}) do
    # Validar que las contraseñas coincidan
    if password != password_confirmation do
      conn
      |> put_flash(:error, "Las contraseñas no coinciden.")
      |> redirect(to: ~p"/register")
    else
      attrs = %{
        "username" => String.trim(username),
        "email" => String.trim(email),
        "password" => password
      }

      case Auth.register(attrs) do
        {:ok, user} ->
          # Registro exitoso - loguear automáticamente y redirigir
          conn
          |> put_session(:user_id, user.id)
          |> put_flash(:info, "Cuenta creada y sesión iniciada correctamente.")
          |> redirect(to: ~p"/")

        {:error, changeset} ->
          # Mostrar primer error de validación
          error_message = get_first_error(changeset)

          conn
          |> put_flash(:error, error_message)
          |> redirect(to: ~p"/register")
      end
    end
  end

  # Cierra la sesión del usuario y redirige al login
  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "Sesión cerrada correctamente.")
    |> redirect(to: ~p"/login")
  end

  # Función privada para extraer el primer error del changeset
  defp get_first_error(changeset) do
    case changeset.errors do
      [] -> "Error en el registro."
      [{field, {message, _}} | _] -> "#{field}: #{message}"
      [{field, message} | _] -> "#{field}: #{message}"
    end
  end
end
