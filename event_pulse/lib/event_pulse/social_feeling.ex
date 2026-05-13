defmodule EventPulse.SocialFeeling do
  @moduledoc """
  API pública del subdominio **Social Feeling**.

  - `calculate/1` / `calculate/2`: cálculo puro delegado en
    `EventPulse.SocialFeeling.Calculator`.
  - `get_for_event/1`: obtiene el resultado persistido de un evento o
    `nil` si aún no se ha calculado.
  """

  alias EventPulse.Repo
  alias EventPulse.SocialFeeling.Calculator
  alias EventPulse.SocialFeeling.Result

  defdelegate calculate(vote_counts), to: Calculator
  defdelegate calculate(vote_counts, opts), to: Calculator

  @label_display %{
    "muy_positivo" => "Muy positivo",
    "positivo" => "Positivo",
    "neutral" => "Neutral",
    "negativo" => "Negativo",
    "muy_negativo" => "Muy negativo",
    "sin_datos" => "Sin datos"
  }

  @doc """
  Convierte la etiqueta persistida (snake_case) a texto legible para la UI/API.
  """
  @spec humanize_label(String.t() | atom() | nil) :: String.t() | nil
  def humanize_label(nil), do: nil

  def humanize_label(label) when is_atom(label), do: humanize_label(Atom.to_string(label))

  def humanize_label(label) when is_binary(label) do
    case String.trim(label) do
      "" ->
        nil

      trimmed ->
        case Map.get(@label_display, trimmed) do
          nil -> titleize_snake(trimmed)
          display -> display
        end
    end
  end

  defp titleize_snake(s) do
    s
    |> String.split("_", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  @doc "Devuelve el resultado persistido del evento o `nil`."
  @spec get_for_event(integer()) :: Result.t() | nil
  def get_for_event(event_id), do: Repo.get_by(Result, event_id: event_id)
end
