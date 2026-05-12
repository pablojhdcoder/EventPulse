defmodule EventPulse.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do

    # Lista de procesos a supervisar
    children = [
      EventPulseWeb.Telemetry,  # Telemetría para monitoreo de rendimiento
      EventPulse.Repo,          # Repositorio de Ecto para acceso a la base de datos
      {EventPulse.Votes.VoteAggregator, name: EventPulse.Votes.VoteAggregator},                 # Proceso para agregar votos en tiempo real
      {DNSCluster, query: Application.get_env(:event_pulse, :dns_cluster_query) || :ignore},    # Cluster de nodos usando DNS para descubrimiento
      {Phoenix.PubSub, name: EventPulse.PubSub},    # PubSub para comunicación entre procesos y nodos en tiempo real
      EventPulseWeb.Endpoint    # Endpoint de Phoenix, el servoidor que escucha las peticiones
    ]

    # Si un hijo muere, reiniciarlo automáticamente a ese en específico
    opts = [strategy: :one_for_one, name: EventPulse.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Permite actualizar la configuración del endpoint en caliente sin reiniciar toda la aplicación
  @impl true
  def config_change(changed, _new, removed) do
    EventPulseWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
