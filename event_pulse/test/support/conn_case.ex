defmodule EventPulseWeb.ConnCase do
  @moduledoc """
  Caso de prueba para tests que necesitan una `conn` HTTP.

  Usa `Phoenix.ConnTest` e importa utilidades para construir datos y consultar capas.
  Si el test toca la base de datos, se activa el *sandbox* SQL y los cambios se revierten
  al terminar cada test. Con PostgreSQL puedes usar `use EventPulseWeb.ConnCase, async: true`
  en algunos casos; no es recomendable en otros motores.
  """

  use ExUnit.CaseTemplate

  alias EventPulse.Accounts.Auth

  using do
    quote do
      # Endpoint por defecto en tests
      @endpoint EventPulseWeb.Endpoint

      use EventPulseWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import EventPulseWeb.ConnCase
    end
  end

  setup tags do
    EventPulse.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Registra un usuario y rellena la sesión de prueba con `user_id` y `demo_user_id`.
  Útil para rutas protegidas con `RequireAuth` y LiveViews que necesitan ambos.

  Opciones: `role: "admin" | "participant"` (por defecto participant).
  """
  def register_and_log_in_user(conn, opts \\ []) do
    role = Keyword.get(opts, :role, "participant")
    suffix = System.unique_integer([:positive])

    {:ok, user} =
      Auth.register(%{
        # Mínimo 3 caracteres; `suffix` puede ser un entero pequeño.
        "username" => "tu#{suffix}",
        "email" => "e#{suffix}@example.com",
        "password" => "TestP1!xx",
        "role" => role
      })

    conn
    |> Plug.Test.init_test_session(%{
      "user_id" => user.id,
      "demo_user_id" => rem(suffix, 900_000) + 100_000
    })
  end
end
