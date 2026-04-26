defmodule EventPulse.SocialFeeling.Calculator do
  @moduledoc """
  Cálculo puro del Social Feeling a partir de un recuento de votos.

  ## Fórmula

  Dado un mapa `%{choice => count}` y una tabla de pesos (por defecto en
  `@default_weights`), el `score` se obtiene como la **media ponderada**:

      score = sum(weight(choice) * count) / total_votos

  siempre en el rango `[-1.0, 1.0]`. Los `choice` no contemplados en la
  tabla de pesos cuentan como neutros (peso 0.0) pero **sí suman** al
  total para no sesgar la media.

  A partir del `score` se asigna una etiqueta cualitativa
  (`:muy_negativo`, `:negativo`, `:neutral`, `:positivo`,
  `:muy_positivo`). Sin votos, el resultado es `:sin_datos`.
  """

  @type vote_counts :: %{String.t() => non_neg_integer()}
  @type result :: %{
          score: float(),
          label:
            :muy_negativo | :negativo | :neutral | :positivo | :muy_positivo | :sin_datos,
          total_votes: non_neg_integer(),
          breakdown: vote_counts()
        }

  @default_weights %{
    "muy_positivo" => 1.0,
    "positivo" => 0.5,
    "neutral" => 0.0,
    "negativo" => -0.5,
    "muy_negativo" => -1.0
  }

  @doc "Devuelve los pesos por defecto utilizados por `calculate/1`."
  def default_weights, do: @default_weights

  @doc "Calcula el Social Feeling con los pesos por defecto."
  @spec calculate(vote_counts()) :: result()
  def calculate(vote_counts), do: calculate(vote_counts, [])

  @doc """
  Calcula el Social Feeling.

  Opciones:
    * `:weights` — mapa `%{choice => peso_float}` para sobreescribir
      los pesos por defecto.
  """
  @spec calculate(vote_counts(), keyword()) :: result()
  def calculate(vote_counts, _opts) when map_size(vote_counts) == 0 do
    %{score: 0.0, label: :sin_datos, total_votes: 0, breakdown: %{}}
  end

  def calculate(vote_counts, opts) when is_map(vote_counts) do
    weights = Keyword.get(opts, :weights, @default_weights)
    total = vote_counts |> Map.values() |> Enum.sum()

    score =
      if total > 0 do
        weighted =
          vote_counts
          |> Enum.map(fn {choice, count} -> Map.get(weights, choice, 0.0) * count end)
          |> Enum.sum()

        weighted / total
      else
        0.0
      end

    %{
      score: Float.round(score, 3),
      label: label_for(score),
      total_votes: total,
      breakdown: vote_counts
    }
  end

  defp label_for(score) do
    cond do
      score >= 0.6 -> :muy_positivo
      score >= 0.2 -> :positivo
      score > -0.2 -> :neutral
      score > -0.6 -> :negativo
      true -> :muy_negativo
    end
  end
end
