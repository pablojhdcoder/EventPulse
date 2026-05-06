defmodule EventPulse.ChatBuffer do
  @moduledoc """
  Buffer distribuido de chat por sala basado en Redis Streams.

  - Conserva solo los últimos `@max_messages` mensajes por sala.
  - No mantiene estado local por nodo.
  - Permite hidratar al entrar (`get_last_messages/2`) y limpiar al finalizar (`delete_buffer/1`).
  """

  require Logger

  @redis_name EventPulse.Redix
  @max_messages Application.compile_env(:event_pulse, :chat_buffer_max, 15)

  @spec append_message(binary(), map()) :: :ok | {:error, term()}
  def append_message(room_id, %{user_id: _, username: _, content: _} = message)
      when is_binary(room_id) do
    payload =
      message
      |> Map.put_new(:timestamp, DateTime.utc_now() |> DateTime.truncate(:millisecond))
      |> normalize_payload()

    encoded = Jason.encode!(payload)
    key = stream_key(room_id)

    case redix_command([
           "XADD",
           key,
           "MAXLEN",
           "=",
           Integer.to_string(@max_messages),
           "*",
           "payload",
           encoded
         ]) do
      {:ok, _stream_id} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def append_message(_room_id, _message), do: {:error, :invalid_message}

  @spec get_last_messages(binary(), pos_integer()) :: [map()]
  def get_last_messages(room_id, limit \\ @max_messages)
      when is_binary(room_id) and is_integer(limit) and limit > 0 do
    key = stream_key(room_id)
    count = Integer.to_string(limit)

    case redix_command(["XREVRANGE", key, "+", "-", "COUNT", count]) do
      {:ok, rows} when is_list(rows) ->
        rows
        |> Enum.map(&decode_stream_entry/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.reverse()

      {:ok, _other} ->
        []

      {:error, %Redix.ConnectionError{reason: :closed}} ->
        []

      {:error, reason} ->
        Logger.warning(
          "chat_buffer: get_last_messages failed room=#{room_id}: #{inspect(reason)}"
        )
        []
    end
  end

  @spec delete_buffer(binary()) :: :ok | {:error, term()}
  def delete_buffer(room_id) when is_binary(room_id) do
    case redix_command(["DEL", stream_key(room_id)]) do
      {:ok, _deleted_count} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp stream_key(room_id), do: "chat:room:#{room_id}"

  defp normalize_payload(message) do
    timestamp =
      message
      |> Map.fetch!(:timestamp)
      |> normalize_timestamp()

    %{
      "user_id" => to_string(Map.fetch!(message, :user_id)),
      "username" => to_string(Map.fetch!(message, :username)),
      "content" => to_string(Map.fetch!(message, :content)),
      "timestamp" => timestamp
    }
  end

  defp normalize_timestamp(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp normalize_timestamp(ts) when is_binary(ts), do: ts
  defp normalize_timestamp(_), do: DateTime.utc_now() |> DateTime.to_iso8601()

  defp decode_stream_entry([_stream_id, fields]) when is_list(fields) do
    case payload_from_fields(fields) do
      nil ->
        nil

      payload ->
        with {:ok, decoded} <- Jason.decode(payload) do
          to_public_message(decoded)
        else
          _ -> nil
        end
    end
  end

  defp decode_stream_entry(_), do: nil

  defp payload_from_fields(["payload", payload]), do: payload
  defp payload_from_fields(fields), do: payload_from_pairs(fields)

  defp payload_from_pairs([key, value | rest]) do
    if key == "payload", do: value, else: payload_from_pairs(rest)
  end

  defp payload_from_pairs(_), do: nil

  defp to_public_message(%{
         "user_id" => user_id,
         "username" => username,
         "content" => content,
         "timestamp" => timestamp
       }) do
    %{
      user_id: user_id,
      username: username,
      content: content,
      timestamp: parse_timestamp(timestamp),
      author: username,
      body: content,
      inserted_at: parse_timestamp(timestamp)
    }
  end

  defp to_public_message(_), do: nil

  defp parse_timestamp(ts) when is_binary(ts) do
    case DateTime.from_iso8601(ts) do
      {:ok, dt, _offset} -> dt
      _ -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end

  defp parse_timestamp(_), do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp redix_command(command) do
    Redix.command(@redis_name, command)
  rescue
    exception ->
      Logger.warning("chat_buffer: redix unavailable command=#{inspect(command)} error=#{inspect(exception)}")
      {:error, :redis_unavailable}
  end
end
