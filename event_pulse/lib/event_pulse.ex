defmodule EventPulse do
  @doc """
  Verdadero si el proceso nombrado `EventPulse.PubSub` está registrado.

  Tareas como `EventPulse.Release.seed` (vía `bin/event_pulse eval`) cargan el código
  pero no arrancan la supervisión de la app: en ese caso no se emiten broadcasts.
  """
  def pubsub_running? do
    is_pid(Process.whereis(EventPulse.PubSub))
  end

  def broadcast(topic, message) when is_binary(topic) do
    if pubsub_running?() do
      Phoenix.PubSub.broadcast(EventPulse.PubSub, topic, message)
    end

    :ok
  end
end
