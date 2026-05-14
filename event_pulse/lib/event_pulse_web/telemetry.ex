defmodule EventPulseWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # El *poller* ejecuta las mediciones periódicas cada 10_000 ms.
      # Más información: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
      {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Métricas de Phoenix
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      sum("phoenix.socket_drain.count"),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Métricas propias de EventPulse
      counter("event_pulse.vote.cast.count", tags: [:event_id]),
      counter("event_pulse.vote.persist.count", tags: [:event_id]),
      counter("event_pulse.chat.message.stored", tags: [:event_id]),

      # Métricas de base de datos (Ecto)
      summary("event_pulse.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "Suma del resto de mediciones de la consulta"
      ),
      summary("event_pulse.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "Tiempo decodificando la respuesta de la base de datos"
      ),
      summary("event_pulse.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "Tiempo ejecutando la consulta SQL"
      ),
      summary("event_pulse.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "Tiempo esperando conexión del pool"
      ),
      summary("event_pulse.repo.query.idle_time",
        unit: {:native, :millisecond},
        description: "Tiempo en que la conexión estuvo inactiva antes de usarse en la consulta"
      ),

      # Métricas de la máquina virtual
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      # Módulo, función y argumentos a invocar de forma periódica.
      # La función debe llamar a `:telemetry.execute/3` y existir la métrica arriba.
      # {EventPulseWeb, :count_users, []}
    ]
  end
end
