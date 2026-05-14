defmodule EventPulseWeb.Layouts do
  @moduledoc """
  Componentes de diseño (layouts).

  El componente `app/1` es el layout principal de la aplicación para las LiveViews.
  Las plantillas LiveView deben empezar con `<Layouts.app flash={@flash} current_user={@current_user}>`.
  """

  use EventPulseWeb, :html

  embed_templates "layouts/*"
end
