defmodule EventPulse.SocialFeeling.CalculatorTest do
  use ExUnit.Case, async: true

  alias EventPulse.SocialFeeling.Calculator

  describe "calculate/1 sin votos" do
    test "devuelve :sin_datos y score 0.0" do
      r = Calculator.calculate(%{})
      assert r.score == 0.0
      assert r.label == :sin_datos
      assert r.total_votes == 0
      assert r.breakdown == %{}
    end
  end

  describe "calculate/1 con pesos por defecto" do
    test "todo muy_positivo -> score 1.0 y etiqueta :muy_positivo" do
      r = Calculator.calculate(%{"muy_positivo" => 10})
      assert r.score == 1.0
      assert r.label == :muy_positivo
      assert r.total_votes == 10
    end

    test "todo muy_negativo -> score -1.0 y etiqueta :muy_negativo" do
      r = Calculator.calculate(%{"muy_negativo" => 5})
      assert r.score == -1.0
      assert r.label == :muy_negativo
      assert r.total_votes == 5
    end

    test "equilibrado entre positivo y negativo -> :neutral" do
      r = Calculator.calculate(%{"positivo" => 3, "negativo" => 3})
      assert r.score == 0.0
      assert r.label == :neutral
      assert r.total_votes == 6
    end

    test "más positivos que negativos -> etiqueta positiva" do
      r = Calculator.calculate(%{"positivo" => 8, "negativo" => 2})
      assert r.score > 0.2
      assert r.label in [:positivo, :muy_positivo]
      assert r.total_votes == 10
    end

    test "choices desconocidos cuentan en el total pero como neutros" do
      r = Calculator.calculate(%{"rara_avis" => 100})
      assert r.total_votes == 100
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
      assert r.total_votes == 10
    end
  end
end
