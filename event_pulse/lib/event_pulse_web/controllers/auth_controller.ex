defmodule EventPulseWeb.AuthController do
  use EventPulseWeb, :controller

  @moduledoc """
  Controlador encargado de manejar la autenticación de usuarios (login, registro, logout).
  Se encarga de recibir las peticiones del navegador, hablar ocn la lógia
  de negocio (AUth.ex) y decidir que respuesta enviarle al usuario (redireccionar, mostrar mensaje, etc)
  """


  alias EventPulse.Accounts.Auth

  # POST /login: Se activa cuando el usuario pulsa "Iniciar sesión" en el formulario.
  def login(conn, %{"email" => email, "password" => password}) do
    case Auth.login(String.trim(email), String.trim(password)) do
      {:ok, user} ->
        ## Login exitoso, guardamos el UUID del usuario en la cookie de sesión cifrada y redirigimos a la página principal
        conn
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Sesión iniciada correctamente.")
        |> redirect(to: ~p"/")

      {:error, :invalid_credentials} ->
        ## Login fallido - volver al formulario con error
        conn
        |> put_flash(:error, "Email o contraseña incorrectos.")
        |> redirect(to: ~p"/login")
    end
  end

  # POST /register: Se activa cuando el usuario pulsa "Registrarse" en el formulario
  def register(conn, %{"username" => username, "email" => email, "password" => password, "password_confirmation" => password_confirmation}) do
    # Validar que las contraseñas coincidan
    if password != password_confirmation do
      conn
      |> put_flash(:error, "Las contraseñas no coinciden.")
      |> redirect(to: ~p"/register")
    else
      #Preparamos los datos para enviarlos al AUth.register
      attrs = %{
        "username" => String.trim(username),
        "email" => String.trim(email),
        "password" => password
      }

      case Auth.register(attrs) do
        {:ok, user} ->
          # Registro exitoso - loguear automáticamente para que no tenga que hacer login otra vez
          conn
          |> put_session(:user_id, user.id)
          |> put_flash(:info, "Cuenta creada y sesión iniciada correctamente.")
          |> redirect(to: ~p"/")

        {:error, changeset} ->
          # Si el registro falla (ej. email repetido), extraemos el error y lo mostramos
          error_message = get_first_error(changeset)

          conn
          |> put_flash(:error, error_message)
          |> redirect(to: ~p"/register")
      end
    end
  end

  # Logout: Limpia la sesión por completo (borra el user_id de la cookie)
  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "Sesión cerrada correctamente.")
    |> redirect(to: ~p"/login")
  end

  # Función auxiliar para convertir errores técnicos de Ecto en frases legibles
  defp get_first_error(changeset) do
    case changeset.errors do
      [] -> "Error en el registro."
      [{field, {message, _}} | _] -> "#{field}: #{message}"
      [{field, message} | _] -> "#{field}: #{message}"
    end
  end
end
