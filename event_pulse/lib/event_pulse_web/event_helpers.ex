defmodule EventPulseWeb.EventHelpers do
  @moduledoc false

  alias EventPulse.Accounts.Auth

  @doc """
  Valor mostrado en inputs del formulario de evento.
  En LiveView la primera pintura puede dejar `field.value` en nil aunque el changeset
  tenga datos; en edición se rellena desde el struct `event`.
  """
  def form_field_value(%Phoenix.HTML.FormField{} = field, event, attr) do
    if field.value != nil do
      field.value
    else
      event_field(event, attr)
    end
  end

  defp event_field(%{id: id} = event, attr) when is_integer(id), do: Map.get(event, attr)

  defp event_field(_event, _attr), do: nil

  @doc """
  Resuelve el usuario de la sesión LiveView (misma clave que `put_session(:user_id, ...)`).
  """
  def current_user_from_session(session) when is_map(session) do
    user_id = Map.get(session, "user_id") || Map.get(session, :user_id)
    user_id && Auth.get_user(user_id)
  end

  def status_color("programado"), do: "#ca8a04"
  def status_color("en_directo"), do: "#16a34a"
  def status_color("finalizado"), do: "#6b7280"
  def status_color(_), do: "#000000"
end
