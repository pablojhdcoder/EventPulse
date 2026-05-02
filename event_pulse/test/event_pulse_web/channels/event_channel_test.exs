defmodule EventPulseWeb.EventChannelTest do
  use EventPulseWeb.ChannelCase

  alias EventPulse.Chat.EventRoom

  # Helpers

  defp connect_socket(user_id \\ "test_user") do
    {:ok, socket} = Phoenix.ChannelTest.connect(EventPulseWeb.UserSocket, %{"user_id" => user_id})

    socket
  end

  defp join_event(socket, event_id) do
    Phoenix.ChannelTest.subscribe_and_join(socket, "event:#{event_id}", %{})
  end

  defp push_msg(channel_socket, body) do
    Phoenix.ChannelTest.push(channel_socket, "new_msg", %{"body" => body})
  end

  # Genera un event_id único por test para evitar colisiones de estado en el GenServer global.
  defp unique_event_id, do: "test_#{System.unique_integer([:positive])}"

  # ---------------------------------------------------------------------------
  # Join
  # ---------------------------------------------------------------------------

  describe "join/3" do
    test "acepta sala válida y devuelve historial vacío" do
      event_id = unique_event_id()
      socket = connect_socket()
      assert {:ok, %{history: []}, _channel} = join_event(socket, event_id)
    end

    test "rechaza tópico con event_id vacío" do
      socket = connect_socket()

      assert {:error, %{reason: "invalid_event"}} =
               Phoenix.ChannelTest.subscribe_and_join(socket, "event:", %{})
    end
  end

  # ---------------------------------------------------------------------------
  # Historial al unirse (RF-08)
  # ---------------------------------------------------------------------------

  describe "historial en join" do
    test "devuelve mensajes previos al conectarse" do
      event_id = unique_event_id()

      EventRoom.send_message(event_id, %{author: "alice", body: "primer mensaje"})
      EventRoom.send_message(event_id, %{author: "bob", body: "segundo mensaje"})

      # Asegurar que el GenServer procesó los casts antes de hacer el join
      _ = :sys.get_state(EventRoom)

      socket = connect_socket()
      assert {:ok, %{history: history}, _} = join_event(socket, event_id)
      assert length(history) == 2
      assert Enum.at(history, 0).body == "primer mensaje"
      assert Enum.at(history, 1).body == "segundo mensaje"
    end

    test "buffer FIFO: descarta el mensaje más antiguo al superar N" do
      event_id = unique_event_id()
      buffer_max = Application.get_env(:event_pulse, :chat_buffer_max, 50)

      for i <- 1..(buffer_max + 1) do
        EventRoom.send_message(event_id, %{author: "u", body: "msg #{i}"})
      end

      _ = :sys.get_state(EventRoom)

      socket = connect_socket()
      assert {:ok, %{history: history}, _} = join_event(socket, event_id)
      assert length(history) == buffer_max
      assert hd(history).body == "msg 2"
    end
  end

  # ---------------------------------------------------------------------------
  # Broadcast a todos los clientes (RF-07)
  # ---------------------------------------------------------------------------

  describe "broadcast de mensajes" do
    test "un mensaje llega al socket que lo envía (y al resto suscrito al mismo topic)" do
      event_id = unique_event_id()

      socket_a = connect_socket("alice")
      socket_b = connect_socket("bob")

      {:ok, _, channel_a} = join_event(socket_a, event_id)
      {:ok, _, _channel_b} = join_event(socket_b, event_id)

      ref = push_msg(channel_a, "hola a todos")
      assert_reply ref, :ok

      # Ambos canales están suscritos al mismo tópico PubSub; el test process
      # recibe los pushes de los dos channels (mailbox compartido en ChannelTest).
      assert_push "new_message", %{body: "hola a todos", author: "alice"}
    end
  end

  # ---------------------------------------------------------------------------
  # Validación de mensajes
  # ---------------------------------------------------------------------------

  describe "validación de new_msg" do
    test "rechaza body vacío" do
      event_id = unique_event_id()
      socket = connect_socket()
      {:ok, _, channel} = join_event(socket, event_id)

      ref = push_msg(channel, "   ")
      assert_reply ref, :error, %{reason: "empty_body"}
    end

    test "rechaza body demasiado largo" do
      event_id = unique_event_id()
      max_len = Application.get_env(:event_pulse, :chat_max_body_length, 500)
      socket = connect_socket()
      {:ok, _, channel} = join_event(socket, event_id)

      ref = push_msg(channel, String.duplicate("x", max_len + 1))
      assert_reply ref, :error, %{reason: "body_too_long"}
    end

    test "acepta mensaje válido y responde :ok" do
      event_id = unique_event_id()
      socket = connect_socket()
      {:ok, _, channel} = join_event(socket, event_id)

      ref = push_msg(channel, "mensaje válido")
      assert_reply ref, :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Leave explícito
  # ---------------------------------------------------------------------------

  describe "leave" do
    test "deja la sala de forma ordenada y responde :ok" do
      event_id = unique_event_id()
      socket = connect_socket()
      {:ok, _, channel} = join_event(socket, event_id)

      Process.unlink(channel.channel_pid)
      ref = Phoenix.ChannelTest.push(channel, "leave", %{})
      assert_reply ref, :ok
    end
  end
end
