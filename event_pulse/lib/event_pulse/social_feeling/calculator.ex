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
  (`:muy_negativo`, ..., `:muy_positivo`). Sin votos, el resultado es `:sin_datos`.

  En `calculate/1` el `score` está en `[-1, 1]` y las etiquetas usan umbrales en ese
  intervalo. En `social_feeling_from_scale_poll_means/2` el `score` está en `[0, 1]`
  y las etiquetas usan umbrales definidos directamente en ese intervalo.
  """

  @type vote_counts :: %{String.t() => non_neg_integer()}
  @type result :: %{
          score: float(),
          label: :muy_negativo | :negativo | :neutral | :positivo | :muy_positivo | :sin_datos,
          numeric_vote_count: non_neg_integer(),
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
    %{score: 0.0, label: :sin_datos, numeric_vote_count: 0, breakdown: %{}}
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
      numeric_vote_count: total,
      breakdown: vote_counts
    }
  end

  @doc """
  Agrega el Social Feeling a partir de **medias ya normalizadas** en \\[0.0, 1.0\\],
  una por cada votación numérica con al menos un voto.

  Cada encuesta cuenta con el **mismo peso**. Devuelve `nil` si no hay ninguna media
  (todas las encuestas contribuyentes vacías).
  """
  @spec social_feeling_from_scale_poll_means([float()], non_neg_integer()) ::
          %{score: float(), label: atom(), numeric_vote_count: non_neg_integer(), breakdown: %{}} | nil
  def social_feeling_from_scale_poll_means(means, numeric_vote_count)
      when is_list(means) and is_integer(numeric_vote_count) do
    case means do
      [] ->
        nil

      _ ->
        raw = Enum.sum(means) / length(means)
        score = Float.round(raw, 3)

        %{
          score: score,
          label: label_from_unit_interval(score),
          numeric_vote_count: numeric_vote_count,
          breakdown: %{}
        }
    end
  end

  @doc """
  Media de valores de voto normalizados a \\[0,1\\] según el rango de `options`
  (enteros como strings). `:skip` si no hay votos.
  """
  @spec normalized_mean_scale_poll(map(), vote_counts()) :: {:ok, float()} | :skip
  def normalized_mean_scale_poll(%{options: options}, counts) when is_map(counts) do
    total = counts |> Map.values() |> Enum.sum()

    if total == 0 do
      :skip
    else
      nums =
        options
        |> Enum.map(fn o ->
          {n, ""} = Integer.parse(String.trim(o))
          n
        end)

      lo = Enum.min(nums)
      hi = Enum.max(nums)

      norm = fn n ->
        cond do
          hi == lo -> 0.5
          true -> (n - lo) / (hi - lo)
        end
      end

      sum =
        Enum.reduce(counts, 0.0, fn {choice, c}, acc ->
          {n, ""} = Integer.parse(String.trim(choice))
          acc + norm.(n) * c
        end)

      {:ok, sum / total}
    end
  end

  defp label_from_unit_interval(s) when is_float(s) do
    cond do
      s >= 0.8 -> :muy_positivo
      s >= 0.6 -> :positivo
      s >= 0.4 -> :neutral
      s >= 0.2 -> :negativo
      true -> :muy_negativo
    end
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
