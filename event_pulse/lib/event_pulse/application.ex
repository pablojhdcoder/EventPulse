defmodule EventPulse.Application do
  @moduledoc false

  use Application

  @cluster_node_prefix "event_pulse"

  @impl true
  def start(_type, _args) do
    front_children = [
      EventPulseWeb.Telemetry,
      {Task.Supervisor, name: EventPulse.TaskSupervisor},
      EventPulse.Chat.Supervisor,
      EventPulse.Repo,
      {Registry, keys: :unique, name: EventPulse.EventRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: EventPulse.EventSupervisor},
      {EventPulse.SocialFeeling.Worker, name: EventPulse.SocialFeeling.Worker},
      {DNSCluster, query: Application.get_env(:event_pulse, :dns_cluster_query) || :ignore}
    ]

    cluster_children = libcluster_supervisor_child()

    # En la demo Docker solo una réplica arranca el agregador global; si varias lo
    # hacen a la vez, `:global` resuelve el conflicto matando procesos y tira nodos.
    vote_aggregator =
      if start_vote_aggregator?() do
        [EventPulse.Votes.VoteAggregator]
      else
        []
      end

    # pool_size fijo en todo el clúster: si varía con schedulers_online/4,
    pubsub_and_endpoint = [
      {Redix, {redis_url(), [name: EventPulse.Redix]}},
      {Phoenix.PubSub,
       name: EventPulse.PubSub, adapter: Phoenix.PubSub.PG2, pool_size: 1, broadcast_pool_size: 1},
      {EventPulse.Chat.EventRoom, name: EventPulse.Chat.EventRoom},
      EventPulseWeb.Endpoint
    ]

    children = front_children ++ cluster_children ++ vote_aggregator ++ pubsub_and_endpoint

    opts = [strategy: :one_for_one, name: EventPulse.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp libcluster_supervisor_child do
    case cluster_epmd_node_atoms() do
      [] ->
        []

      hosts ->
        topologies = [
          event_pulse_epmd: [
            strategy: Cluster.Strategy.Epmd,
            config: [hosts: hosts, timeout: 5_000]
          ]
        ]

        [{Cluster.Supervisor, [topologies, [name: EventPulse.ClusterSupervisor]]}]
    end
  end

  defp cluster_epmd_node_atoms do
    case System.get_env("CLUSTER_PEER_HOSTS") do
      s when is_binary(s) and s != "" ->
        s
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&String.to_atom("#{@cluster_node_prefix}@#{&1}"))

      _ ->
        []
    end
  end

  defp redis_url do
    Application.get_env(:event_pulse, :redis_url, "redis://localhost:6379/0")
  end

  defp start_vote_aggregator? do
    System.get_env("START_VOTE_AGGREGATOR", "true") != "false"
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EventPulseWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
