defmodule EventPulseWeb.Plugs.RequireAuth do
  @moduledoc """
  Plug personalizado para proteger rutas que requieren autenticación. Se encarga de verificar si el usuario
  tiene una sesión activa (es decir, si hay un user_id en la sesión) y, si no es así, redirige al usuario a la página de login con un mensaje de error.
  Además, si el user_id existe pero no corresponde a un usuario válido en la base de
  datos (ej. el usuario fue borrado mientras tenía la sesión activa), también limpia la sesión y redirige al login.
  """

  @behaviour Plug # el módulo debe tener init y call
  import Plug.Conn
  import Phoenix.Controller
  use Phoenix.VerifiedRoutes, #usar rutas verificadas para evitar errores de rutas mal escritas
    endpoint: EventPulseWeb.Endpoint,#url base y generar urls completas
    router: EventPulseWeb.Router #generar rutas basadas en el router (ejemplo: ~p"/login" en vez de "/login")

  alias EventPulse.Accounts.Auth

  #Función para definir que por defecto, si alguien no está logueado, lo mande a "/login"
  @impl Plug
  def init(opts), do: Keyword.put_new(opts, :redirect_to, "/login")

  #Función que se ejecuta en cada petición para gestionar si el usuario tiene o no sesión y que hacer en cada caso.
  @impl Plug
  def call(conn, opts) do
    conn
    |> get_session(:user_id)
    |> ensure_user(conn, opts)
  end

  #Caso 1: No hay usuario logueado
  defp ensure_user(nil, conn, opts) do
    conn
    |> put_flash(:error, "Debes iniciar sesión para acceder.")
    |> redirect(to: opts[:redirect_to])
    |> halt() #Detiene la ejecución de cualquier otro plug o acción después de este punto
  end

  #Caso 2: Hay un usuario logueado
  defp ensure_user(user_id, conn, opts) do
    case Auth.get_user(user_id) do #Miramos en la base de datos si existe
      nil -> #Alguien boorró al usuario de la base de datos mientras tenía la sesión activa (ejemplo: admin borra a un participante)
        conn
        |> clear_session()
        |> put_flash(:error, "Sesión inválida. Por favor inicia sesión de nuevo.")
        |> redirect(to: opts[:redirect_to])
        |> halt()
      #Si hay en la base de datos, gaurdamos el usaurio dentro de la conexión --> cualquier controlador peude acceder a él.
      user ->
        assign(conn, :current_user, user)
    end
  end
end
