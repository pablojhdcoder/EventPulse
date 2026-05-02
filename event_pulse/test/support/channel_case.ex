defmodule EventPulseWeb.ChannelCase do
  @moduledoc """
  Módulo de soporte para tests de Phoenix Channels.

  Importa `Phoenix.ChannelTest` y fija el endpoint del proyecto.
  Usa `start_supervised!/1` para arrancar procesos auxiliares como
  `EventPulse.Chat.EventRoom` de forma aislada en cada test.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import EventPulseWeb.ChannelCase

      @endpoint EventPulseWeb.Endpoint
    end
  end

  setup tags do
    EventPulse.DataCase.setup_sandbox(tags)
    :ok
  end
end
