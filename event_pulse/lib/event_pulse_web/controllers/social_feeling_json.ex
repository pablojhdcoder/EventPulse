defmodule EventPulseWeb.SocialFeelingJSON do
  @moduledoc """
  Vista JSON del `SocialFeelingController`.
  """

  alias EventPulse.SocialFeeling.Result

  @doc "Serializa un `Result` para la respuesta `200 OK`."
  def show(%{result: %Result{} = r}) do
    %{
      data: %{
        event_id: r.event_id,
        score: r.score,
        label: r.label,
        total_votes: r.total_votes,
        breakdown: r.breakdown,
        computed_at: r.computed_at
      }
    }
  end

  @doc "Serializa respuestas de error manteniendo la info disponible."
  def error(%{error: err} = assigns) do
    base = %{error: err}
    if Map.has_key?(assigns, :state), do: Map.put(base, :state, assigns.state), else: base
  end
end
