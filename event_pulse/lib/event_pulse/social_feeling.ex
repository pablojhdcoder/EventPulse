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

  @doc "Devuelve el resultado persistido del evento o `nil`."
  @spec get_for_event(integer()) :: Result.t() | nil
  def get_for_event(event_id), do: Repo.get_by(Result, event_id: event_id)
end
