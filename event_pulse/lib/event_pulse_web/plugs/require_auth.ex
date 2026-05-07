defmodule EventPulseWeb.Plugs.RequireAuth do
  # Este plug se encarga de verificar si el usuario está autenticado antes de permitir el acceso a ciertas rutas protegidas.
  # Si el usuario no está autenticado, se redirige al login.
  # Si el usuario está autenticado pero su sesión es inválida (por ejemplo, si el usuario fue eliminado de la base de datos), también se redirige al login y se limpia la sesión.


  @behaviour Plug #Si nos olvidamos de inito o call el compilador avisa

  import Plug.Conn
  import Phoenix.Controller

  alias EventPulse.Accounts.Auth

  @login_path ~p"/login" #ruta del login
  #CUando el plug para a un usuario no atenticado, lo mando aqui


  def init(opts), do: Keyword.put_new(opts, :redirect_to, @login_path)

  @impl Plug
  def call(conn, opts) do
    conn
    |> get_session(:user_id) #Verificamos si hay user_id en la sesion
    |> ensure_user(conn, opts)
    #Si no hay user_id o el user_id no corresponde a un usuario válido, redirigimos al login.
    #Si es válido, asignamos el usuario a conn.assigns.current_user para que esté disponible en los controladores y vistas.
  end

  #Caso 1: NO hay user_id en la sesión (usuario no autenticado)

  defp ensure_user(nil, conn, opts) do
    conn
    |> clear_session()
    # Mensajepara informar al usuario que debe iniciar sesión (opcional, útil si redirigimos a una página de login con un mensaje)
    |> put_flash(:error, "Debes iniciar sesión para acceder.")
    #Redirigimos al login
    |> redirect(to: opts[:redirect_to])
    |> halt()
    #Ningún plug mas se ejecuta despues de este, es decir, no se llega al controlador ni a la vista, se detiene el pipeline de plugs.
    #Esto es importante para evitar que el usuario acceda a rutas protegidas sin autenticarse.
  end

  #Caso2: Hay user_id en la sesión
  defp ensure_user(user_id, conn, opts) do
    case Auth.get_user(user_id) do
      #Usuario existe en sesión pero no en BD --> usuario borrado con sesión activa

      nil ->
        conn
        |> clear_session() #Limpiamos la sesión para evitar problemas futuros con un user_id inválido
        |> put_flash(:error, "Sesión inválida. Por favor inicia sesión de nuevo.")
        |> redirect(to: opts[:redirect_to]) #Redirigimos al login
        |> halt()

      #Usuario válido encontrado en la base de datos, asignamos el usuario a conn.assigns.current_user para que LIveViews pueda saber quien está conectado
      user ->
        assign(conn, :current_user, user)
    end
  end
end
