defmodule EventPulse.MixProject do
  use Mix.Project

  def project do
    [
      app: :event_pulse,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader],
      releases: [
        event_pulse: [
          include_executables_for: [:unix],
          cookie: "event_pulse_demo"
        ]
      ]
    ]
  end

  # Configuración de la aplicación OTP.
  #
  # Consulta `mix help compile.app` para más información.
  def application do
    [
      mod: {EventPulse.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Rutas compiladas según el entorno (`test` incluye `test/support`).
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Dependencias del proyecto.
  #
  # Consulta `mix help deps` para ejemplos y opciones.
  defp deps do
    [
      {:phoenix, "~> 1.8.5"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_live_view, "~> 1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:libcluster, "~> 3.5"},
      {:bandit, "~> 1.5"},
      {:pbkdf2_elixir, "~> 2.0"},
      {:redix, "~> 1.5"}
    ]
  end

  # Alias de Mix: atajos para tareas habituales del proyecto.
  # Por ejemplo, para instalar dependencias y preparar la base de datos:
  #
  #     $ mix setup
  #
  # Consulta la documentación de `Mix` para más detalle sobre los alias.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      demo_state: ["ecto.reset"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "test.docker": [
        "cmd docker-compose -f docker-compose.test.yml up -d db_test",
        "ecto.create --quiet",
        "ecto.migrate --quiet",
        "test",
        "cmd docker-compose -f docker-compose.test.yml down"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
