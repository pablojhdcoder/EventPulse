defmodule EventPulse.DataCase do
  @moduledoc """
  Caso de prueba para tests que acceden a la capa de datos.

  Puedes definir aquí funciones auxiliares para los tests.

  Si el test usa la base de datos, se activa el *sandbox* SQL y los cambios se revierten
  al terminar cada test. Con PostgreSQL puedes usar `use EventPulse.DataCase, async: true`
  en algunos casos; no es recomendable en otros motores.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias EventPulse.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import EventPulse.DataCase
    end
  end

  setup tags do
    EventPulse.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Arranca el *sandbox* según las etiquetas del test (`async: true/false`).
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(EventPulse.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  Convierte errores del changeset en un mapa de mensajes por campo.

      assert {:error, changeset} = Accounts.create_user(%{password: "corta"})
      assert "es demasiado corto" in errors_on(changeset).password
      assert %{password: ["es demasiado corto"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
