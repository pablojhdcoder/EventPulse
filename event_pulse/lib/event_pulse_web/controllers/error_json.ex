defmodule EventPulseWeb.ErrorJSON do
  @moduledoc """
  Respuestas JSON de error ante fallos en peticiones JSON (configuradas en el endpoint).

  Véase `config/config.exs`.
  """

  # Para personalizar un código concreto, añade cláusulas, por ejemplo:
  #
  # def render("500.json", _assigns) do
  #   %{errors: %{detail: "Error interno del servidor"}}
  # end

  def render(template, _assigns) do
    %{errors: %{detail: json_error_detail(template)}}
  end

  defp json_error_detail("404.json"), do: "No encontrado"
  defp json_error_detail("500.json"), do: "Error interno del servidor"
  defp json_error_detail(other), do: Phoenix.Controller.status_message_from_template(other)
end
