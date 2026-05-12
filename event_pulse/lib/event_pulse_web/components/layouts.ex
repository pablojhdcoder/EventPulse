defmodule EventPulseWeb.Layouts do
  @moduledoc """
  Provides layout components.

  The `app/1` component is the main app layout used by all LiveViews.
  LiveView templates must begin with `<Layouts.app flash={@flash} current_user={@current_user}>`.
  """

  use EventPulseWeb, :html

  embed_templates "layouts/*"
end
