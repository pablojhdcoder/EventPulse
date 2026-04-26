defmodule EventPulseWeb.SocialFeelingController do
  @moduledoc """
  Consulta del Social Feeling persistido para un `event_id`.

  - `GET /api/events/:event_id/social_feeling`
    - `200` + JSON si ya existe fila en `social_feeling_results` (p. ej. tras
      el cierre del evento o `SocialFeeling.Worker.process_event_sync/1`).
    - `404` si aún no hay resultado.
    - `400` si el id no es un entero válido.

  La comprobación de que el evento exista o esté en estado finalizado en
  la tabla `events` corresponde a la **Parte 2** (aquí no se consulta `events`).
  """

  use EventPulseWeb, :controller

  alias EventPulse.SocialFeeling

  def show(conn, %{"event_id" => raw_id}) do
    with {:ok, id} <- parse_id(raw_id),
         %_{} = result <- SocialFeeling.get_for_event(id) do
      conn
      |> put_status(:ok)
      |> render(:show, result: result)
    else
      :invalid_id ->
        conn
        |> put_status(:bad_request)
        |> render(:error, error: "invalid_id")

      nil ->
        conn
        |> put_status(:not_found)
        |> render(:error, error: "social_feeling_not_found")

      _ ->
        conn
        |> put_status(:not_found)
        |> render(:error, error: "social_feeling_not_found")
    end
  end

  defp parse_id(raw) when is_binary(raw) do
    case Integer.parse(raw) do
      {id, ""} -> {:ok, id}
      _ -> :invalid_id
    end
  end

  defp parse_id(raw) when is_integer(raw), do: {:ok, raw}
  defp parse_id(_), do: :invalid_id
end
