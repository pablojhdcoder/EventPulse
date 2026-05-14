defmodule EventPulseWeb.ErrorHTML do
  @moduledoc """
  Páginas HTML de error (404, 500, etc.).
  """
  use EventPulseWeb, :html

  def render("404.html", _assigns) do
    "No encontrado"
  end

  def render("500.html", _assigns) do
    "Error interno del servidor"
  end

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
