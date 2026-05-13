defmodule EventPulse.SocialFeeling.CalculatorTest do
  use ExUnit.Case, async: true

  alias EventPulse.SocialFeeling.Calculator

  describe "calculate/1 sin votos" do
    test "devuelve :sin_datos y score 0.0" do
      r = Calculator.calculate(%{})
      assert r.score == 0.0
      assert r.label == :sin_datos
      assert r.numeric_vote_count == 0
      assert r.breakdown == %{}
    end
  end

  describe "calculate/1 con pesos por defecto" do
    test "todo muy_positivo -> score 1.0 y etiqueta :muy_positivo" do
      r = Calculator.calculate(%{"muy_positivo" => 10})
      assert r.score == 1.0
      assert r.label == :muy_positivo
      assert r.numeric_vote_count == 10
    end

    test "todo muy_negativo -> score -1.0 y etiqueta :muy_negativo" do
      r = Calculator.calculate(%{"muy_negativo" => 5})
      assert r.score == -1.0
      assert r.label == :muy_negativo
      assert r.numeric_vote_count == 5
    end

    test "equilibrado entre positivo y negativo -> :neutral" do
      r = Calculator.calculate(%{"positivo" => 3, "negativo" => 3})
      assert r.score == 0.0
      assert r.label == :neutral
      assert r.numeric_vote_count == 6
    end

    test "más positivos que negativos -> etiqueta positiva" do
      r = Calculator.calculate(%{"positivo" => 8, "negativo" => 2})
      assert r.score > 0.2
      assert r.label in [:positivo, :muy_positivo]
      assert r.numeric_vote_count == 10
    end

    test "choices desconocidos cuentan en el total pero como neutros" do
      r = Calculator.calculate(%{"rara_avis" => 100})
      assert r.numeric_vote_count == 100
      assert r.score == 0.0
      assert r.label == :neutral
    end

    test "umbrales exactos de etiqueta" do
      assert Calculator.calculate(%{"muy_positivo" => 6, "neutral" => 4}).label == :muy_positivo
      assert Calculator.calculate(%{"positivo" => 4, "neutral" => 6}).label == :positivo
      assert Calculator.calculate(%{"negativo" => 4, "neutral" => 6}).label == :negativo
      assert Calculator.calculate(%{"muy_negativo" => 6, "neutral" => 4}).label == :muy_negativo
    end
  end

  describe "calculate/2 con pesos personalizados" do
    test "usa los pesos recibidos" do
      weights = %{"sí" => 1.0, "no" => -1.0}
      r = Calculator.calculate(%{"sí" => 8, "no" => 2}, weights: weights)
      assert_in_delta r.score, 0.6, 0.001
      assert r.label == :muy_positivo
    end

    test "pesos vacíos -> neutro siempre" do
      r = Calculator.calculate(%{"sí" => 8, "no" => 2}, weights: %{})
      assert r.score == 0.0
      assert r.label == :neutral
      assert r.numeric_vote_count == 10
    end
  end

  describe "normalized_mean_scale_poll/2" do
    test "media en rango normalizado [0,1]" do
      poll = %{options: ["1", "3", "5"]}
      counts = %{"1" => 1, "5" => 1}
      assert {:ok, mean} = Calculator.normalized_mean_scale_poll(poll, counts)
      assert_in_delta mean, 0.5, 0.0001
    end

    test "sin votos -> :skip" do
      assert :skip == Calculator.normalized_mean_scale_poll(%{options: ["1", "2"]}, %{})
    end
  end

  describe "social_feeling_from_scale_poll_means/2" do
    test "media simple de medias por encuesta" do
      r = Calculator.social_feeling_from_scale_poll_means([0.0, 1.0], 10)
      assert r.score == 0.5
      assert r.label == :neutral
      assert r.numeric_vote_count == 10
    end

    test "etiquetas en [0,1] sin transformación a [-1,1]" do
      assert Calculator.social_feeling_from_scale_poll_means([1.0], 1).label == :muy_positivo
      assert Calculator.social_feeling_from_scale_poll_means([0.8], 1).label == :muy_positivo
      assert Calculator.social_feeling_from_scale_poll_means([0.6], 1).label == :positivo
      assert Calculator.social_feeling_from_scale_poll_means([0.4], 1).label == :neutral
      assert Calculator.social_feeling_from_scale_poll_means([0.2], 1).label == :negativo
      assert Calculator.social_feeling_from_scale_poll_means([0.19], 1).label == :muy_negativo
    end

    test "lista vacía -> nil" do
      assert Calculator.social_feeling_from_scale_poll_means([], 0) == nil
    end
  end
end
